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
    
    private let appGroupIdentifier = "group.com.cczu.helper"
    
    /// 课程数据模型（与主应用保持一致）
    struct WatchCourse: Codable {
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
    
    /// 从共享容器加载今天的课程数据
    func loadTodayCoursesFromApp() -> [WatchCourse] {
        guard let containerURL = sharedContainerURL else {
            print("Watch: 无法访问共享容器")
            return []
        }
        
        let coursesFile = containerURL.appendingPathComponent("widget_courses.json")
        guard FileManager.default.fileExists(atPath: coursesFile.path) else {
            print("Watch: 尚未收到课程数据文件，等待主 App 同步")
            return []
        }
        
        do {
            let data = try Data(contentsOf: coursesFile)
            let decoder = JSONDecoder()
            let courses = try decoder.decode([WatchCourse].self, from: data)
            print("Watch: 成功加载 \(courses.count) 门课程")
            return courses
        } catch {
            print("Watch: 加载课程数据失败: \(error)")
            return []
        }
    }
    
    /// 获取课程的开始和结束时间
    func getTimeRange(for timeSlot: Int) -> (start: String, end: String)? {
        return ClassTimeManager.shared.getTimeRange(for: timeSlot)
    }
    
    /// 获取课程颜色
    func getUIColor(from hexString: String) -> String {
        // 返回十六进制颜色字符串供后续使用
        hexString
    }
}
