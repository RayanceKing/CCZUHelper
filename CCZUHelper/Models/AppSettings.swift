//
//  AppSettings.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/11/30.
//

import SwiftUI
#if canImport(CCZUKit)
//import CCZUKit
import CCZUNISwiftBridge

#endif

/// 应用设置模型
@Observable
class AppSettings {
        // MARK: - 服务实例
    #if canImport(CCZUKit)
        var jwqywxApplication: JwqywxApplication?
    #endif
    // MARK: - 周开始日
    enum WeekStartDay: Int, CaseIterable {
        case monday = 1
        case tuesday = 2
        case wednesday = 3
        case thursday = 4
        case friday = 5
        case saturday = 6
        case sunday = 7
        
        var displayName: String {
            switch self {
            case .monday: return "weekday.monday".localized
            case .tuesday: return "weekday.tuesday".localized
            case .wednesday: return "weekday.wednesday".localized
            case .thursday: return "weekday.thursday".localized
            case .friday: return "weekday.friday".localized
            case .saturday: return "weekday.saturday".localized
            case .sunday: return "weekday.sunday".localized
            }
        }
    }
    
    // MARK: - 时间间隔
    enum TimeInterval: Int, CaseIterable {
        case fifteen = 15
        case thirty = 30
        case sixty = 60
        
        var displayName: String {
            switch rawValue {
            case 15: return "time_interval.15min".localized
            case 30: return "time_interval.30min".localized
            case 60: return "time_interval.60min".localized
            default: return "\(rawValue)分钟"
            }
        }
    }
    
    // MARK: - 通知提醒时间
    enum NotificationTime: Int, CaseIterable {
        case none = 15
        case thirtyMinutes = 30
        case oneHour = 60
        
        var displayName: String {
            switch self {
            case .none: return "settings.notification_time.15min".localized
            case .thirtyMinutes: return "settings.notification_time.30min".localized
            case .oneHour: return "settings.notification_time.1hour".localized
            }
        }
    }
    
    // MARK: - 时间轴显示方式
    enum TimelineDisplayMode: Int, CaseIterable {
        case standardTime = 0
        case classTime = 1
        
        var displayName: String {
            switch self {
            case .standardTime: return "settings.timeline_display_standard".localized
            case .classTime: return "settings.timeline_display_class".localized
            }
        }
        
        var description: String {
            switch self {
            case .standardTime: return "settings.timeline_display_standard_desc".localized
            case .classTime: return "settings.timeline_display_class_desc".localized
            }
        }
    }
    
    // MARK: - 存储键
    private enum Keys {
        static let weekStartDay = "weekStartDay"
        static let calendarStartHour = "calendarStartHour"
        static let calendarEndHour = "calendarEndHour"
        static let showGridLines = "showGridLines"
        static let showTimeRuler = "showTimeRuler"
        static let showCurrentTimeline = "showCurrentTimeline"
        static let showAllDayEvents = "showAllDayEvents"
        static let timeInterval = "timeInterval"
        static let courseBlockOpacity = "courseBlockOpacity"
        static let backgroundImageEnabled = "backgroundImageEnabled"
        static let backgroundImagePath = "backgroundImagePath"
        static let backgroundOpacity = "backgroundOpacity" // 新增
        static let isLoggedIn = "isLoggedIn"
        static let username = "username"
        static let userDisplayName = "userDisplayName"
        static let semesterStartDate = "semesterStartDate"
        static let enableCourseNotification = "enableCourseNotification"
        static let enableExamNotification = "enableExamNotification"
        static let courseNotificationTime = "courseNotificationTime"
        static let examNotificationTime = "examNotificationTime"
        static let userAvatarPath = "userAvatarPath"
        static let enableCalendarSync = "enableCalendarSync"
        static let timelineDisplayMode = "timelineDisplayMode"
        static let useLiquidGlass = "useLiquidGlass"
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

    var showCurrentTimeline: Bool {
        didSet { UserDefaults.standard.set(showCurrentTimeline, forKey: Keys.showCurrentTimeline) }
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

    var backgroundOpacity: Double { // 新增属性
        didSet { UserDefaults.standard.set(backgroundOpacity, forKey: Keys.backgroundOpacity) }
    }
    
    var isLoggedIn: Bool {
        didSet { UserDefaults.standard.set(isLoggedIn, forKey: Keys.isLoggedIn) }
    }
    
    var username: String? {
        didSet { UserDefaults.standard.set(username, forKey: Keys.username) }
    }
    
    var userDisplayName: String? {
        didSet { UserDefaults.standard.set(userDisplayName, forKey: Keys.userDisplayName) }
    }
    
    var semesterStartDate: Date {
        didSet { UserDefaults.standard.set(semesterStartDate.timeIntervalSince1970, forKey: Keys.semesterStartDate) }
    }
    
    var enableCourseNotification: Bool {
        didSet { UserDefaults.standard.set(enableCourseNotification, forKey: Keys.enableCourseNotification) }
    }
    
    var enableExamNotification: Bool {
        didSet { UserDefaults.standard.set(enableExamNotification, forKey: Keys.enableExamNotification) }
    }
    
    var userAvatarPath: String? {
        didSet { UserDefaults.standard.set(userAvatarPath, forKey: Keys.userAvatarPath) }
    }
    
    var enableCalendarSync: Bool {
        didSet { UserDefaults.standard.set(enableCalendarSync, forKey: Keys.enableCalendarSync) }
    }
    
    var courseNotificationTime: NotificationTime {
        didSet { UserDefaults.standard.set(courseNotificationTime.rawValue, forKey: Keys.courseNotificationTime) }
    }
    
    var examNotificationTime: NotificationTime {
        didSet { UserDefaults.standard.set(examNotificationTime.rawValue, forKey: Keys.examNotificationTime) }
    }
    
    var timelineDisplayMode: TimelineDisplayMode {
        didSet { UserDefaults.standard.set(timelineDisplayMode.rawValue, forKey: Keys.timelineDisplayMode) }
    }
    
    var useLiquidGlass: Bool {
        didSet { UserDefaults.standard.set(useLiquidGlass, forKey: Keys.useLiquidGlass) }
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
        self.showCurrentTimeline = defaults.object(forKey: Keys.showCurrentTimeline) as? Bool ?? true
        self.showAllDayEvents = defaults.object(forKey: Keys.showAllDayEvents) as? Bool ?? false
        
        // 加载时间间隔
        let timeIntervalRaw = defaults.integer(forKey: Keys.timeInterval)
        self.timeInterval = TimeInterval(rawValue: timeIntervalRaw) ?? .sixty
        
        // 加载课程块透明度
        self.courseBlockOpacity = defaults.object(forKey: Keys.courseBlockOpacity) as? Double ?? 0.5
        
        // 加载背景图片设置
        self.backgroundImageEnabled = defaults.bool(forKey: Keys.backgroundImageEnabled)
        self.backgroundImagePath = defaults.string(forKey: Keys.backgroundImagePath)
        self.backgroundOpacity = defaults.object(forKey: Keys.backgroundOpacity) as? Double ?? 0.3 // 初始化新增属性
        
        // 加载登录状态
        self.isLoggedIn = defaults.bool(forKey: Keys.isLoggedIn)
        self.username = defaults.string(forKey: Keys.username)
        self.userDisplayName = defaults.string(forKey: Keys.userDisplayName)
        
        // 加载学期开始日期（默认为当前日期）
        if let timestamp = defaults.object(forKey: Keys.semesterStartDate) as? Double {
            self.semesterStartDate = Date(timeIntervalSince1970: timestamp)
        } else {
            self.semesterStartDate = Date()
        }
        
        // 加载通知设置
        self.enableCourseNotification = defaults.object(forKey: Keys.enableCourseNotification) as? Bool ?? true
        self.enableExamNotification = defaults.object(forKey: Keys.enableExamNotification) as? Bool ?? true
        
        let courseNotificationTimeRaw = defaults.integer(forKey: Keys.courseNotificationTime)
        self.courseNotificationTime = NotificationTime(rawValue: courseNotificationTimeRaw) ?? .none
        
        let examNotificationTimeRaw = defaults.integer(forKey: Keys.examNotificationTime)
        self.examNotificationTime = NotificationTime(rawValue: examNotificationTimeRaw) ?? .none
        
        // 加载用户头像路径
        self.userAvatarPath = defaults.string(forKey: Keys.userAvatarPath)
        
        // 日历同步开关
        self.enableCalendarSync = defaults.object(forKey: Keys.enableCalendarSync) as? Bool ?? false
        
        // 加载时间轴显示方式
        let timelineDisplayModeRaw = defaults.integer(forKey: Keys.timelineDisplayMode)
        self.timelineDisplayMode = TimelineDisplayMode(rawValue: timelineDisplayModeRaw) ?? .standardTime
        
        if let stored = defaults.object(forKey: Keys.useLiquidGlass) as? Bool {
            self.useLiquidGlass = stored
        } else {
            if #available(iOS 26, macOS 26, *) {
                self.useLiquidGlass = true
            } else {
                self.useLiquidGlass = false
            }
        }

#if canImport(CCZUKit)
        // 若存在已登录用户名，这里仅占位实例化客户端；密码需由登录流程提供
        if let user = self.username, self.isLoggedIn {
            // 以空密码占位，真实登录流程会重新创建并登录
            let client = DefaultHTTPClient(username: user, password: "")
            self.jwqywxApplication = JwqywxApplication(client: client)
        }
#endif
    }

#if canImport(CCZUKit)
    /// 在登录后配置教务应用客户端
    func configureJwqywx(username: String, password: String) {
        let client = DefaultHTTPClient(username: username, password: password)
        self.jwqywxApplication = JwqywxApplication(client: client)
    }

    /// 从 Keychain 同步账户并配置共享教务客户端
    /// - 返回: 是否成功从 Keychain 读取并完成配置
    @discardableResult
    func configureFromKeychain() -> Bool {
        // 使用 iCloud Keychain 同步的账号信息
        guard let (username, password) = AccountSyncManager.retrieveAccountFromiCloud() else { return false }
        let client = DefaultHTTPClient(username: username, password: password)
        self.jwqywxApplication = JwqywxApplication(client: client)
        self.username = username
        self.isLoggedIn = true
        return true
    }

    /// 确保教务客户端已配置且可用，必要时从 Keychain 恢复并重新登录
    func ensureJwqywxLoggedIn() async throws -> JwqywxApplication {
        // 始终从 Keychain 拿到最新凭据，并在需要时重建客户端（避免空密码占位导致登录失败）
        if let (username, password) = AccountSyncManager.retrieveAccountFromiCloud() {
            // 始终用最新的 Keychain 凭据重建客户端，避免占位空密码导致登录失败
            let client = DefaultHTTPClient(username: username, password: password)
            jwqywxApplication = JwqywxApplication(client: client)
        } else if jwqywxApplication == nil {
            throw CCZUError.notLoggedIn
        }

        guard let app = jwqywxApplication else { throw CCZUError.notLoggedIn }

        // 始终尝试刷新登录，确保 token 有效（即使进程重启或后台恢复）
        _ = try await app.login()
        return app
    }
#endif
    
    // MARK: - 方法
    func logout() {
        // 删除 Keychain 中的密码（同时删除iCloud和本地）
        if let username = username {
            AccountSyncManager.removeAccountFromiCloud(username: username)
        }
        
        // 删除用户头像文件
        if let avatarPath = userAvatarPath {
            try? FileManager.default.removeItem(atPath: avatarPath)
        }
        
    #if canImport(CCZUKit)
        jwqywxApplication = nil
    #endif
        isLoggedIn = false
        username = nil
        userDisplayName = nil
        userAvatarPath = nil
    }
    
    // MARK: - 课程时间配置 (统一使用 ClassTimeManager)
    
    /// 将节次转换为开始时间(分钟)
    /// - Parameter timeSlot: 节次 (1-12)
    /// - Returns: 从00:00开始的分钟数
    func timeSlotToMinutes(_ timeSlot: Int) -> Int {
        return ClassTimeManager.shared.timeSlotToMinutes(timeSlot)
    }
    
    /// 获取节次的结束时间(分钟)
    /// - Parameter timeSlot: 节次 (1-12)
    /// - Returns: 从00:00开始的分钟数
    func timeSlotEndMinutes(_ timeSlot: Int) -> Int {
        return ClassTimeManager.shared.timeSlotEndMinutes(timeSlot)
    }
    
    /// 将节次转换为开始小时
    /// - Parameter timeSlot: 节次 (1-12)
    /// - Returns: 对应的开始小时
    func timeSlotToHour(_ timeSlot: Int) -> Int {
        guard let classTime = ClassTimeManager.shared.getClassTime(for: timeSlot) else { return 0 }
        return Int(classTime.startTime.prefix(2)) ?? 0
    }
    
    /// 获取课程时长(以分钟为单位)
    /// - Parameters:
    ///   - startSlot: 开始节次
    ///   - duration: 课程持续的节次数
    /// - Returns: 课程实际时长对应的分钟数
    func courseDurationInMinutes(startSlot: Int, duration: Int) -> Int {
        return ClassTimeManager.shared.courseDurationInMinutes(startSlot: startSlot, duration: duration)
    }
}

