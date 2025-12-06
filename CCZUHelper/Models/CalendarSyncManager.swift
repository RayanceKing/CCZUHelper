//
//  CalendarSyncManager.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/05.
//

import Foundation
import EventKit

struct CalendarSyncManager {
    private static let eventStore = EKEventStore()
    private static let calendarIdentifierKey = "calendarSync.calendarIdentifier"
    
    enum SyncError: Error {
        case accessDenied
        case accessRestricted
        case calendarNotFound
    }
    
    /// 请求日历权限（仅写入）
    static func requestAccess() async throws {
        if #available(iOS 17.0, macOS 14.0, *) {
            let status = EKEventStore.authorizationStatus(for: .event)
            if status == .fullAccess || status == .writeOnly { return }
            if status == .denied { throw SyncError.accessDenied }
            if status == .restricted { throw SyncError.accessRestricted }
            let granted = try await eventStore.requestWriteOnlyAccessToEvents()
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
           let calendar = eventStore.calendar(withIdentifier: id) {
            return calendar
        }
        guard let source = eventStore.defaultCalendarForNewEvents?.source ?? eventStore.sources.first(where: { $0.sourceType == .local }) ?? eventStore.sources.first else {
            throw SyncError.calendarNotFound
        }
        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = "CCZUHelper"
        calendar.source = source
        try eventStore.saveCalendar(calendar, commit: true)
        UserDefaults.standard.set(calendar.calendarIdentifier, forKey: calendarIdentifierKey)
        return calendar
    }
    
    /// 清空当前日历下已写入的事件
    private static func removeExistingEvents(calendar: EKCalendar) throws {
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        let oneYearLater = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        let predicate = eventStore.predicateForEvents(withStart: oneYearAgo, end: oneYearLater, calendars: [calendar])
        let events = eventStore.events(matching: predicate)
        for event in events {
            try eventStore.remove(event, span: .thisEvent, commit: false)
        }
        try eventStore.commit()
    }
    
    /// 同步课程到系统日历
    static func sync(schedule: Schedule, courses: [Course], settings: AppSettings) async throws {
        try await requestAccess()
        let calendar = try ensureCalendar()
        try removeExistingEvents(calendar: calendar)
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
                event.notes = course.teacher
                event.startDate = startDate
                event.endDate = endDate
                try eventStore.save(event, span: .thisEvent, commit: false)
            }
        }
        try eventStore.commit()
    }
}
