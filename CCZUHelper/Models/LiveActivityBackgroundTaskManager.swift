//
//  LiveActivityBackgroundTaskManager.swift
//  CCZUHelper
//
//  Created by Copilot on 2026/2/26.
//

import Foundation

#if os(iOS) && canImport(BackgroundTasks)
import BackgroundTasks
import SwiftData

final class LiveActivityBackgroundTaskManager {
    static let shared = LiveActivityBackgroundTaskManager()
    
    private let taskIdentifier = "com.stuwang.edupal.refresh-live-activity"
    
    private init() {}
    
    /// 注册后台任务处理器（必须在应用启动早期调用）
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            self.handleBackgroundRefresh(task: task as! BGProcessingTask)
        }
    }
    
    /// 安排下一次后台刷新任务
    /// - Parameters:
    ///   - targetDate: 目标执行时间（课程开始时间）
    ///   - allowEarlierStart: 是否允许提前开始（默认：是，最多提前5分钟）
    func scheduleBackgroundRefresh(at targetDate: Date, allowEarlierStart: Bool = true) {
        let request = BGProcessingTaskRequest(identifier: taskIdentifier)
        
        // 设置执行时间为课程开始时间
        request.earliestBeginDate = targetDate
        
        // 需要网络连接（虽然我们不需要，但设置为false可能提高执行机会）
        request.requiresNetworkConnectivity = false
        
        // 需要外部电源（设置为false以提高执行机会）
        request.requiresExternalPower = false
        
        do {
            // 取消之前安排的任务
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
            
            // 提交新任务
            try BGTaskScheduler.shared.submit(request)
            print("✅ 已安排实时活动后台刷新任务，执行时间: \(targetDate)")
        } catch {
            print("❌ 安排后台任务失败: \(error)")
        }
    }
    
    /// 取消所有后台刷新任务
    func cancelAllBackgroundTasks() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
        print("🚫 已取消所有实时活动后台刷新任务")
    }
    
    // MARK: - Private
    
    private func handleBackgroundRefresh(task: BGProcessingTask) {
        print("🔄 执行实时活动后台刷新任务")
        
        // 设置任务过期处理
        task.expirationHandler = {
            print("⏰ 后台任务即将过期")
            task.setTaskCompleted(success: false)
        }
        
        // 执行刷新操作
        Task { @MainActor in
            // 加载应用设置
            let settings = AppSettings()
            
            // 加载课程数据并刷新实时活动
            if let courses = await loadCourses() {
                #if canImport(ActivityKit)
                await NextCourseLiveActivityManager.shared.refresh(
                    courses: courses,
                    settings: settings
                )
                #endif
                
                // 如果还有未来的课程，安排下一次后台任务
                if let nextCourse = findNextCourseStartDate(courses: courses, settings: settings) {
                    scheduleBackgroundRefresh(at: nextCourse)
                }
            }
            
            task.setTaskCompleted(success: true)
            print("✅ 后台刷新任务完成")
        }
    }
    
    /// 从 SwiftData 加载课程数据
    private func loadCourses() async -> [Course]? {
        guard let modelContainer = try? ModelContainer(for: Course.self, Schedule.self) else {
            print("❌ 无法创建 ModelContainer")
            return nil
        }
        
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<Course>()
        
        do {
            let courses = try context.fetch(descriptor)
            print("📚 已加载 \(courses.count) 门课程")
            return courses
        } catch {
            print("❌ 加载课程数据失败: \(error)")
            return nil
        }
    }
    
    /// 加载应用设置
    private func loadAppSettings() async -> AppSettings? {
        return AppSettings()
    }
    
    /// 查找下一个课程的开始时间
    private func findNextCourseStartDate(courses: [Course], settings: AppSettings) -> Date? {
        let now = Date()
        let calendar = Calendar.current
        let helpers = ScheduleHelpers()
        var candidates: [Date] = []
        
        for dayOffset in 0...14 {
            guard let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now)) else { continue }
            
            let weekNumber = helpers.currentWeekNumber(
                for: dayDate,
                schedules: [],
                semesterStartDate: settings.semesterStartDate,
                weekStartDay: settings.weekStartDay
            )
            guard weekNumber >= 1 else { continue }
            
            let weekday = calendar.component(.weekday, from: dayDate)
            let dayOfWeek = ((weekday + 5) % 7) + 1
            
            let dayCourses = courses.filter { $0.dayOfWeek == dayOfWeek && $0.weeks.contains(weekNumber) }
            
            for course in dayCourses {
                guard let startConfig = ClassTimeManager.shared.getClassTime(for: course.timeSlot) else { continue }
                
                guard let startDate = calendar.date(
                    bySettingHour: startConfig.startHourInt,
                    minute: startConfig.startMinute,
                    second: 0,
                    of: dayDate
                ) else { continue }
                
                if startDate > now {
                    candidates.append(startDate)
                }
            }
        }
        
        return candidates.min()
    }
}
#else
// 非 iOS 平台或不支持 BackgroundTasks 时的空实现
@MainActor
final class LiveActivityBackgroundTaskManager {
    static let shared = LiveActivityBackgroundTaskManager()
    private init() {}
    
    func registerBackgroundTasks() {}
    func scheduleBackgroundRefresh(at targetDate: Date, allowEarlierStart: Bool = true) {}
    func cancelAllBackgroundTasks() {}
}
#endif

