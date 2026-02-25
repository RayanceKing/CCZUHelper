//
//  WatchDataManager.swift
//  CCZUHelperLite Watch App
//
//  Created by rayanceking on 2025/12/6.
//

import Foundation

/// Watch App 数据管理器 - 负责从共享容器加载课程数据
struct WatchDataManager {
    static let shared = WatchDataManager()
    
    private let appGroupIdentifier = AppGroupIdentifiers.watch

    enum LoadFailureReason {
        case missingContainer
        case missingFile
        case decodeFailed
    }

    struct LoadResult {
        let courses: [WatchCourse]
        let lastModified: Date?
        let failureReason: LoadFailureReason?
    }
    
    /// 课程数据模型（与主应用保持一致）
    struct WatchCourse: Codable, Identifiable {
        let name: String
        let teacher: String
        let location: String
        let timeSlot: Int
        let duration: Int
        let color: String
        let dayOfWeek: Int  // 1-7 表示周一到周日

        var id: String { "\(name)-\(location)-\(timeSlot)-\(dayOfWeek)" }
    }
    
    /// 获取共享容器URL
    private var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }
    
    /// 从共享容器加载今天的课程数据
    func loadTodayCoursesFromApp(now: Date = Date(), calendar: Calendar = .current) -> LoadResult {
        guard let containerURL = sharedContainerURL else {
            print("Watch: 无法访问共享容器")
            return LoadResult(courses: [], lastModified: nil, failureReason: .missingContainer)
        }
        
        let coursesFile = containerURL.appendingPathComponent("widget_courses.json")
        guard FileManager.default.fileExists(atPath: coursesFile.path) else {
            print("Watch: 尚未收到课程数据文件，等待主 App 同步")
            return LoadResult(courses: [], lastModified: nil, failureReason: .missingFile)
        }
        
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: coursesFile.path)
            let modified = attrs[.modificationDate] as? Date
            let data = try Data(contentsOf: coursesFile)
            let decoder = JSONDecoder()
            let courses = try decoder.decode([WatchCourse].self, from: data)
            let todayWeekday = weekdayForSchedule(from: now, calendar: calendar)
            let todayCourses = courses
                .filter { $0.dayOfWeek == todayWeekday }
                .sorted {
                    if $0.timeSlot == $1.timeSlot {
                        return $0.name.localizedStandardCompare($1.name) == .orderedAscending
                    }
                    return $0.timeSlot < $1.timeSlot
                }
            print("Watch: 成功加载课程 \(courses.count) 门，今日课程 \(todayCourses.count) 门")
            return LoadResult(courses: todayCourses, lastModified: modified, failureReason: nil)
        } catch {
            print("Watch: 加载课程数据失败: \(error)")
            return LoadResult(courses: [], lastModified: nil, failureReason: .decodeFailed)
        }
    }
    
    /// 获取课程的开始和结束时间
    func getTimeRange(for timeSlot: Int) -> (start: String, end: String)? {
        return ClassTimeManager.shared.getTimeRange(for: timeSlot)
    }
    
    /// 将系统 weekday(1=周日...7=周六) 转为课表 weekday(1=周一...7=周日)
    private func weekdayForSchedule(from date: Date, calendar: Calendar) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return ((weekday + 5) % 7) + 1
    }
}
