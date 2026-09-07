import Foundation

/// Shared by the timetable, App Intents and widget. Weekdays use Monday=1…Sunday=7.
nonisolated struct ScheduleDateContext: Codable {
    let semesterStartDate: Date
    let weekStartDay: Int

    func weekNumber(for date: Date, calendar: Calendar = .current) -> Int {
        func weekStart(_ date: Date) -> Date {
            let weekday = calendar.component(.weekday, from: date)
            let firstWeekday = (weekStartDay % 7) + 1
            let offset = (weekday - firstWeekday + 7) % 7
            return calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: date))!
        }
        let days = calendar.dateComponents([.day], from: weekStart(semesterStartDate), to: weekStart(date)).day ?? 0
        return days / 7 + 1
    }

    func includes(weeks: [Int], dayOfWeek: Int, on date: Date, calendar: Calendar = .current) -> Bool {
        let week = weekNumber(for: date, calendar: calendar)
        let weekday = (calendar.component(.weekday, from: date) + 5) % 7 + 1
        return week > 0 && weeks.contains(week) && dayOfWeek == weekday
    }
}

/// Full semester data; never discard weeks when exporting the phone widget cache.
nonisolated struct ScheduleWidgetCourse: Codable {
    let name: String
    let teacher: String
    let location: String
    let timeSlot: Int
    let duration: Int
    let color: String
    let dayOfWeek: Int
    var weeks: [Int] = []
}

nonisolated struct WidgetScheduleSnapshot: Codable {
    static let fileName = "widget_schedule.json"
    let context: ScheduleDateContext
    let courses: [ScheduleWidgetCourse]

    func courses(on date: Date, calendar: Calendar = .current) -> [ScheduleWidgetCourse] {
        courses.filter {
            context.includes(weeks: $0.weeks, dayOfWeek: $0.dayOfWeek, on: date, calendar: calendar)
        }.sorted { $0.timeSlot < $1.timeSlot }
    }
}

nonisolated enum ScheduleSelection {
    /// Keep a multi-period class through breaks and until the end of its final period.
    static func currentOrNext<C>(
        in courses: [C], at date: Date, calendar: Calendar = .current,
        timeSlot: (C) -> Int, duration: (C) -> Int,
        classTime: (Int) -> ClassTimeConfig?
    ) -> C? {
        let minutes = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let sorted = courses.sorted { timeSlot($0) < timeSlot($1) }
        if let ongoing = sorted.first(where: { course in
            guard let start = classTime(timeSlot(course)),
                  let end = classTime(timeSlot(course) + max(1, duration(course)) - 1) else { return false }
            return start.startTimeInMinutes <= minutes && minutes < end.endTimeInMinutes
        }) {
            return ongoing
        }
        return sorted.first { course in
            guard let start = classTime(timeSlot(course)) else { return false }
            return start.startTimeInMinutes > minutes
        }
    }
}
