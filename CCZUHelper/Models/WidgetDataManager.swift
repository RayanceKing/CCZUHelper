//
//  WidgetDataManager.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/04.
//

import Foundation
import SwiftData

/// Widget数据管理器 - 负责将课程数据写入共享容器供Widget读取
struct WidgetDataManager {
    static let shared = WidgetDataManager()
    
    private let appGroupIdentifier = "group.com.cczu.helper"
    
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
    
    /// 获取共享容器URL
    private var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }
    
    /// 保存今天的课程到Widget共享容器
    /// - Parameter courses: 课程数组（来自ScheduleView的today课程）
    func saveTodayCoursesForWidget(_ courses: [WidgetCourse]) {
        guard let containerURL = sharedContainerURL else {
            print("无法访问共享容器")
            return
        }
        
        let coursesFile = containerURL.appendingPathComponent("widget_courses.json")
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(courses)
            try data.write(to: coursesFile)
        } catch {
            print("保存Widget课程数据失败: \(error)")
        }
    }
    
    /// 从共享容器加载课程数据（用于测试）
    func loadTodayCoursesFromWidget() -> [WidgetCourse] {
        guard let containerURL = sharedContainerURL else {
            return []
        }
        
        let coursesFile = containerURL.appendingPathComponent("widget_courses.json")
        
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
    func clearWidgetData() {
        guard let containerURL = sharedContainerURL else {
            return
        }
        
        let coursesFile = containerURL.appendingPathComponent("widget_courses.json")
        try? FileManager.default.removeItem(at: coursesFile)
    }

    /// 从本地 SwiftData 中取出当前活跃课表的今日课程，并写入共享容器。
    /// 在 App 启动或宿主 App 进入前台时调用，确保 Watch 端随时可读。
    func syncTodayCoursesFromStore(container: ModelContainer) {
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

            // 3) 过滤今天课程
            let calendar = Calendar.current
            let today = Date()
            let weekday = calendar.component(.weekday, from: today)
            let todayDayOfWeek = weekday == 1 ? 7 : weekday - 1
            let todayCourses = courses.filter { $0.dayOfWeek == todayDayOfWeek }

            // 4) 转换并写入共享容器
            let widgetCourses = todayCourses.map { course in
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

            saveTodayCoursesForWidget(widgetCourses)
        } catch {
            print("Widget sync failed: \(error)")
        }
    }
}

