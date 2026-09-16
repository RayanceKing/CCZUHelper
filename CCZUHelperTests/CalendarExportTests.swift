import XCTest
@testable import CCZUHelper

@MainActor
final class CalendarExportTests: XCTestCase {
    private func calendar(firstWeekday: Int = 2, timeZone: String = "Asia/Shanghai") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone)!
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    private func date(_ value: String, calendar: Calendar) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: value)!
    }

    private func course(day: Int, weeks: [Int] = [1, 2]) -> Course {
        Course(name: "课程\(day)", teacher: "教师", location: "教室", weeks: weeks,
               dayOfWeek: day, timeSlot: 1, duration: 2, scheduleId: "calendar-regression")
    }

    func testMondayDoesNotMoveToTuesdayWhenSystemWeekStartsOnMonday() throws {
        let calendar = calendar()
        let context = ScheduleDateContext(semesterStartDate: date("2026-08-31 12:00", calendar: calendar), weekStartDay: 1)
        XCTAssertEqual(try XCTUnwrap(context.date(forWeek: 2, dayOfWeek: 1, calendar: calendar)),
                       date("2026-09-07 00:00", calendar: calendar))
        XCTAssertEqual(try XCTUnwrap(context.date(forWeek: 2, dayOfWeek: 7, calendar: calendar)),
                       date("2026-09-13 00:00", calendar: calendar))
    }

    func testAllWeekdaysAgreeWithTimetableForEveryAppAndSystemWeekStart() throws {
        // Include a midweek, non-midnight semester anchor. Locale must not alter dates.
        for appStart in 1...7 {
            for systemStart in 1...7 {
                let calendar = calendar(firstWeekday: systemStart)
                let context = ScheduleDateContext(semesterStartDate: date("2026-09-02 12:00", calendar: calendar), weekStartDay: appStart)
                for week in [1, 2, 16, 22] {
                    for day in 1...7 {
                        let actual = try XCTUnwrap(context.date(forWeek: week, dayOfWeek: day, calendar: calendar))
                        XCTAssertEqual((calendar.component(.weekday, from: actual) + 5) % 7 + 1, day)
                        XCTAssertEqual(context.weekNumber(for: actual, calendar: calendar), week)
                        XCTAssertTrue(context.includes(weeks: [week], dayOfWeek: day, on: actual, calendar: calendar))
                        XCTAssertEqual(calendar.component(.hour, from: actual), 0)
                    }
                }
            }
        }
    }

    func testSundayWeekStartAcrossYearBoundary() throws {
        let calendar = calendar()
        let context = ScheduleDateContext(semesterStartDate: date("2026-12-30 12:00", calendar: calendar), weekStartDay: 7)
        XCTAssertEqual(try XCTUnwrap(context.date(forWeek: 2, dayOfWeek: 7, calendar: calendar)),
                       date("2027-01-03 00:00", calendar: calendar))
        XCTAssertEqual(try XCTUnwrap(context.date(forWeek: 2, dayOfWeek: 1, calendar: calendar)),
                       date("2027-01-04 00:00", calendar: calendar))
    }

    func testCalendarDaysStayAtMidnightAcrossDaylightSavingChange() throws {
        let calendar = calendar(timeZone: "America/New_York")
        let context = ScheduleDateContext(semesterStartDate: date("2026-03-04 12:00", calendar: calendar), weekStartDay: 1)
        XCTAssertEqual(try XCTUnwrap(context.date(forWeek: 2, dayOfWeek: 1, calendar: calendar)),
                       date("2026-03-09 00:00", calendar: calendar))
    }

    func testInvalidWeekOrWeekdayDoesNotProduceAnEventDate() {
        let context = ScheduleDateContext(semesterStartDate: Date(), weekStartDay: 1)
        XCTAssertNil(context.date(forWeek: 0, dayOfWeek: 1))
        XCTAssertNil(context.date(forWeek: -1, dayOfWeek: 1))
        XCTAssertNil(context.date(forWeek: 1, dayOfWeek: 0))
        XCTAssertNil(context.date(forWeek: 1, dayOfWeek: 8))
    }

    func testICSExportsExactMondaySundayAndWeekMarkerDates() {
        for systemStart in [1, 2] {
            let calendar = calendar(firstWeekday: systemStart)
            let context = ScheduleDateContext(semesterStartDate: date("2026-08-31 12:00", calendar: calendar), weekStartDay: 1)
            let ics = ICSConverter.export(schedule: Schedule(name: "回归课表", termName: "秋季"),
                                          courses: [course(day: 1), course(day: 7)], context: context, calendar: calendar)
            for day in ["20260831", "20260906", "20260907", "20260913"] {
                XCTAssertTrue(ics.contains("DTSTART;TZID=Asia/Shanghai:\(day)T080000"))
                XCTAssertTrue(ics.contains("DTEND;TZID=Asia/Shanghai:\(day)T092500"))
            }
            XCTAssertTrue(ics.contains("SUMMARY:第1周\nDTSTART;VALUE=DATE:20260831\nDTEND;VALUE=DATE:20260907"))
            XCTAssertTrue(ics.contains("SUMMARY:第2周\nDTSTART;VALUE=DATE:20260907\nDTEND;VALUE=DATE:20260914"))
        }
    }

    func testICSRoundTripPreservesWeekNumbersAndWeekdaysWhenSystemWeekDiffers() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".ics")
        defer { try? FileManager.default.removeItem(at: url) }
        for appStart in [1, 7] {
            let calendar = calendar(firstWeekday: appStart == 1 ? 1 : 2)
            let context = ScheduleDateContext(semesterStartDate: date("2026-08-31 12:00", calendar: calendar), weekStartDay: appStart)
            let original = (1...7).map { course(day: $0, weeks: [1, 2, 16]) }
            let ics = ICSConverter.export(schedule: Schedule(name: "回归课表", termName: "秋季"),
                                          courses: original, context: context, calendar: calendar)
            try Data(ics.utf8).write(to: url)
            let imported = try ICSConverter.importICS(from: url, weekStartDay: appStart, calendar: calendar)
            XCTAssertEqual(imported.semesterStartDate, context.startOfWeek(containing: context.semesterStartDate, calendar: calendar))
            XCTAssertEqual(imported.courses.count, 7)
            for course in imported.courses {
                XCTAssertEqual(course.weeks, [1, 2, 16])
                XCTAssertEqual(course.name, "课程\(course.dayOfWeek)")
                XCTAssertEqual(course.timeSlot, 1)
                XCTAssertEqual(course.duration, 2)
            }
        }
    }

    func testResyncRangeCoversLegacyShiftedDatesAndRemovedCourses() throws {
        for systemStart in 1...7 {
            let calendar = calendar(firstWeekday: systemStart)
            for appStart in 1...7 {
                let context = ScheduleDateContext(semesterStartDate: date("2026-09-02 12:00", calendar: calendar), weekStartDay: appStart)
                // Even an empty updated schedule must remove the semester's old events.
                let intervals = CalendarSyncManager.resyncSearchIntervals(context: context, weeks: [], calendar: calendar)
                let legacyStart = try XCTUnwrap(calendar.dateInterval(of: .weekOfYear, for: context.semesterStartDate)?.start)
                for week in [1, 22, 30] {
                    for day in 1...7 {
                        let oldDate = try XCTUnwrap(calendar.date(byAdding: .day, value: (week - 1) * 7 + day % 7, to: legacyStart))
                        XCTAssertTrue(intervals.contains { $0.contains(oldDate) })
                    }
                }
            }
        }
    }

    func testLongResyncRangesAreSplitBelowEventKitLimit() throws {
        let calendar = calendar()
        let context = ScheduleDateContext(semesterStartDate: date("2026-08-31 12:00", calendar: calendar), weekStartDay: 1)
        let intervals = CalendarSyncManager.resyncSearchIntervals(context: context, weeks: [300], calendar: calendar)
        XCTAssertGreaterThan(intervals.count, 1)
        for interval in intervals {
            XCTAssertLessThanOrEqual(interval.duration, 367 * 24 * 60 * 60)
        }
        for (previous, next) in zip(intervals, intervals.dropFirst()) {
            XCTAssertEqual(previous.end, next.start)
        }
        let lastCourse = try XCTUnwrap(context.date(forWeek: 300, dayOfWeek: 7, calendar: calendar))
        XCTAssertTrue(intervals.contains { $0.contains(lastCourse) })
    }
}
