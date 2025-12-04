//
//  AppSettings.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/11/30.
//

import SwiftUI

/// 应用设置模型
@Observable
class AppSettings {
    // MARK: - 周开始日
    enum WeekStartDay: Int, CaseIterable {
        case sunday = 1
        case monday = 2
        case saturday = 7
        
        var displayName: String {
            switch self {
            case .sunday: return "周日"
            case .monday: return "周一"
            case .saturday: return "周六"
            }
        }
    }
    
    // MARK: - 时间间隔
    enum TimeInterval: Int, CaseIterable {
        case fifteen = 15
        case thirty = 30
        case sixty = 60
        
        var displayName: String {
            "\(rawValue)分钟"
        }
    }
    
    // MARK: - 存储键
    private enum Keys {
        static let weekStartDay = "weekStartDay"
        static let calendarStartHour = "calendarStartHour"
        static let calendarEndHour = "calendarEndHour"
        static let showGridLines = "showGridLines"
        static let showTimeRuler = "showTimeRuler"
        static let showAllDayEvents = "showAllDayEvents"
        static let timeInterval = "timeInterval"
        static let courseBlockOpacity = "courseBlockOpacity"
        static let backgroundImageEnabled = "backgroundImageEnabled"
        static let backgroundImagePath = "backgroundImagePath"
        static let isLoggedIn = "isLoggedIn"
        static let username = "username"
    }
    
    // MARK: - 属性
    var weekStartDay: WeekStartDay {
        didSet { UserDefaults.standard.set(weekStartDay.rawValue, forKey: Keys.weekStartDay) }
    }
    
    var calendarStartHour: Int {
        didSet { UserDefaults.standard.set(calendarStartHour, forKey: Keys.calendarStartHour) }
    }
    
    var calendarEndHour: Int {
        didSet { UserDefaults.standard.set(calendarEndHour, forKey: Keys.calendarEndHour) }
    }
    
    var showGridLines: Bool {
        didSet { UserDefaults.standard.set(showGridLines, forKey: Keys.showGridLines) }
    }
    
    var showTimeRuler: Bool {
        didSet { UserDefaults.standard.set(showTimeRuler, forKey: Keys.showTimeRuler) }
    }
    
    var showAllDayEvents: Bool {
        didSet { UserDefaults.standard.set(showAllDayEvents, forKey: Keys.showAllDayEvents) }
    }
    
    var timeInterval: TimeInterval {
        didSet { UserDefaults.standard.set(timeInterval.rawValue, forKey: Keys.timeInterval) }
    }
    
    var courseBlockOpacity: Double {
        didSet { UserDefaults.standard.set(courseBlockOpacity, forKey: Keys.courseBlockOpacity) }
    }
    
    var backgroundImageEnabled: Bool {
        didSet { UserDefaults.standard.set(backgroundImageEnabled, forKey: Keys.backgroundImageEnabled) }
    }
    
    var backgroundImagePath: String? {
        didSet { UserDefaults.standard.set(backgroundImagePath, forKey: Keys.backgroundImagePath) }
    }
    
    var isLoggedIn: Bool {
        didSet { UserDefaults.standard.set(isLoggedIn, forKey: Keys.isLoggedIn) }
    }
    
    var username: String? {
        didSet { UserDefaults.standard.set(username, forKey: Keys.username) }
    }
    
    // MARK: - 初始化
    init() {
        let defaults = UserDefaults.standard
        
        // 加载周开始日
        let weekStartDayRaw = defaults.integer(forKey: Keys.weekStartDay)
        self.weekStartDay = WeekStartDay(rawValue: weekStartDayRaw) ?? .monday
        
        // 加载日历时间范围
        self.calendarStartHour = defaults.object(forKey: Keys.calendarStartHour) as? Int ?? 8
        self.calendarEndHour = defaults.object(forKey: Keys.calendarEndHour) as? Int ?? 21
        
        // 加载显示选项
        self.showGridLines = defaults.object(forKey: Keys.showGridLines) as? Bool ?? true
        self.showTimeRuler = defaults.object(forKey: Keys.showTimeRuler) as? Bool ?? true
        self.showAllDayEvents = defaults.object(forKey: Keys.showAllDayEvents) as? Bool ?? false
        
        // 加载时间间隔
        let timeIntervalRaw = defaults.integer(forKey: Keys.timeInterval)
        self.timeInterval = TimeInterval(rawValue: timeIntervalRaw) ?? .sixty
        
        // 加载课程块透明度
        self.courseBlockOpacity = defaults.object(forKey: Keys.courseBlockOpacity) as? Double ?? 0.8
        
        // 加载背景图片设置
        self.backgroundImageEnabled = defaults.bool(forKey: Keys.backgroundImageEnabled)
        self.backgroundImagePath = defaults.string(forKey: Keys.backgroundImagePath)
        
        // 加载登录状态
        self.isLoggedIn = defaults.bool(forKey: Keys.isLoggedIn)
        self.username = defaults.string(forKey: Keys.username)
    }
    
    // MARK: - 方法
    func logout() {
        // 删除 Keychain 中的密码
        if let username = username {
            KeychainHelper.delete(service: "com.cczu.helper", account: username)
        }
        isLoggedIn = false
        username = nil
    }
    
    // MARK: - 课程时间配置 (基于CCZUKit calendar.json)
    /// 课时时间配置结构
    struct ClassTime {
        let name: String
        let startHour: Int
        let startMinute: Int
        let endHour: Int
        let endMinute: Int
        
        var startTimeInMinutes: Int { startHour * 60 + startMinute }
        var endTimeInMinutes: Int { endHour * 60 + endMinute }
        var durationInMinutes: Int { endTimeInMinutes - startTimeInMinutes }
    }
    
    /// 常州大学课程时间配置
    static let classTimes: [ClassTime] = [
        ClassTime(name: "1", startHour: 8, startMinute: 0, endHour: 8, endMinute: 40),
        ClassTime(name: "2", startHour: 8, startMinute: 45, endHour: 9, endMinute: 25),
        ClassTime(name: "3", startHour: 9, startMinute: 45, endHour: 10, endMinute: 25),
        ClassTime(name: "4", startHour: 10, startMinute: 35, endHour: 11, endMinute: 15),
        ClassTime(name: "5", startHour: 11, startMinute: 20, endHour: 12, endMinute: 0),
        ClassTime(name: "6", startHour: 13, startMinute: 30, endHour: 14, endMinute: 10),
        ClassTime(name: "7", startHour: 14, startMinute: 15, endHour: 14, endMinute: 55),
        ClassTime(name: "8", startHour: 15, startMinute: 15, endHour: 15, endMinute: 55),
        ClassTime(name: "9", startHour: 16, startMinute: 0, endHour: 16, endMinute: 40),
        ClassTime(name: "10", startHour: 18, startMinute: 30, endHour: 19, endMinute: 10),
        ClassTime(name: "11", startHour: 19, startMinute: 15, endHour: 19, endMinute: 55),
        ClassTime(name: "12", startHour: 20, startMinute: 5, endHour: 20, endMinute: 45)
    ]
    
    /// 将节次转换为开始时间(分钟)
    /// - Parameter timeSlot: 节次 (1-12)
    /// - Returns: 从00:00开始的分钟数
    func timeSlotToMinutes(_ timeSlot: Int) -> Int {
        guard timeSlot >= 1 && timeSlot <= AppSettings.classTimes.count else {
            return calendarStartHour * 60
        }
        return AppSettings.classTimes[timeSlot - 1].startTimeInMinutes
    }
    
    /// 获取节次的结束时间(分钟)
    /// - Parameter timeSlot: 节次 (1-12)
    /// - Returns: 从00:00开始的分钟数
    func timeSlotEndMinutes(_ timeSlot: Int) -> Int {
        guard timeSlot >= 1 && timeSlot <= AppSettings.classTimes.count else {
            return calendarStartHour * 60 + 40
        }
        return AppSettings.classTimes[timeSlot - 1].endTimeInMinutes
    }
    
    /// 将节次转换为开始小时
    /// - Parameter timeSlot: 节次 (1-12)
    /// - Returns: 对应的开始小时
    func timeSlotToHour(_ timeSlot: Int) -> Int {
        guard timeSlot >= 1 && timeSlot <= AppSettings.classTimes.count else {
            return calendarStartHour
        }
        return AppSettings.classTimes[timeSlot - 1].startHour
    }
    
    /// 获取课程时长(以分钟为单位)
    /// - Parameters:
    ///   - startSlot: 开始节次
    ///   - duration: 课程持续节数
    /// - Returns: 从开始节次到结束节次的总分钟数
    func courseDurationInMinutes(startSlot: Int, duration: Int) -> Int {
        guard startSlot >= 1 && startSlot <= AppSettings.classTimes.count else {
            return duration * 40 // 默认每节40分钟
        }
        let endSlot = min(startSlot + duration - 1, AppSettings.classTimes.count)
        let startMinutes = timeSlotToMinutes(startSlot)
        let endMinutes = timeSlotEndMinutes(endSlot)
        return endMinutes - startMinutes
    }
}
