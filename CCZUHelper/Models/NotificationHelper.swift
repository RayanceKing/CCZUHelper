//
//  NotificationHelper.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/04.
//
import Foundation
import UserNotifications
#if os(iOS)
import UIKit
#endif

enum NotificationHelper {
    // MARK: - 通知ID前缀
    static let courseNotificationPrefix = "course_"
    static let examNotificationPrefix = "exam_"
    
    /// 移除相同标识的待触发与已送达通知，防止重复
    private static func removeExistingNotifications(with identifier: String) async {
        let center = UNUserNotificationCenter.current()
        // 移除待触发
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        // 移除已送达（通知中心里的）
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
    
    /// 清空应用角标并移除所有已送达通知（可在应用启动/激活时调用）
    static func resetBadgeAndDeliveredNotifications() async {
        let center = UNUserNotificationCenter.current()
        center.removeAllDeliveredNotifications()
        #if os(iOS)
        if #available(iOS 17.0, *) {
            try? await center.setBadgeCount(0)
        } else {
            // Fallback on earlier versions
            await MainActor.run {
                UIApplication.shared.applicationIconBadgeNumber = 0
            }
        }
        #endif
    }
    
    // MARK: - 权限请求
    static func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                #if os(iOS)
                if granted {
                    await MainActor.run {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
                #endif
            } catch {}
        case .authorized, .provisional, .ephemeral:
            #if os(iOS)
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
            #endif
        default:
            break
        }
    }
    
    // MARK: - 课程通知
    /// 安排课程通知
    /// - Parameters:
    ///   - courseId: 课程ID
    ///   - courseName: 课程名称
    ///   - location: 上课地点
    ///   - classTime: 上课时间（开始时间）
    ///   - notificationTime: 提前多久通知（分钟）
    static func scheduleCourseNotification(
        courseId: String,
        courseName: String,
        location: String,
        classTime: Date,
        notificationTime: Int
    ) async {
        let notificationDate = classTime.addingTimeInterval(-TimeInterval(notificationTime * 60))
        guard notificationDate > Date() else { return }
        
        let notificationId = courseNotificationPrefix + courseId
        await removeExistingNotifications(with: notificationId)
        
        let content = UNMutableNotificationContent()
        content.title = courseName
        content.body = "location_reminder".localized(with: location)
        content.sound = .default
        
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: notificationDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: notificationId, content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {}
    }
    
    /// 移除课程通知
    static func removeCourseNotification(courseId: String) async {
        let notificationId = courseNotificationPrefix + courseId
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId])
    }
    
    /// 为所有课程安排通知
    /// - Parameters:
    ///   - courses: 课程列表
    ///   - settings: 应用设置
    static func scheduleAllCourseNotifications(
        courses: [Course],
        settings: AppSettings
    ) async {
        // 检查是否启用了课程通知
        guard settings.enableCourseNotification else { return }
        
        let notificationMinutes = settings.courseNotificationTime.rawValue
        let today = Date()
        let calendar = Calendar.current
        let restDayKeys = settings.skipCourseNotificationOnHolidayRest
            ? await HolidayRestDayProvider.loadRestDayKeys(calendar: calendar)
            : []
        
        // 先清除旧的课程通知，避免过期提醒继续触发
        await removeAllCourseNotifications()
        
        // 以“用户设定的周起始日”为基准，避免因系统地区首日不同导致日期偏移
        let semesterWeekStart = weekStartDate(
            for: settings.semesterStartDate,
            weekStartDay: settings.weekStartDay,
            calendar: calendar
        )
        
        for course in courses {
            for week in course.weeks where week > 0 {
                let dayOffsetInWeek = weekdayOffsetInWeek(
                    dayOfWeek: course.dayOfWeek,
                    weekStartDay: settings.weekStartDay
                )
                let dayOffset = (week - 1) * 7 + dayOffsetInWeek
                guard let courseDate = calendar.date(byAdding: .day, value: dayOffset, to: semesterWeekStart) else { continue }

                guard let classTimeConfig = ClassTimeManager.shared.getClassTime(for: course.timeSlot) else { continue }
                let classStartMinutes = classTimeConfig.startTimeInMinutes
                let hour = classStartMinutes / 60
                let minute = classStartMinutes % 60

                var timeComps = calendar.dateComponents([.year, .month, .day], from: courseDate)
                timeComps.hour = hour
                timeComps.minute = minute

                guard let classTime = calendar.date(from: timeComps) else { continue }

                // 只为“未来的实际上课时间”安排通知，避免漏掉今天稍后的课程
                guard classTime > today else { continue }
                if settings.skipCourseNotificationOnHolidayRest {
                    let comps = calendar.dateComponents([.year, .month, .day], from: classTime)
                    if let y = comps.year, let m = comps.month, let d = comps.day {
                        let key = y * 10_000 + m * 100 + d
                        if restDayKeys.contains(key) {
                            continue
                        }
                    }
                }

                let notificationId = "\(course.id)_week\(week)"

                await scheduleCourseNotification(
                    courseId: notificationId,
                    courseName: course.name,
                    location: course.location,
                    classTime: classTime,
                    notificationTime: notificationMinutes
                )
            }
        }
    }

    private static func weekStartDate(
        for date: Date,
        weekStartDay: AppSettings.WeekStartDay,
        calendar: Calendar
    ) -> Date {
        let weekday = calendar.component(.weekday, from: date) // 1=周日 ... 7=周六
        let startWeekday = calendarWeekday(for: weekStartDay)
        var daysFromStart = weekday - startWeekday
        if daysFromStart < 0 { daysFromStart += 7 }
        let startDate = calendar.date(byAdding: .day, value: -daysFromStart, to: date) ?? date
        return calendar.startOfDay(for: startDate)
    }

    private static func weekdayOffsetInWeek(dayOfWeek: Int, weekStartDay: AppSettings.WeekStartDay) -> Int {
        // dayOfWeek: 1=周一 ... 7=周日
        // weekStartDay.rawValue: 1=周一 ... 7=周日
        var offset = dayOfWeek - weekStartDay.rawValue
        if offset < 0 { offset += 7 }
        return offset
    }

    private static func calendarWeekday(for weekStartDay: AppSettings.WeekStartDay) -> Int {
        // AppSettings: 周一=1...周日=7 -> Calendar: 周日=1...周六=7
        weekStartDay.rawValue == 7 ? 1 : weekStartDay.rawValue + 1
    }
    
    // MARK: - 考试通知
    /// 安排单个考试通知
    static func scheduleExamNotification(
        id: String,
        title: String,
        body: String,
        triggerDate: Date
    ) async {
        guard triggerDate > Date() else { return }
        let fullId = examNotificationPrefix + id
        await removeExistingNotifications(with: fullId)
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }
        
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: fullId, content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {}
    }
    
    /// 为所有考试安排通知
    /// - Parameters:
    ///   - exams: 考试列表（包含 examTime 字段）
    ///   - settings: 应用设置
    static func scheduleAllExamNotifications(
        exams: [Any],
        settings: AppSettings
    ) async {
        // 检查是否启用了考试通知
        guard settings.enableExamNotification else { return }
        
        let notificationMinutes = settings.examNotificationTime.rawValue
        
        // 先清除所有旧的考试通知
        await removeAllExamNotifications()
        
        for exam in exams {
            // 使用反射获取考试信息
            let mirror = Mirror(reflecting: exam)
            var courseName: String?
            var examTimeStr: String?
            var examLocation: String?
            var examId: String?
            
            for child in mirror.children {
                switch child.label {
                case "courseName":
                    courseName = child.value as? String
                case "examTime":
                    examTimeStr = child.value as? String
                case "examLocation":
                    examLocation = child.value as? String
                case "id":
                    examId = "\(child.value)"
                default:
                    break
                }
            }
            
            guard let name = courseName,
                  let timeStr = examTimeStr,
                  let id = examId,
                  let examDate = parseExamTime(timeStr) else {
                continue
            }
            let location = examLocation // 允许为 nil
            
            // 计算通知时间
            let notificationDate = examDate.addingTimeInterval(-TimeInterval(notificationMinutes * 60))
            
            // 只为未来的考试安排通知
            if notificationDate > Date() {
                let body: String
                if let location, !location.isEmpty {
                    body = String(format: NSLocalizedString("exam.notification_body", comment: ""), location)
                } else {
                    body = ""
                }
                await scheduleExamNotification(
                    id: id,
                    title: name,
                    body: body,
                    triggerDate: notificationDate
                )
            }
        }
    }
    
    /// 解析考试时间字符串
    /// 支持格式: "2025年12月18日 18:30--20:30" 或 "2025年12月18日 18:30"
    private static func parseExamTime(_ timeString: String) -> Date? {
        AppDateFormatting.parseChineseExamDateTime(timeString)
    }
    
    /// 清除所有考试通知
    static func removeAllExamNotifications() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let examNotificationIds = pending
            .filter { $0.identifier.hasPrefix(examNotificationPrefix) }
            .map { $0.identifier }
        center.removePendingNotificationRequests(withIdentifiers: examNotificationIds)
        center.removeDeliveredNotifications(withIdentifiers: examNotificationIds)
    }
    
    static func removeScheduledNotification(id: String) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.removeDeliveredNotifications(withIdentifiers: [id])
    }
    
    // MARK: - 批量清除
    /// 清除所有课程通知
    static func removeAllCourseNotifications() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let courseNotificationIds = pending
            .filter { $0.identifier.hasPrefix(courseNotificationPrefix) }
            .map { $0.identifier }
        center.removePendingNotificationRequests(withIdentifiers: courseNotificationIds)
        center.removeDeliveredNotifications(withIdentifiers: courseNotificationIds)
    }
}
