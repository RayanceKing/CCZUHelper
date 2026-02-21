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
        AppDateFormatting.yearMonthChineseString(from: date)
    }
    
    /// 计算当前周数
    func currentWeekNumber(for date: Date, schedules: [Schedule], semesterStartDate: Date, weekStartDay: AppSettings.WeekStartDay) -> Int {
        // 找到 semesterStartDate 所在周的开始日期
        let semesterWeekStart = getWeekStartDateForAppSettings(for: semesterStartDate, weekStartDay: weekStartDay)
        let targetWeekStart = getWeekStartDateForAppSettings(for: date, weekStartDay: weekStartDay)
        
        // 计算两个周开始日期之间的周数差异
        let daysBetween = calendar.dateComponents([.day], from: semesterWeekStart, to: targetWeekStart).day ?? 0
        let weeksBetween = daysBetween / 7
        
        return max(1, weeksBetween + 1)
    }
    
    /// 获取星期名称
    func weekdayName(for index: Int, weekStartDay: AppSettings.WeekStartDay) -> String {
        let weekdays = [
            String(localized: "weekday.monday"),
            String(localized: "weekday.tuesday"),
            String(localized: "weekday.wednesday"),
            String(localized: "weekday.thursday"),
            String(localized: "weekday.friday"),
            String(localized: "weekday.saturday"),
            String(localized: "weekday.sunday")
        ]
        
        // weekStartDay.rawValue: 1=周一, 2=周二, ..., 7=周日
        // index: 0-6 表示显示位置
        let offset = weekStartDay.rawValue - 1
        let adjustedIndex = (index + offset) % 7
        
        return weekdays[adjustedIndex]
    }
    
    /// 获取一周的日期数组
    func getWeekDates(for targetDate: Date, weekStartDay: AppSettings.WeekStartDay) -> [Date] {
        var dates: [Date] = []
        
        // 获取目标日期所在周的weekday（1=周日, 2=周一, ..., 7=周六）
        let weekday = calendar.component(.weekday, from: targetDate)
        
        // 计算到本周开始日的天数偏移
        // weekStartDay.rawValue: 1=周一, 2=周二, ..., 7=周日
        // weekday: 1=周日, 2=周一, ..., 7=周六
        let startDayInCalendar = calendarWeekday(for: weekStartDay)
        
        // 计算当前日期距离本周开始日的天数
        var daysFromStart = weekday - startDayInCalendar
        if daysFromStart < 0 {
            daysFromStart += 7
        }
        
        guard let startOfWeek = calendar.date(byAdding: .day, value: -daysFromStart, to: targetDate) else {
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
    func coursesForWeek(courses: [Course], date: Date, semesterStartDate: Date, weekStartDay: AppSettings.WeekStartDay) -> [Course] {
        // 找到 semesterStartDate 所在周的开始日期
        let semesterWeekStart = getWeekStartDateForAppSettings(for: semesterStartDate, weekStartDay: weekStartDay)
        let targetWeekStart = getWeekStartDateForAppSettings(for: date, weekStartDay: weekStartDay)
        
        // 计算两个周开始日期之间的周数差异
        let daysBetween = calendar.dateComponents([.day], from: semesterWeekStart, to: targetWeekStart).day ?? 0
        let weeksBetween = daysBetween / 7
        let semesterWeekNumber = weeksBetween + 1
        
        // 只显示有效的正周数课程（周数 >= 1）
        if semesterWeekNumber <= 0 {
            return []
        }
        
        return courses.filter { $0.weeks.contains(semesterWeekNumber) }
    }
    
    /// 获取指定日期所在周的开始日期（使用 AppSettings.WeekStartDay）
    private func getWeekStartDateForAppSettings(for date: Date, weekStartDay: AppSettings.WeekStartDay) -> Date {
        let targetDayOfWeek = calendar.component(.weekday, from: date)
        let startDayInCalendar = calendarWeekday(for: weekStartDay)
        
        // 计算当前日期距离本周开始日的天数
        var daysFromStart = targetDayOfWeek - startDayInCalendar
        if daysFromStart < 0 {
            daysFromStart += 7
        }
        
        guard let weekStartDate = calendar.date(byAdding: .day, value: -daysFromStart, to: date) else {
            return date
        }
        
        return calendar.startOfDay(for: weekStartDate)
    }

    private func calendarWeekday(for weekStartDay: AppSettings.WeekStartDay) -> Int {
        // AppSettings 以周一=1...周日=7，Calendar 以周日=1...周六=7
        weekStartDay.rawValue == 7 ? 1 : weekStartDay.rawValue + 1
    }
    
    // MARK: - 布局计算
    
    /// 调整星期索引（根据周起始日）
    func adjustedDayIndex(for dayOfWeek: Int, weekStartDay: AppSettings.WeekStartDay) -> Int {
        // dayOfWeek: 1=周一, 2=周二, ..., 7=周日
        // 返回值: 在7列网格中的列索引 (0-6)
        
        // weekStartDay.rawValue: 1=周一, 2=周二, ..., 7=周日
        let offset = weekStartDay.rawValue - 1
        
        // 将dayOfWeek映射到0-6的范围
        let dayIndex = dayOfWeek - 1
        
        // 计算相对于起始日的偏移
        var adjustedIndex = dayIndex - offset
        if adjustedIndex < 0 {
            adjustedIndex += 7
        }
        
        return adjustedIndex
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
#if canImport(UIKit)
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
typealias PlatformImage = NSImage
#else
typealias PlatformImage = Any
#endif
