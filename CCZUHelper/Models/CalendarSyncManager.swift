//
//  CalendarSyncManager.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/05.
//

import Foundation
import EventKit
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

struct CalendarSyncManager {
    private static let eventStore = EKEventStore()
    private static let calendarIdentifierKey = "calendarSync.calendarIdentifier"
    private static let eventURLScheme = "edupal://schedule"
    private static let notesPrefix = "[EduPal] "
    
    /// 查找已存在的 CCZUHelper 日历（不创建新日历）
    private static func findExistingCCZUHelperCalendars() -> [EKCalendar] {
        var result: [EKCalendar] = []
        let calendars = eventStore.calendars(for: .event)
        // 1) 先根据已保存的 identifier 精确匹配
        if let savedID = UserDefaults.standard.string(forKey: calendarIdentifierKey),
           let savedCalendar = eventStore.calendar(withIdentifier: savedID) {
            result.append(savedCalendar)
        }
        // 2) 再补充所有标题为 CCZUHelper 的日历（去重）
        let titled = calendars.filter { $0.title == "EduPal" }
        for cal in titled where !result.contains(where: { $0.calendarIdentifier == cal.calendarIdentifier }) {
            result.append(cal)
        }
        return result
    }
    
    enum SyncError: Error {
        case accessDenied
        case accessRestricted
        case calendarNotFound
    }
    
    /// 请求日历权限（始终索要完整访问权限）
    static func requestAccess() async throws {
        try await requestFullAccess()
    }
    
    /// 请求日历权限（完整访问以支持读写操作）
    static func requestFullAccess() async throws {
        if #available(iOS 17.0, macOS 14.0, *) {
            let status = EKEventStore.authorizationStatus(for: .event)
            if status == .fullAccess { return }
            if status == .denied { throw SyncError.accessDenied }
            if status == .restricted { throw SyncError.accessRestricted }
            let granted = try await eventStore.requestFullAccessToEvents()
            if !granted { throw SyncError.accessDenied }
        } else {
            let status = EKEventStore.authorizationStatus(for: .event)
            if status == .authorized { return }
            if status == .denied { throw SyncError.accessDenied }
            if status == .restricted { throw SyncError.accessRestricted }
            let granted = try await eventStore.requestAccess(to: .event)
            if !granted { throw SyncError.accessDenied }
        }
    }
    
    /// 获取或创建专用日历
    private static func ensureCalendar() throws -> EKCalendar {
        if let id = UserDefaults.standard.string(forKey: calendarIdentifierKey),
           let calendar = eventStore.calendar(withIdentifier: id),
           calendar.allowsContentModifications {
            return calendar
        }
        // 优先尝试在仅写权限下创建专用日历；若失败再回退到可写日历
        if let source = eventStore.defaultCalendarForNewEvents?.source ?? eventStore.sources.first(where: { $0.sourceType == .local }) ?? eventStore.sources.first {
            let calendar = EKCalendar(for: .event, eventStore: eventStore)
            calendar.title = "EduPal"
            calendar.source = source
            do {
                try eventStore.saveCalendar(calendar, commit: true)
                UserDefaults.standard.set(calendar.calendarIdentifier, forKey: calendarIdentifierKey)
                return calendar
            } catch {
                // 创建失败（如 Code=17），继续回退到已有可写日历
            }
        }
        if let defaultCalendar = eventStore.defaultCalendarForNewEvents, defaultCalendar.allowsContentModifications {
            UserDefaults.standard.set(defaultCalendar.calendarIdentifier, forKey: calendarIdentifierKey)
            return defaultCalendar
        }
        if let writable = eventStore.calendars(for: .event).first(where: { $0.allowsContentModifications }) {
            UserDefaults.standard.set(writable.calendarIdentifier, forKey: calendarIdentifierKey)
            return writable
        }
        throw SyncError.calendarNotFound
    }
    
    /// 同步课程到系统日历
    static func sync(schedule: Schedule, courses: [Course], settings: AppSettings) async throws {
        try await requestFullAccess()
        let calendar = try ensureCalendar()
        let tz = TimeZone.current
        let calendarUtil = Calendar.current
        guard let semesterWeekStart = calendarUtil.dateInterval(of: .weekOfYear, for: settings.semesterStartDate)?.start else {
            throw SyncError.calendarNotFound
        }
        for course in courses {
            for week in course.weeks where week > 0 {
                let dayOffset = (week - 1) * 7 + (course.dayOfWeek % 7)
                guard let day = calendarUtil.date(byAdding: .day, value: dayOffset, to: semesterWeekStart) else { continue }
                let startMinutes = settings.timeSlotToMinutes(course.timeSlot)
                let durationMinutes = settings.courseDurationInMinutes(startSlot: course.timeSlot, duration: course.duration)
                let startHour = startMinutes / 60
                let startMinute = startMinutes % 60
                guard let startDate = calendarUtil.date(bySettingHour: startHour, minute: startMinute, second: 0, of: day) else { continue }
                guard let endDate = calendarUtil.date(byAdding: .minute, value: durationMinutes, to: startDate) else { continue }
                let event = EKEvent(eventStore: eventStore)
                event.calendar = calendar
                event.timeZone = tz
                event.title = course.name
                event.location = course.location
                let teacher = course.teacher
                if !teacher.isEmpty {
                    event.notes = notesPrefix + teacher
                } else {
                    event.notes = notesPrefix
                }
                if let url = URL(string: eventURLScheme) {
                    event.url = url
                }
                event.startDate = startDate
                event.endDate = endDate
                try eventStore.save(event, span: .thisEvent, commit: false)
            }
        }
        try eventStore.commit()
    }
    
    /// 删除CCZUHelper日历中的所有日程
    static func clearAllEvents() async throws {
        do {
            // 请求完整访问权限（删除操作需要完整权限）
            try await requestFullAccess()

            // 仅查找已存在的 CCZUHelper 日历
            var targetCalendars = findExistingCCZUHelperCalendars()

            // 额外：扫描所有日历，删除带有我们标记（URL 或 notes 前缀）的事件，防止早期版本写入到其他日历
            let allCalendars = eventStore.calendars(for: .event)
            // 合并去重
            for cal in allCalendars where !targetCalendars.contains(where: { $0.calendarIdentifier == cal.calendarIdentifier }) {
                targetCalendars.append(cal)
            }
            guard !targetCalendars.isEmpty else {
                print("No calendars found to scan. Nothing to clear.")
                return
            }

            var total = 0
            for calendar in targetCalendars {
                let predicate = eventStore.predicateForEvents(withStart: Date.distantPast, end: Date.distantFuture, calendars: [calendar])
                let events = eventStore.events(matching: predicate)
                for event in events {
                    let hasURLMark = (event.url?.absoluteString == eventURLScheme)
                    let hasNotesMark = (event.notes?.hasPrefix(notesPrefix) ?? false)
                    let isCCZUCalendar = (calendar.title == "EduPal")
                    // 仅当事件有我们的标记，或位于 CCZUHelper 日历中时删除
                    if hasURLMark || hasNotesMark || isCCZUCalendar {
                        try eventStore.remove(event, span: .thisEvent, commit: false)
                        total += 1
                    }
                }
            }
            try eventStore.commit()
            print("Successfully cleared \(total) calendar events")
        } catch {
            print("Failed to clear calendar events: \(error)")
            // 静默处理错误，避免影响关闭同步的流程
        }
    }
    
    /// 当用户关闭“同步到日历”时调用，删除日历中的所有课表
    static func disableSyncAndClear() async {
        do {
            try await clearAllEvents()
        } catch {
            // 已在 clearAllEvents 内部进行错误处理，这里无需额外处理
        }
    }
    
    /// 更激进的清理：根据课程标题与学期时间范围，删除所有日历中的匹配事件
    /// 调用场景：关闭“同步到日历”时，若 `clearAllEvents()` 未能清除干净，可调用此方法
    static func clearEventsForCourses(_ courses: [Course], settings: AppSettings) async {
        do {
            try await requestFullAccess()
            let calendarUtil = Calendar.current
            // 以学期开始周为基准，向前后扩一段时间，覆盖整个学期
            guard let rangeStart = calendarUtil.date(byAdding: .day, value: -7, to: settings.semesterStartDate) else { return }
            // 估算一个较大的结束范围（例如 30 周），也可根据 settings 提供的周数动态计算
            guard let rangeEnd = calendarUtil.date(byAdding: .day, value: 7 + 30 * 7, to: settings.semesterStartDate) else { return }

            let allCalendars = eventStore.calendars(for: .event)
            let titles = Set(courses.map { $0.name })

            var total = 0
            for calendar in allCalendars {
                let predicate = eventStore.predicateForEvents(withStart: rangeStart, end: rangeEnd, calendars: [calendar])
                let events = eventStore.events(matching: predicate)
                for event in events {
                    // 标记优先，其次按标题匹配课程名
                    let hasURLMark = (event.url?.absoluteString == eventURLScheme)
                    let hasNotesMark = (event.notes?.hasPrefix(notesPrefix) ?? false)
                    if hasURLMark || hasNotesMark || titles.contains(event.title) {
                        do {
                            try eventStore.remove(event, span: .thisEvent, commit: false)
                            total += 1
                        } catch {
                            // 单个事件删除失败，继续尝试删除其他事件
                        }
                    }
                }
            }
            do { try eventStore.commit() } catch {}
            print("Aggressively cleared \(total) events by title & markers in semester range")
        } catch {
            print("Failed to aggressively clear events: \(error)")
        }
    }

    /// 打开应用的系统设置，引导用户授予日历权限。
    static func openAppSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            Task { @MainActor in
                UIApplication.shared.open(url)
            }
        }
        #elseif canImport(AppKit)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            // macOS 可以尝试直接打开到隐私-日历设置，但路径可能因macOS版本而异
            NSWorkspace.shared.open(url)
        } else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
            // 回退到隐私设置面板
            NSWorkspace.shared.open(url)
        } else {
            // 最终回退到应用设置
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        }
        #else
        // 其他平台（如 watchOS, tvOS）可能没有直接打开应用设置的API
        print("Opening app settings is not directly supported on this platform.")
        #endif
    }
}

