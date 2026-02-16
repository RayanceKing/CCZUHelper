//
//  AppDateFormatting.swift
//  CCZUHelper
//
//  Created by Codex on 2026/2/16.
//

import Foundation

/// 统一日期格式化入口，避免业务层分散创建 DateFormatter。
enum AppDateFormatting {
    private static let mediumDateKey = "com.stuwang.edupal.dateformatter.mediumDate"
    private static let yearMonthKey = "com.stuwang.edupal.dateformatter.yearMonthChinese"
    private static let examDateKey = "com.stuwang.edupal.dateformatter.examDate"
    private static let monthDayHourMinuteKey = "com.stuwang.edupal.dateformatter.monthDayHourMinute"

    static func mediumDateString(from date: Date) -> String {
        formatter(for: mediumDateKey) { formatter in
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
        }
        .string(from: date)
    }

    static func yearMonthChineseString(from date: Date) -> String {
        formatter(for: yearMonthKey) { formatter in
            formatter.dateFormat = "yyyy年M月"
        }
        .string(from: date)
    }

    static func monthDayHourMinuteString(from date: Date) -> String {
        formatter(for: monthDayHourMinuteKey) { formatter in
            formatter.dateFormat = "MM-dd HH:mm"
        }
        .string(from: date)
    }

    /// 支持格式: "2025年12月18日 18:30--20:30" 或 "2025年12月18日 18:30"
    static func parseChineseExamDateTime(_ timeString: String) -> Date? {
        let components = timeString.components(separatedBy: " ")
        guard components.count >= 2 else { return nil }

        let datePart = components[0]
        let timePart = components[1].components(separatedBy: "--")[0]
        let merged = "\(datePart) \(timePart)"

        return formatter(for: examDateKey) { formatter in
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        }
        .date(from: merged)
    }

    /// DateFormatter 线程不安全，使用 threadDictionary 做线程级缓存。
    private static func formatter(for key: String, configure: (DateFormatter) -> Void) -> DateFormatter {
        if let cached = Thread.current.threadDictionary[key] as? DateFormatter {
            return cached
        }

        let formatter = DateFormatter()
        configure(formatter)
        Thread.current.threadDictionary[key] = formatter
        return formatter
    }
}
