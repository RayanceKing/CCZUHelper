import XCTest
@testable import CCZUHelper

final class ScheduleSelectionTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    private func date(_ value: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: value)!
    }

    // Synthetic reproduction, not a downloaded student timetable: physics starts
    // in week 2 while Python occurs every week. A week-1 filter loses physics.
    private var snapshot: WidgetScheduleSnapshot {
        WidgetScheduleSnapshot(
            context: ScheduleDateContext(semesterStartDate: date("2026-08-31 12:00"), weekStartDay: 1),
            courses: [
                course("Python", weeks: [1, 2, 3], slot: 6, duration: 3),
                course("大学物理实验", weeks: [2], slot: 3, duration: 3)
            ]
        )
    }

    private func course(_ name: String, weeks: [Int], slot: Int, duration: Int = 1) -> ScheduleWidgetCourse {
        ScheduleWidgetCourse(name: name, teacher: "", location: "", timeSlot: slot,
                             duration: duration, color: "#007AFF", dayOfWeek: 1, weeks: weeks)
    }

    @MainActor
    private func next(at time: String, courses: [ScheduleWidgetCourse]? = nil) -> String? {
        let now = date("2026-09-07 \(time)")
        return ScheduleSelection.currentOrNext(
            in: courses ?? snapshot.courses(on: now, calendar: calendar), at: now, calendar: calendar,
            timeSlot: { $0.timeSlot }, duration: { $0.duration },
            classTime: { ClassTimeManager.shared.getClassTime(for: $0) }
        )?.name
    }

    func testWeekTwoIncludesPhysicsBeforePython() {
        XCTAssertEqual(snapshot.courses.filter { $0.weeks.contains(1) }.map(\.name), ["Python"])
        XCTAssertEqual(snapshot.courses(on: date("2026-09-07 09:00"), calendar: calendar).map(\.name),
                       ["大学物理实验", "Python"])
    }

    func testOnePersistedSnapshotAdvancesWeeksWithoutAppRefresh() throws {
        let data = try JSONEncoder().encode(snapshot)
        let restored = try JSONDecoder().decode(WidgetScheduleSnapshot.self, from: data)
        XCTAssertEqual(restored.courses(on: date("2026-08-31 09:00"), calendar: calendar).map(\.name), ["Python"])
        XCTAssertEqual(restored.courses(on: date("2026-09-07 09:00"), calendar: calendar).map(\.name), ["大学物理实验", "Python"])
        XCTAssertEqual(restored.courses(on: date("2026-09-14 09:00"), calendar: calendar).map(\.name), ["Python"])
    }

    func testNoCoursesBeforeSemesterOrOnWrongWeekday() {
        XCTAssertTrue(snapshot.courses(on: date("2026-08-24 09:00"), calendar: calendar).isEmpty)
        XCTAssertTrue(snapshot.courses(on: date("2026-09-08 09:00"), calendar: calendar).isEmpty)
        XCTAssertTrue(snapshot.courses(on: date("2026-09-21 09:00"), calendar: calendar).isEmpty)
    }

    func testMondayBoundaryIgnoresTimeOfDay() {
        XCTAssertEqual(snapshot.context.weekNumber(for: date("2026-09-06 23:59"), calendar: calendar), 1)
        XCTAssertEqual(snapshot.context.weekNumber(for: date("2026-09-07 00:00"), calendar: calendar), 2)
    }

    func testSundayWeekStartAndYearBoundary() {
        let context = ScheduleDateContext(semesterStartDate: date("2026-12-28 12:00"), weekStartDay: 7)
        XCTAssertEqual(context.weekNumber(for: date("2027-01-02 23:59"), calendar: calendar), 1)
        XCTAssertEqual(context.weekNumber(for: date("2027-01-03 00:00"), calendar: calendar), 2)
        XCTAssertTrue(context.includes(weeks: [2], dayOfWeek: 7, on: date("2027-01-03 10:00"), calendar: calendar))
    }

    @MainActor
    func testPhysicsRemainsNextBeforeStartDuringClassAndBreak() {
        for time in ["09:00", "09:45", "10:00", "10:30", "11:59"] {
            XCTAssertEqual(next(at: time), "大学物理实验", "at \(time)")
        }
    }

    @MainActor
    func testSwitchesToPythonOnlyWhenPhysicsEnds() {
        XCTAssertEqual(next(at: "12:00"), "Python")
        XCTAssertEqual(next(at: "13:30"), "Python")
        XCTAssertNil(next(at: "15:55"))
    }

    @MainActor
    func testEveningAndNinthPeriodAreNotTreatedAsEightAM() {
        let courses = [course("晚课", weeks: [2], slot: 10), course("第九节", weeks: [2], slot: 9)]
        XCTAssertEqual(next(at: "15:56", courses: courses), "第九节")
        XCTAssertEqual(next(at: "16:40", courses: courses), "晚课")
        XCTAssertEqual(next(at: "18:30", courses: courses), "晚课")
        XCTAssertNil(next(at: "19:10", courses: courses))
    }
}
