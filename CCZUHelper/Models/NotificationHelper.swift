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
    
    // MARK: - 权限请求
    static func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            do {
                _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                print("Failed to request notification authorization: \(error)")
            }
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
        let content = UNMutableNotificationContent()
        content.title = courseName
        content.body = "location_reminder".localized(with: location)
        content.sound = .default
        
        #if os(iOS)
        if #available(iOS 16.1, *) {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            if settings.badgeSetting == .enabled {
                do {
                    try await UNUserNotificationCenter.current().setBadgeCount(1)
                } catch {
                    print("Failed to set badge count: \(error)")
                }
            }
            content.badge = NSNumber(value: 1)
        } else {
            // iOS 16以下使用旧API
            content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
        }
        #endif
        
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: notificationDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: notificationId, content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ Scheduled course notification for \(courseName) at \(notificationDate)")
        } catch {
            print("❌ Failed to schedule course notification: \(error)")
        }
    }
    
    /// 移除课程通知
    static func removeCourseNotification(courseId: String) async {
        let notificationId = courseNotificationPrefix + courseId
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId])
        print("🗑️ Removed course notification for \(courseId)")
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
        
        for course in courses {
            // 获取课程所在周的开始日期
            _ = calendar.component(.weekOfYear, from: today)
            let currentYear = calendar.component(.yearForWeekOfYear, from: today)
            
            // 检查课程是否在有效周次范围内
            for week in course.weeks {
                // 计算该周的日期
                var weekComps = DateComponents()
                weekComps.yearForWeekOfYear = currentYear
                weekComps.weekOfYear = week
                weekComps.weekday = course.dayOfWeek + 1  // weekday 1=周日，需要转换
                
                guard let courseDate = calendar.date(from: weekComps) else { continue }
                
                // 只为未来的课程安排通知
                if courseDate > today {
                    // 计算课程的开始时间
                    let classStartMinutes = AppSettings.classTimes[course.timeSlot - 1].startTimeInMinutes
                    let hour = classStartMinutes / 60
                    let minute = classStartMinutes % 60
                    
                    var timeComps = calendar.dateComponents([.year, .month, .day], from: courseDate)
                    timeComps.hour = hour
                    timeComps.minute = minute
                    
                    guard let classTime = calendar.date(from: timeComps) else { continue }
                    
                    // 生成唯一的课程通知ID（包含周次信息）
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
    }
    
    // MARK: - 考试通知
    static func scheduleExamNotification(
        id: String,
        title: String,
        body: String,
        triggerDate: Date
    ) async {
        guard triggerDate > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: examNotificationPrefix + id, content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Failed to schedule exam notification: \(error)")
        }
    }
    
    static func removeScheduledNotification(id: String) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
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
        print("🗑️ Removed all course notifications")
    }
}
