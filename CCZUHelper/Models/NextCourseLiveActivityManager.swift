//
//  NextCourseLiveActivityManager.swift
//  CCZUHelper
//
//  Created by Codex on 2026/2/23.
//

#if os(iOS) && canImport(ActivityKit)
import ActivityKit
import Foundation

@MainActor
final class NextCourseLiveActivityManager {
    static let shared = NextCourseLiveActivityManager()

    private let liveReminderCourseId = "live_activity_next_course"

    private init() {}

    func refresh(courses: [Course], settings: AppSettings) async {
        if #available(iOS 16.2, *) {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else {
                await endAll()
                return
            }

            guard settings.hasPurchase, settings.enableLiveActivity else {
                await endAll()
                return
            }

            let now = Date()
            let leadTime: TimeInterval = 10 * 60

            // 检查并关闭所有已开始或已结束的课程活动
            for activity in Activity<NextCourseActivityAttributes>.activities {
                // 如果课程已经开始（当前时间 >= 开始时间），立即结束活动
                if activity.content.state.startDate <= now {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }

            guard let next = findNextCourseSession(courses: courses, settings: settings, from: now) else {
                await endAll()
                await NotificationHelper.removeCourseNotification(courseId: liveReminderCourseId)
                return
            }

            // 通知始终安排在课前10分钟
            await NotificationHelper.scheduleCourseNotification(
                courseId: liveReminderCourseId,
                courseName: next.course.name,
                location: next.course.location,
                classTime: next.startDate,
                notificationTime: 10
            )

            // 仅在开课前10分钟内显示实时活动
            let activityStartDate = next.startDate.addingTimeInterval(-leadTime)
            guard now >= activityStartDate && now < next.startDate else {
                await endAll()
                return
            }

            let contentState = NextCourseActivityAttributes.ContentState(
                courseName: next.course.name,
                location: next.course.location,
                startDate: next.startDate,
                endDate: next.endDate,
                progressStartDate: activityStartDate
            )

            // staleDate设置为课程开始时间，系统会在此时将活动标记为过时
            let content = ActivityContent(state: contentState, staleDate: next.startDate)
            
            if let existing = Activity<NextCourseActivityAttributes>.activities.first {
                // 更新现有活动
                await existing.update(content)
            } else {
                // 创建新活动
                let attributes = NextCourseActivityAttributes(identifier: "next_course")
                _ = try? Activity.request(attributes: attributes, content: content, pushType: nil)
            }
            
            // 安排后台任务在课程开始时刷新并结束活动
            #if os(iOS)
            LiveActivityBackgroundTaskManager.shared.scheduleBackgroundRefresh(at: next.startDate)
            #endif
        }
    }

    func endAll() async {
        if #available(iOS 16.2, *) {
            for activity in Activity<NextCourseActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        
        // 取消后台刷新任务
        #if os(iOS)
        LiveActivityBackgroundTaskManager.shared.cancelAllBackgroundTasks()
        #endif
    }

    // MARK: - Private

    private struct CourseSession {
        let course: Course
        let startDate: Date
        let endDate: Date
    }

    private func findNextCourseSession(courses: [Course], settings: AppSettings, from now: Date) -> CourseSession? {
        let calendar = Calendar.current
        let helpers = ScheduleHelpers()
        let startOfToday = calendar.startOfDay(for: now)
        var candidates: [CourseSession] = []

        for dayOffset in 0...14 {
            guard let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) else { continue }
            let weekNumber = helpers.currentWeekNumber(
                for: dayDate,
                schedules: [],
                semesterStartDate: settings.semesterStartDate,
                weekStartDay: settings.weekStartDay
            )
            guard weekNumber >= 1 else { continue }

            let dayOfWeek = mondayFirstWeekday(for: dayDate, calendar: calendar)
            let dayCourses = courses.filter { $0.dayOfWeek == dayOfWeek && $0.weeks.contains(weekNumber) }

            for course in dayCourses {
                guard let startConfig = ClassTimeManager.shared.getClassTime(for: course.timeSlot) else { continue }
                let endSlot = course.timeSlot + max(1, course.duration) - 1
                guard let endConfig = ClassTimeManager.shared.getClassTime(for: endSlot) else { continue }

                guard let startDate = calendar.date(
                    bySettingHour: startConfig.startHourInt,
                    minute: startConfig.startMinute,
                    second: 0,
                    of: dayDate
                ) else { continue }

                guard let endDate = calendar.date(
                    bySettingHour: endConfig.endHourInt,
                    minute: endConfig.endMinute,
                    second: 0,
                    of: dayDate
                ) else { continue }

                if startDate > now {
                    candidates.append(CourseSession(course: course, startDate: startDate, endDate: endDate))
                }
            }
        }

        return candidates.min(by: { $0.startDate < $1.startDate })
    }

    private func mondayFirstWeekday(for date: Date, calendar: Calendar) -> Int {
        let weekday = calendar.component(.weekday, from: date) // 1 = Sunday ... 7 = Saturday
        return weekday == 1 ? 7 : weekday - 1 // 1 = Monday ... 7 = Sunday
    }
}
#endif
