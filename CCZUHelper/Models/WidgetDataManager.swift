//
//  WidgetDataManager.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/04.
//

import Foundation
import SwiftData
import SwiftUI

/// Widget数据管理器 - 负责将课程数据写入共享容器供Widget读取
struct WidgetDataManager {
    static let shared = WidgetDataManager()
    
    private let appGroupIdentifier = AppGroupIdentifiers.main
    private let coursesFileName = "widget_courses.json"
    private let classTimesFileName = "widget_class_times.json"
    
    /// Widget课程数据模型
    struct WidgetCourse: Codable {
        let name: String
        let teacher: String
        let location: String
        let timeSlot: Int
        let duration: Int
        let color: String
        let dayOfWeek: Int  // 1-7 表示周一到周日
    }

    struct WidgetClassTime: Codable {
        let slotNumber: Int
        let start: String // HH:mm
        let end: String   // HH:mm
    }
    
    /// 获取共享容器URL
    private nonisolated var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }
    
    /// 保存课程到Widget共享容器
    /// - Parameter courses: 课程数组（来自当前活跃课表，可按需提前筛选周次或日期）
    nonisolated func saveCoursesForWidget(_ courses: [WidgetCourse]) async {
        guard let containerURL = sharedContainerURL else {
            print("无法访问共享容器")
            return
        }
        
        let coursesFile = containerURL.appendingPathComponent(coursesFileName)
        let classTimesFile = containerURL.appendingPathComponent(classTimesFileName)
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(courses)
            try data.write(to: coursesFile)

            // Persist class-time mapping so watch widget can render exactly the same time table.
            let classTimes: [WidgetClassTime] = await MainActor.run {
                ClassTimeManager.shared.allClassTimes
                    .sorted { $0.slotNumber < $1.slotNumber }
                    .map { config in
                        WidgetClassTime(
                            slotNumber: config.slotNumber,
                            start: formatTime(config.startTime),
                            end: formatTime(config.endTime)
                        )
                    }
            }
            let classTimesData = try encoder.encode(classTimes)
            try classTimesData.write(to: classTimesFile)
        } catch {
            print("保存Widget课程数据失败: \(error)")
        }
    }
    
    /// 从共享容器加载课程数据（用于测试）
    func loadTodayCoursesFromWidget() -> [WidgetCourse] {
        guard let containerURL = sharedContainerURL else {
            return []
        }
        
        let coursesFile = containerURL.appendingPathComponent(coursesFileName)
        
        do {
            let data = try Data(contentsOf: coursesFile)
            let decoder = JSONDecoder()
            return try decoder.decode([WidgetCourse].self, from: data)
        } catch {
            print("加载Widget课程数据失败: \(error)")
            return []
        }
    }
    
    /// 清空Widget数据
    nonisolated func clearWidgetData() {
        guard let containerURL = sharedContainerURL else {
            return
        }
        
        let coursesFile = containerURL.appendingPathComponent(coursesFileName)
        let classTimesFile = containerURL.appendingPathComponent(classTimesFileName)
        try? FileManager.default.removeItem(at: coursesFile)
        try? FileManager.default.removeItem(at: classTimesFile)
    }

    /// 从本地 SwiftData 中取出当前活跃课表的课程，并写入共享容器。
    /// 在 App 启动或宿主 App 进入前台时调用，确保 Widget/Watch 随时可读。
    nonisolated func syncTodayCoursesFromStore(container: ModelContainer) async {
        let context = ModelContext(container)

        do {
            // 1) 取活跃课表，否则取最新课表兜底
            var scheduleDescriptor = FetchDescriptor<Schedule>(predicate: #Predicate { $0.isActive })
            scheduleDescriptor.fetchLimit = 1
            let activeSchedules = try context.fetch(scheduleDescriptor)
            let active = activeSchedules.first ?? {
                var fallback = FetchDescriptor<Schedule>()
                fallback.sortBy = [SortDescriptor(\Schedule.createdAt, order: .reverse)]
                fallback.fetchLimit = 1
                return try? context.fetch(fallback).first
            }()

            guard let schedule = active else {
                clearWidgetData()
                return
            }

            // Fix: Capture the schedule.id into a local constant before the predicate
            let targetScheduleID = schedule.id
            
            // 2) 拉取该课表课程
            let courseDescriptor = FetchDescriptor<Course>(predicate: #Predicate { $0.scheduleId == targetScheduleID })
            let courses = try context.fetch(courseDescriptor)

            // 3) 获取设置值用于过滤当前周课程
            let (semesterStartDate, weekStartDay) = await MainActor.run {
                let settings = AppSettings()
                return (settings.semesterStartDate, settings.weekStartDay)
            }
            
            // 4) 在 nonisolated 上下文中手动过滤当前周的课程，避免跨 actor 边界传递 Course 对象
            let calendar = Calendar.current
            let today = Date()
            
            // 计算 semesterStartDate 所在周的开始日期
            let semesterWeekdayComponent = calendar.component(.weekday, from: semesterStartDate)
            let startDayInCalendar = (weekStartDay.rawValue % 7) + 1  // Convert to Calendar.weekday (1=Sunday)
            var daysFromSemesterStart = semesterWeekdayComponent - startDayInCalendar
            if daysFromSemesterStart < 0 { daysFromSemesterStart += 7 }
            let semesterWeekStart = calendar.date(byAdding: .day, value: -daysFromSemesterStart, to: semesterStartDate) ?? semesterStartDate
            
            // 计算今天所在周的开始日期
            let todayWeekdayComponent = calendar.component(.weekday, from: today)
            var daysFromTodayStart = todayWeekdayComponent - startDayInCalendar
            if daysFromTodayStart < 0 { daysFromTodayStart += 7 }
            let todayWeekStart = calendar.date(byAdding: .day, value: -daysFromTodayStart, to: today) ?? today
            
            // 计算周数
            let daysBetween = calendar.dateComponents([.day], from: semesterWeekStart, to: todayWeekStart).day ?? 0
            let semesterWeekNumber = (daysBetween / 7) + 1
            
            // 过滤当前周的课程
            let currentWeekCourses = semesterWeekNumber > 0 
                ? courses.filter { $0.weeks.contains(semesterWeekNumber) }
                : []

            // 5) 将当前周课程写入共享容器
            let widgetCourses = currentWeekCourses.map { course in
                WidgetCourse(
                    name: course.name,
                    teacher: course.teacher,
                    location: course.location,
                    timeSlot: course.timeSlot,
                    duration: course.duration,
                    color: course.color,
                    dayOfWeek: course.dayOfWeek
                )
            }

            await saveCoursesForWidget(widgetCourses)
        } catch {
            print("Widget sync failed: \(error)")
        }
    }

    private nonisolated func formatTime(_ raw: String) -> String {
        guard raw.count == 4 else { return raw }
        return "\(raw.prefix(2)):\(raw.suffix(2))"
    }
}
