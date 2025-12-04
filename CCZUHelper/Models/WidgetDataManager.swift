//
//  WidgetDataManager.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/04.
//

import Foundation

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
}
