//
//  ScheduleHelpers.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/03.
//

import Foundation
import SwiftUI

/// 课程表辅助方法集合
struct ScheduleHelpers {
    private let calendar = Calendar.current
    
    // MARK: - 日期相关
    
    /// 格式化年月字符串
    func yearMonthString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: date)
    }
    
    /// 计算当前周数
    func currentWeekNumber(for date: Date, schedules: [Schedule]) -> Int {
        if let activeSchedule = schedules.first(where: { $0.isActive }) {
            let semesterStart = activeSchedule.createdAt
            let weeksSinceStart = calendar.dateComponents([.weekOfYear], from: semesterStart, to: date).weekOfYear ?? 0
            return max(1, weeksSinceStart + 1)
        }
        return calendar.component(.weekOfYear, from: date)
    }
    
    /// 获取星期名称
    func weekdayName(for index: Int, weekStartDay: AppSettings.WeekStartDay) -> String {
        let weekdays = [
            String(localized: "周一"),
            String(localized: "周二"),
            String(localized: "周三"),
            String(localized: "周四"),
            String(localized: "周五"),
            String(localized: "周六"),
            String(localized: "周日")
        ]
        let adjustedIndex: Int
        
        switch weekStartDay {
        case .sunday:
            adjustedIndex = (index + 6) % 7
        case .monday:
            adjustedIndex = index
        case .saturday:
            adjustedIndex = (index + 5) % 7
        }
        
        return weekdays[adjustedIndex]
    }
    
    /// 获取一周的日期数组
    func getWeekDates(for targetDate: Date, weekStartDay: AppSettings.WeekStartDay) -> [Date] {
        var dates: [Date] = []
        
        // 获取目标日期所在周的周一
        let weekday = calendar.component(.weekday, from: targetDate)
        
        // 计算到本周一的天数偏移（weekday: 1=周日, 2=周一, ..., 7=周六）
        let daysFromMonday: Int
        switch weekStartDay {
        case .monday:
            // 周一开始：周日往前6天,周一0天,周二往前1天...
            daysFromMonday = weekday == 1 ? -6 : -(weekday - 2)
        case .sunday:
            // 周日开始：周日0天,周一往前1天...
            daysFromMonday = -(weekday - 1)
        case .saturday:
            // 周六开始：周六0天,周日往前1天,周一往前2天...
            daysFromMonday = weekday == 7 ? -1 : -(weekday)
        }
        
        guard let startOfWeek = calendar.date(byAdding: .day, value: daysFromMonday, to: targetDate) else {
            return []
        }
        
        // 生成一周的日期
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: startOfWeek) {
                dates.append(date)
            }
        }
        
        return dates
    }
    
    /// 根据周偏移量获取日期
    func getDateForWeekOffset(_ offset: Int, baseDate: Date) -> Date {
        calendar.date(byAdding: .weekOfYear, value: offset, to: baseDate) ?? baseDate
    }
    
    /// 筛选当前周的课程
    func coursesForWeek(courses: [Course], date: Date) -> [Course] {
        let weekNumber = calendar.component(.weekOfYear, from: date)
        return courses.filter { $0.weeks.contains(weekNumber) }
    }
    
    // MARK: - 布局计算
    
    /// 调整星期索引（根据周起始日）
    func adjustedDayIndex(for dayOfWeek: Int, weekStartDay: AppSettings.WeekStartDay) -> Int {
        switch weekStartDay {
        case .sunday:
            return dayOfWeek == 7 ? 6 : dayOfWeek - 1
        case .monday:
            return dayOfWeek - 1
        case .saturday:
            return (dayOfWeek + 1) % 7
        }
    }
    
    // MARK: - 图片加载
    
    /// 从路径加载图片
    func loadImage(from path: String) -> PlatformImage? {
        #if os(iOS)
        return UIImage(contentsOfFile: path)
        #elseif os(macOS)
        return NSImage(contentsOfFile: path)
        #else
        return nil
        #endif
    }
}

// MARK: - 平台图片类型
#if os(iOS)
typealias PlatformImage = UIImage
#elseif os(macOS)
typealias PlatformImage = NSImage
#else
typealias PlatformImage = Any
#endif
