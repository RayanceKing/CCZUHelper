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
    private static let managedCalendarOwnedKey = "calendarSync.managedCalendarOwned"
    private static let eventURLScheme = "edupal://schedule"
    private static let notesPrefix = "[EduPal] "

    private static func sanitizedTeacherNotes(_ teacher: String) -> String? {
        let cleaned = teacher
            .replacingOccurrences(of: "[EduPal]", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    /// Include a full semester even when courses were removed, plus a week at each
    /// boundary to catch dates shifted by the legacy Sunday-based calculation.
    /// EventKit truncates queries longer than four years; query in one-year chunks.
    static func resyncSearchIntervals(context: ScheduleDateContext, weeks: Set<Int>, calendar: Calendar = .current) -> [DateInterval] {
        let firstDay = context.startOfWeek(containing: context.semesterStartDate, calendar: calendar)
        guard var start = calendar.date(byAdding: .day, value: -7, to: firstDay),
              let end = calendar.date(byAdding: .day, value: (max(30, weeks.max() ?? 0) + 1) * 7, to: firstDay) else { return [] }
        var intervals: [DateInterval] = []
        while start < end {
            guard let nextYear = calendar.date(byAdding: .year, value: 1, to: start), nextYear > start else { break }
            let next = min(nextYear, end)
            intervals.append(DateInterval(start: start, end: next))
            start = next
        }
        return intervals
    }

    /// 重同步时仅清理当前学期、当前同步目标日历中的受管事件。
    private static func clearManagedEventsForResync(primaryCalendar: EKCalendar, intervals: [DateInterval]) throws {
        let isOwnedCalendar = primaryCalendar.calendarIdentifier == UserDefaults.standard.string(forKey: calendarIdentifierKey)
            && UserDefaults.standard.bool(forKey: managedCalendarOwnedKey)
        var removedIDs = Set<String>()
        for interval in intervals {
            let predicate = eventStore.predicateForEvents(withStart: interval.start, end: interval.end, calendars: [primaryCalendar])
            for event in eventStore.events(matching: predicate) {
                let hasURLMark = (event.url?.absoluteString == eventURLScheme)
                let hasLegacyNotesMark = (event.notes?.hasPrefix(notesPrefix) ?? false)
                let isWeekMarker = isOwnedCalendar && event.isAllDay && event.title.hasPrefix("第") && event.title.hasSuffix("周")
                if hasURLMark || hasLegacyNotesMark || isWeekMarker {
                    // An event spanning two search intervals can be returned twice.
                    guard removedIDs.insert(event.calendarItemIdentifier).inserted else { continue }
                    try eventStore.remove(event, span: .thisEvent, commit: false)
                }
            }
        }
    }
    
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
                UserDefaults.standard.set(true, forKey: managedCalendarOwnedKey)
                return calendar
            } catch {
                // 创建失败（如 Code=17），继续回退到已有可写日历
            }
        }
        if let defaultCalendar = eventStore.defaultCalendarForNewEvents, defaultCalendar.allowsContentModifications {
            UserDefaults.standard.set(defaultCalendar.calendarIdentifier, forKey: calendarIdentifierKey)
            UserDefaults.standard.set(false, forKey: managedCalendarOwnedKey)
            return defaultCalendar
        }
        if let writable = eventStore.calendars(for: .event).first(where: { $0.allowsContentModifications }) {
            UserDefaults.standard.set(writable.calendarIdentifier, forKey: calendarIdentifierKey)
            UserDefaults.standard.set(false, forKey: managedCalendarOwnedKey)
            return writable
        }
        throw SyncError.calendarNotFound
    }

    /// 获取由应用管理并可删除的日历（关闭同步时使用）
    private static func managedCalendarsForDeletion() -> [EKCalendar] {
        var result: [EKCalendar] = []
        let calendars = eventStore.calendars(for: .event)
        let owned = UserDefaults.standard.bool(forKey: managedCalendarOwnedKey)
        let savedID = UserDefaults.standard.string(forKey: calendarIdentifierKey)

        // 首选：删除标题为 EduPal 的专用日历
        for cal in calendars where cal.title == "EduPal" {
            result.append(cal)
        }

        // 兜底：若明确标记为应用创建，补充 savedID 对应日历
        if owned,
           let savedID,
           let saved = eventStore.calendar(withIdentifier: savedID),
           !result.contains(where: { $0.calendarIdentifier == saved.calendarIdentifier }) {
            result.append(saved)
        }

        return result
    }
    
    /// 同步课程到系统日历
    static func sync(schedule: Schedule, courses: [Course], settings: AppSettings) async throws {
        try await requestFullAccess()
        let calendar = try ensureCalendar()
        let tz = TimeZone.current
        let calendarUtil = Calendar.current
        let context = ScheduleDateContext(semesterStartDate: settings.semesterStartDate, weekStartDay: settings.weekStartDay.rawValue)

        let weekNumbers = Set(
            courses
                .flatMap { $0.weeks }
                .filter { $0 > 0 }
        )

        // 清除本学期旧事件（包括旧算法错位的日期），再写入正确日期。
        try clearManagedEventsForResync(primaryCalendar: calendar, intervals: resyncSearchIntervals(context: context, weeks: weekNumbers, calendar: calendarUtil))

        for course in courses {
            for week in course.weeks where week > 0 {
                guard let day = context.date(forWeek: week, dayOfWeek: course.dayOfWeek, calendar: calendarUtil) else { continue }
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
                event.notes = sanitizedTeacherNotes(course.teacher)
                if let url = URL(string: eventURLScheme) {
                    event.url = url
                }
                event.startDate = startDate
                event.endDate = endDate
                try eventStore.save(event, span: .thisEvent, commit: false)
            }
        }

        // 额外同步“第几周”全天事件（每周持续一周）
        // 对 EventKit 全天事件，部分客户端会将结束日按“包含边界日”显示，
        // 因此这里使用“开始日 + 6天”的结束日期，确保周起始日不会出现双周重叠。
        for week in weekNumbers.sorted() {
            guard let weekStartDate = context.date(forWeek: week, dayOfWeek: context.weekStartDay, calendar: calendarUtil) else { continue }
            let startOfDay = calendarUtil.startOfDay(for: weekStartDate)
            guard let endDate = calendarUtil.date(byAdding: .day, value: 6, to: startOfDay) else { continue }

            let weekEvent = EKEvent(eventStore: eventStore)
            weekEvent.calendar = calendar
            weekEvent.timeZone = nil
            weekEvent.isAllDay = true
            weekEvent.title = "第\(week)周"
            weekEvent.notes = nil
            if let url = URL(string: eventURLScheme) {
                weekEvent.url = url
            }
            weekEvent.startDate = startOfDay
            weekEvent.endDate = endDate
            try eventStore.save(weekEvent, span: .thisEvent, commit: false)
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
            try await requestFullAccess()
            try await clearAllEvents()

            let calendars = managedCalendarsForDeletion()
            guard !calendars.isEmpty else {
                UserDefaults.standard.removeObject(forKey: calendarIdentifierKey)
                UserDefaults.standard.removeObject(forKey: managedCalendarOwnedKey)
                return
            }

            for calendar in calendars where calendar.allowsContentModifications {
                do {
                    try eventStore.removeCalendar(calendar, commit: false)
                } catch {
                    // 单个日历删除失败不影响后续删除
                }
            }

            do {
                try eventStore.commit()
            } catch {
                // commit 失败时保持静默，避免打断用户关闭开关流程
            }

            UserDefaults.standard.removeObject(forKey: calendarIdentifierKey)
            UserDefaults.standard.removeObject(forKey: managedCalendarOwnedKey)
        } catch {
            // 关闭流程不抛错到 UI
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
