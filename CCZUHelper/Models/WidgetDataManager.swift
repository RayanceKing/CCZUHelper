//
//  WidgetDataManager.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/04.
//

import Foundation
import SwiftData
import SwiftUI
import WidgetKit

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
    
    /// Export the active schedule for both shortcuts and widgets in one place.
    @MainActor
    func syncSchedule(courses: [Course], settings: AppSettings) {
        if let username = settings.username {
            AppIntentsDataCache.shared.saveCourses(courses, for: username)
        }
        let snapshot = WidgetScheduleSnapshot(
            context: ScheduleDateContext(
                semesterStartDate: settings.semesterStartDate,
                weekStartDay: settings.weekStartDay.rawValue
            ),
            courses: courses.map {
                ScheduleWidgetCourse(
                    name: $0.name, teacher: $0.teacher, location: $0.location,
                    timeSlot: $0.timeSlot, duration: $0.duration, color: $0.color,
                    dayOfWeek: $0.dayOfWeek, weeks: $0.weeks
                )
            }
        )
        guard let containerURL = sharedContainerURL else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let data = try encoder.encode(snapshot)
            let snapshotURL = containerURL.appendingPathComponent(WidgetScheduleSnapshot.fileName)
            let changed = (try? Data(contentsOf: snapshotURL)) != data
            try data.write(to: snapshotURL, options: .atomic)

            // Keep the existing weekly payload for older watch apps. The phone widget
            // reads the full snapshot above, so it can advance weeks without opening the app.
            let week = snapshot.context.weekNumber(for: Date())
            let legacyCourses = snapshot.courses.filter { week > 0 && $0.weeks.contains(week) }.map {
                WidgetCourse(name: $0.name, teacher: $0.teacher, location: $0.location,
                             timeSlot: $0.timeSlot, duration: $0.duration, color: $0.color, dayOfWeek: $0.dayOfWeek)
            }
            try encoder.encode(legacyCourses).write(
                to: containerURL.appendingPathComponent(coursesFileName), options: .atomic
            )
            let classTimes = ClassTimeManager.shared.allClassTimes.map {
                WidgetClassTime(slotNumber: $0.slotNumber, start: formatTime($0.startTime), end: formatTime($0.endTime))
            }
            try encoder.encode(classTimes).write(
                to: containerURL.appendingPathComponent(classTimesFileName), options: .atomic
            )
            if changed { WidgetCenter.shared.reloadTimelines(ofKind: "CCZUHelperWidget") }
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
        try? FileManager.default.removeItem(at: containerURL.appendingPathComponent(WidgetScheduleSnapshot.fileName))
        WidgetCenter.shared.reloadTimelines(ofKind: "CCZUHelperWidget")
        try? FileManager.default.removeItem(at: coursesFile)
        try? FileManager.default.removeItem(at: classTimesFile)
    }

    /// 从本地 SwiftData 中取出当前活跃课表的课程，并写入共享容器。
    /// 在 App 启动或宿主 App 进入前台时调用，确保 Widget/Watch 随时可读。
    @MainActor
    func syncTodayCoursesFromStore(container: ModelContainer) async {
        let context = ModelContext(container)

        do {
            // 1) 取活跃课表，否则与课表页面一致，取最早创建的课表兜底
            var scheduleDescriptor = FetchDescriptor<Schedule>(predicate: #Predicate { $0.isActive })
            scheduleDescriptor.fetchLimit = 1
            let activeSchedules = try context.fetch(scheduleDescriptor)
            let active = activeSchedules.first ?? {
                var fallback = FetchDescriptor<Schedule>()
                fallback.sortBy = [SortDescriptor(\Schedule.createdAt)]
                fallback.fetchLimit = 1
                return try? context.fetch(fallback).first
            }()

            guard let schedule = active else {
                clearWidgetData()
                if let username = AppSettings().username {
                    AppIntentsDataCache.shared.saveCourses([], for: username)
                }
                return
            }

            // Fix: Capture the schedule.id into a local constant before the predicate
            let targetScheduleID = schedule.id
            
            // 2) 拉取该课表课程
            let courseDescriptor = FetchDescriptor<Course>(predicate: #Predicate { $0.scheduleId == targetScheduleID })
            let courses = try context.fetch(courseDescriptor)

            syncSchedule(courses: courses, settings: AppSettings())
        } catch {
            print("Widget sync failed: \(error)")
        }
    }

    private nonisolated func formatTime(_ raw: String) -> String {
        guard raw.count == 4 else { return raw }
        return "\(raw.prefix(2)):\(raw.suffix(2))"
    }
}
