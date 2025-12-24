//
//  ICSConverter.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/05.
//

import Foundation
import SwiftUI
import SwiftData

struct ICSConverter {
    struct CourseTemplate {
        let name: String
        let teacher: String
        let location: String
        let weeks: [Int]
        let dayOfWeek: Int
        let timeSlot: Int
        let duration: Int
        let color: String
        
        func toCourse(scheduleId: String) -> Course {
            Course(
                name: name,
                teacher: teacher,
                location: location,
                weeks: weeks,
                dayOfWeek: dayOfWeek,
                timeSlot: timeSlot,
                duration: duration,
                color: color,
                scheduleId: scheduleId
            )
        }
    }
    
    struct ImportResult {
        let scheduleName: String
        let termName: String
        let semesterStartDate: Date
        let courses: [CourseTemplate]
    }
    
    private struct ICSEvent {
        let title: String
        let location: String?
        let description: String?
        let start: Date
        let end: Date
    }
    
    // MARK: - Export
    static func export(schedule: Schedule, courses: [Course], settings: AppSettings) -> String {
        let calendar = Calendar.current
        let tzid = TimeZone.current.identifier
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss"
        formatter.timeZone = TimeZone.current
        let stampFormatter = DateFormatter()
        stampFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        stampFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        guard let semesterWeekStart = calendar.dateInterval(of: .weekOfYear, for: settings.semesterStartDate)?.start else {
            return ""
        }
        
        var lines: [String] = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:ICALENDAR-RS",
            "CALSCALE:GREGORIAN",
            "TIMEZONE-ID:\(tzid)",
            "X-WR-CALNAME:\(schedule.name)",
            "X-WR-TIMEZONE:\(tzid)",
            "NAME:\(schedule.name)"
        ]
        
        for course in courses {
            for week in course.weeks {
                guard week > 0 else { continue }
                let dayOffset = (week - 1) * 7 + (course.dayOfWeek % 7)
                guard let day = calendar.date(byAdding: .day, value: dayOffset, to: semesterWeekStart) else { continue }
                let startMinutes = settings.timeSlotToMinutes(course.timeSlot)
                let durationMinutes = settings.courseDurationInMinutes(startSlot: course.timeSlot, duration: course.duration)
                let startHour = startMinutes / 60
                let startMinute = startMinutes % 60
                guard let startDate = calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: day) else { continue }
                guard let endDate = calendar.date(byAdding: .minute, value: durationMinutes, to: startDate) else { continue }
                let uid = "\(course.id)_week\(week)"
                lines.append(contentsOf: [
                    "BEGIN:VEVENT",
                    "UID:\(uid)",
                    "DTSTAMP:\(stampFormatter.string(from: Date()))",
                    "SUMMARY:\(escapeICS(course.name))",
                    "DESCRIPTION:\(escapeICS(course.teacher))",
                    "DTSTART;TZID=\(tzid):\(formatter.string(from: startDate))",
                    "DTEND;TZID=\(tzid):\(formatter.string(from: endDate))",
                    "LOCATION:\(escapeICS(course.location))",
                    "SEQUENCE:0",
                    "TRANSP:OPAQUE",
                    "END:VEVENT"
                ])
            }
        }
        
        lines.append("END:VCALENDAR")
        return lines.joined(separator: "\n")
    }
    
    // MARK: - Import
    static func importICS(from url: URL, settings: AppSettings) throws -> ImportResult {
        let data = try Data(contentsOf: url)
        guard let content = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "EduPal", code: -2, userInfo: [NSLocalizedDescriptionKey: "无法读取ICS内容"])
        }
        // 先规范化换行，兼容 \r\n / \r
        let normalized = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let unfolded = unfoldICS(normalized)
        let calendarName = extractCalendarName(from: unfolded) ?? url.deletingPathExtension().lastPathComponent
        let events = parseEvents(from: unfolded)
        guard !events.isEmpty else {
            throw NSError(domain: "EduPal", code: -3, userInfo: [NSLocalizedDescriptionKey: "ICS文件中没有事件"])
        }
        guard let earliest = events.map({ $0.start }).min() else {
            throw NSError(domain: "EduPal", code: -4, userInfo: [NSLocalizedDescriptionKey: "无法确定起始时间"])
        }
        let calendar = Calendar.current
        guard let semesterWeekStart = calendar.dateInterval(of: .weekOfYear, for: earliest)?.start else {
            throw NSError(domain: "EduPal", code: -5, userInfo: [NSLocalizedDescriptionKey: "无法计算学期开始周"])
        }
        let termName = buildTermName(for: earliest)
        let templates = convertEventsToCourses(events: events, settings: settings, semesterStart: semesterWeekStart)
        return ImportResult(
            scheduleName: calendarName,
            termName: termName,
            semesterStartDate: semesterWeekStart,
            courses: templates
        )
    }
    
    // MARK: - Helpers
    private static func buildTermName(for date: Date) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let semester = (2...7).contains(month) ? "春季" : "秋季"
        return "\(year)年\(semester)学期"
    }
    
    private static func escapeICS(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
    
    private static func unfoldICS(_ content: String) -> String {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        var unfolded: [String] = []
        for line in lines {
            if let last = unfolded.last, line.first == " " || line.first == "\t" {
                unfolded[unfolded.count - 1] = last + line.dropFirst()
            } else {
                unfolded.append(String(line))
            }
        }
        return unfolded.joined(separator: "\n")
    }
    
    private static func extractCalendarName(from content: String) -> String? {
        for line in content.split(separator: "\n") {
            if line.hasPrefix("X-WR-CALNAME:") {
                return String(line.dropFirst("X-WR-CALNAME:".count))
            }
        }
        return nil
    }
    
    private static func parseEvents(from content: String) -> [ICSEvent] {
        var events: [ICSEvent] = []
        let lines = content.split(separator: "\n")
        var current: [String: String] = [:]
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            if line == "BEGIN:VEVENT" {
                current = [:]
            } else if line == "END:VEVENT" {
                if let event = buildEvent(from: current) {
                    events.append(event)
                }
                current = [:]
            } else {
                let parts = line.split(separator: ":", maxSplits: 1)
                guard parts.count == 2 else { continue }
                let key = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
                let value = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
                current[key] = value
            }
        }
        return events
    }
    
    private static func buildEvent(from dict: [String: String]) -> ICSEvent? {
        guard let rawStart = dict.first(where: { $0.key.hasPrefix("DTSTART") })?.key,
              let startValue = dict[rawStart],
              let startDate = parseDate(from: rawStart, value: startValue),
              let rawEnd = dict.first(where: { $0.key.hasPrefix("DTEND") })?.key,
              let endValue = dict[rawEnd],
              let endDate = parseDate(from: rawEnd, value: endValue) else {
            return nil
        }
        let title = dict["SUMMARY"] ?? ""
        let location = dict["LOCATION"]
        let description = dict["DESCRIPTION"]
        return ICSEvent(title: title, location: location, description: description, start: startDate, end: endDate)
    }
    
    private static func parseDate(from key: String, value: String) -> Date? {
        let timezone: TimeZone
        if let range = key.range(of: "TZID=") {
            let tzString = key[range.upperBound...]
            if let tzid = tzString.split(separator: ";").first {
                timezone = TimeZone(identifier: String(tzid)) ?? TimeZone.current
            } else {
                timezone = TimeZone.current
            }
        } else if value.hasSuffix("Z") {
            timezone = TimeZone(secondsFromGMT: 0) ?? TimeZone.current
        } else {
            timezone = TimeZone.current
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedValue = trimmed.hasSuffix("Z") ? String(trimmed.dropLast()) : trimmed
        let formats = ["yyyyMMdd'T'HHmmss", "yyyyMMdd'T'HHmm", "yyyyMMdd"]
        let formatter = DateFormatter()
        formatter.timeZone = timezone
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: cleanedValue) {
                return date
            }
        }
        return nil
    }
    
    private static func convertEventsToCourses(events: [ICSEvent], settings: AppSettings, semesterStart: Date) -> [CourseTemplate] {
        let calendar = Calendar.current
        let classTimes = ClassTimeManager.classTimes
        var courses: [String: CourseTemplate] = [:]
        guard let semesterWeekStart = calendar.dateInterval(of: .weekOfYear, for: semesterStart)?.start else { return [] }
        
        for event in events {
            let startMinutes = calendar.component(.hour, from: event.start) * 60 + calendar.component(.minute, from: event.start)
            let endMinutes = calendar.component(.hour, from: event.end) * 60 + calendar.component(.minute, from: event.end)
            guard endMinutes > startMinutes else { continue }
            guard let slotIndex = classTimes.firstIndex(where: { abs($0.startTimeInMinutes - startMinutes) <= 5 }) else { continue }
            var endSlot = slotIndex
            var currentEnd = classTimes[slotIndex].endTimeInMinutes
            while endSlot + 1 < classTimes.count && currentEnd < endMinutes - 2 {
                endSlot += 1
                currentEnd = classTimes[endSlot].endTimeInMinutes
            }
            let duration = max(1, endSlot - slotIndex + 1)
            guard let eventWeekStart = calendar.dateInterval(of: .weekOfYear, for: event.start)?.start else { continue }
            let daysBetween = calendar.dateComponents([.day], from: semesterWeekStart, to: eventWeekStart).day ?? 0
            let weekNumber = daysBetween / 7 + 1
            guard weekNumber > 0 else { continue }
            let weekday = calendar.component(.weekday, from: event.start)
            let dayOfWeek = weekday == 1 ? 7 : weekday - 1
            let key = "\(event.title)_\(event.description ?? "")_\(event.location ?? "")_\(dayOfWeek)_\(slotIndex + 1)"
            let colorIndex = abs(key.hashValue) % highContrastColors.count
            let color = highContrastColors[colorIndex]
            if var existing = courses[key] {
                var weeks = Set(existing.weeks)
                weeks.insert(weekNumber)
                existing = CourseTemplate(
                    name: existing.name,
                    teacher: existing.teacher,
                    location: existing.location,
                    weeks: Array(weeks).sorted(),
                    dayOfWeek: existing.dayOfWeek,
                    timeSlot: existing.timeSlot,
                    duration: existing.duration,
                    color: existing.color
                )
                courses[key] = existing
            } else {
                let template = CourseTemplate(
                    name: event.title.isEmpty ? "未命名课程" : event.title,
                    teacher: event.description ?? "",
                    location: event.location ?? "",
                    weeks: [weekNumber],
                    dayOfWeek: dayOfWeek,
                    timeSlot: slotIndex + 1,
                    duration: duration,
                    color: color
                )
                courses[key] = template
            }
        }
        return courses.values.sorted { $0.name < $1.name }
    }
    
    private static let highContrastColors: [String] = [
        "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFD93D", "#FF9E9E", "#A8D8EA", "#FF90EE", "#98FB98", "#FFA500",
        "#87CEEB", "#F08080", "#20B2AA", "#FFB6C1", "#3CB371", "#DDA0DD", "#F7DC6F", "#BB8FCE", "#85C1E9", "#F8B88B"
    ]
}
