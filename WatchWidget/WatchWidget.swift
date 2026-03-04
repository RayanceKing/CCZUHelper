//
//  WatchWidget.swift
//  WatchWidget
//
//  Created by rayanceking on 2026/2/24.
//

import WidgetKit
import SwiftUI

private enum WatchWidgetConstants {
    static let appGroupID = "group.com.stuwang.edupal"
    static let dataFileName = "widget_courses.json"
    static let classTimesFileName = "widget_class_times.json"
}

struct WatchWidgetCourse: Codable, Identifiable {
    let name: String
    let teacher: String
    let location: String
    let timeSlot: Int
    let duration: Int
    let color: String
    let dayOfWeek: Int

    var id: String { "\(name)-\(location)-\(dayOfWeek)-\(timeSlot)" }
}

private struct SlotTime {
    let start: String
    let end: String
}

private let slotTimes: [Int: SlotTime] = [
    // Fallback timetable if synced class time data is unavailable.
    1: SlotTime(start: "08:00", end: "08:40"),
    2: SlotTime(start: "08:45", end: "09:25"),
    3: SlotTime(start: "09:45", end: "10:25"),
    4: SlotTime(start: "10:35", end: "11:15"),
    5: SlotTime(start: "11:20", end: "12:00"),
    6: SlotTime(start: "13:30", end: "14:10"),
    7: SlotTime(start: "14:15", end: "14:55"),
    8: SlotTime(start: "15:15", end: "15:55"),
    9: SlotTime(start: "16:00", end: "16:40"),
    10: SlotTime(start: "18:30", end: "19:10"),
    11: SlotTime(start: "19:15", end: "19:55"),
    12: SlotTime(start: "20:05", end: "20:45")
]

private struct WatchWidgetCourseStore {
    struct WidgetClassTime: Codable {
        let slotNumber: Int
        let start: String
        let end: String
    }

    func loadTodayCourses(now: Date = Date(), calendar: Calendar = .current) -> [WatchWidgetCourse] {
        guard
            let containerURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: WatchWidgetConstants.appGroupID
            )
        else {
            return []
        }

        let fileURL = containerURL.appendingPathComponent(WatchWidgetConstants.dataFileName)
        guard
            let data = try? Data(contentsOf: fileURL),
            let courses = try? JSONDecoder().decode([WatchWidgetCourse].self, from: data)
        else {
            return []
        }

        let weekday = calendar.component(.weekday, from: now)
        let scheduleWeekday = ((weekday + 5) % 7) + 1

        return courses
            .filter { $0.dayOfWeek == scheduleWeekday }
            .sorted { $0.timeSlot < $1.timeSlot }
    }

    func loadClassTimes() -> [Int: SlotTime] {
        guard
            let containerURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: WatchWidgetConstants.appGroupID
            )
        else {
            return slotTimes
        }

        let fileURL = containerURL.appendingPathComponent(WatchWidgetConstants.classTimesFileName)
        guard
            let data = try? Data(contentsOf: fileURL),
            let classTimes = try? JSONDecoder().decode([WidgetClassTime].self, from: data),
            !classTimes.isEmpty
        else {
            return slotTimes
        }

        var map: [Int: SlotTime] = [:]
        for item in classTimes {
            map[item.slotNumber] = SlotTime(start: item.start, end: item.end)
        }
        return map.isEmpty ? slotTimes : map
    }
}

private struct NextCourseSummary {
    let course: WatchWidgetCourse
    let startDate: Date
    let startText: String
}

private func nextCourseSummary(
    from courses: [WatchWidgetCourse],
    classTimes: [Int: SlotTime],
    now: Date = Date(),
    calendar: Calendar = .current
) -> NextCourseSummary? {
    for course in courses {
        guard
            let slot = classTimes[course.timeSlot],
            let startDate = courseStartDate(for: slot.start, now: now, calendar: calendar)
        else {
            continue
        }
        if startDate > now {
            return NextCourseSummary(course: course, startDate: startDate, startText: slot.start)
        }
    }
    return nil
}

private func courseStartDate(for hhmm: String, now: Date, calendar: Calendar) -> Date? {
    let parts = hhmm.split(separator: ":")
    guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else {
        return nil
    }
    return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now)
}

private func countdownText(to date: Date, now: Date = Date()) -> String {
    let seconds = max(0, Int(date.timeIntervalSince(now)))
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60

    if hours > 0 {
        return "\(hours)h \(minutes)m"
    }
    return "\(minutes)m"
}

struct Provider: AppIntentTimelineProvider {
    private let store = WatchWidgetCourseStore()

    func placeholder(in context: Context) -> WatchWidgetEntry {
        WatchWidgetEntry(
            date: Date(),
            nextCourse: WatchWidgetCourse(
                name: "高等数学",
                teacher: "张老师",
                location: "W1708",
                timeSlot: 1,
                duration: 2,
                color: "#4ECDC4",
                dayOfWeek: 1
            ),
            nextCourseStartDate: nil,
            nextCourseStartText: "08:00"
        )
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> WatchWidgetEntry {
        entry(for: Date())
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<WatchWidgetEntry> {
        let now = Date()
        let calendar = Calendar.current
        var entries: [WatchWidgetEntry] = [entry(for: now)]

        for offset in stride(from: 15, through: 180, by: 15) {
            if let date = calendar.date(byAdding: .minute, value: offset, to: now) {
                entries.append(entry(for: date))
            }
        }

        return Timeline(entries: entries, policy: .atEnd)
    }

    func recommendations() -> [AppIntentRecommendation<ConfigurationAppIntent>] {
        [AppIntentRecommendation(intent: ConfigurationAppIntent(), description: "课表")]
    }

    private func entry(for date: Date) -> WatchWidgetEntry {
        let todayCourses = store.loadTodayCourses(now: date)
        let classTimes = store.loadClassTimes()
        let next = nextCourseSummary(from: todayCourses, classTimes: classTimes, now: date)
        return WatchWidgetEntry(
            date: date,
            nextCourse: next?.course,
            nextCourseStartDate: next?.startDate,
            nextCourseStartText: next?.startText
        )
    }
}

struct WatchWidgetEntry: TimelineEntry {
    let date: Date
    let nextCourse: WatchWidgetCourse?
    let nextCourseStartDate: Date?
    let nextCourseStartText: String?
}

private struct WatchRectangularWidgetView: View {
    let entry: WatchWidgetEntry

    var body: some View {
        if let course = entry.nextCourse {
            VStack(alignment: .leading, spacing: 2) {
                Text("下节课")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(course.name)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text(entry.nextCourseStartText ?? "--:--")
                    Image(systemName: "mappin.and.ellipse")
                    Text(course.location)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("今日无课")
                    .font(.footnote.weight(.semibold))
                Text("好好休息")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct WatchInlineWidgetView: View {
    let entry: WatchWidgetEntry

    var body: some View {
        if let course = entry.nextCourse {
            Text("\(entry.nextCourseStartText ?? "--:--") \(course.name)")
        } else {
            Text("今日无课")
        }
    }
}

private struct WatchCircularWidgetView: View {
    let entry: WatchWidgetEntry

    var body: some View {
        if let nextStart = entry.nextCourseStartDate {
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.25), lineWidth: 3)
                Text(countdownText(to: nextStart))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.7)
            }
        } else {
            Image(systemName: "checkmark.circle")
                .widgetAccentable()
        }
    }
}

struct WatchWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: WatchWidgetEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            WatchRectangularWidgetView(entry: entry)
        case .accessoryInline:
            WatchInlineWidgetView(entry: entry)
        case .accessoryCircular:
            WatchCircularWidgetView(entry: entry)
        default:
            WatchRectangularWidgetView(entry: entry)
        }
    }
}

struct WatchWidget: Widget {
    let kind: String = "WatchWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            WatchWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("课表")
        .description("显示今天下节课信息")
        .supportedFamilies([
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCircular
        ])
    }
}

#Preview(as: .accessoryRectangular) {
    WatchWidget()
} timeline: {
    WatchWidgetEntry(
        date: .now,
        nextCourse: WatchWidgetCourse(
            name: "高等数学",
            teacher: "张老师",
            location: "W1708",
            timeSlot: 3,
            duration: 2,
            color: "#4ECDC4",
            dayOfWeek: 2
        ),
        nextCourseStartDate: Calendar.current.date(byAdding: .minute, value: 42, to: .now),
        nextCourseStartText: "10:00"
    )
}
