//
//  AppIntents.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/6.
//

import AppIntents
import Foundation

private let pendingIntentRouteKey = "intent.pending.route"
private let appGroupMainIdentifier = "group.com.stuwang.edupal"

nonisolated private func intentL(_ key: String) -> String {
    Bundle.main.localizedString(forKey: key, value: key, table: nil)
}

/// 打开课表意图
struct OpenScheduleIntent: AppIntent {
    static var title: LocalizedStringResource = "intent.open_schedule.title"
    static var description = IntentDescription("intent.open_schedule.description")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        let defaults = await UserDefaults(suiteName: appGroupMainIdentifier) ?? .standard
        await defaults.set("schedule", forKey: pendingIntentRouteKey)
        return .result()
    }
}

/// 打开成绩查询意图
struct OpenGradesIntent: AppIntent {
    static var title: LocalizedStringResource = "intent.open_grades.title"
    static var description = IntentDescription("intent.open_grades.description")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        let defaults = await UserDefaults(suiteName: appGroupMainIdentifier) ?? .standard
        await defaults.set("grades", forKey: pendingIntentRouteKey)
        return .result()
    }
}

/// 获取今日课程意图
struct GetTodayScheduleIntent: AppIntent {
    static var title: LocalizedStringResource = "intent.get_today_schedule.title"
    static var description = IntentDescription("intent.get_today_schedule.description")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let intent = GetScheduleIntent()
        intent.date = Date()
        return try await intent.perform()
    }
}

/// 获取明日课程意图
struct GetTomorrowScheduleIntent: AppIntent {
    static var title: LocalizedStringResource = "intent.get_tomorrow_schedule.title"
    static var description = IntentDescription("intent.get_tomorrow_schedule.description")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let intent = GetScheduleIntent()
        intent.date = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        return try await intent.perform()
    }
}

/// 获取指定日期课程意图
struct GetScheduleForSpecificDateIntent: AppIntent {
    static var title: LocalizedStringResource = "intent.get_schedule_for_date.title"
    static var description = IntentDescription("intent.get_schedule_for_date.description")
    static var openAppWhenRun: Bool = false

    @Parameter(
        title: "intent.param.date.title",
        description: "intent.param.date.description"
    )
    var date: Date

    static var parameterSummary: some ParameterSummary {
        Summary("intent.summary.get_schedule \(\.$date)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let intent = GetScheduleIntent()
        intent.date = date
        return try await intent.perform()
    }
}

/// 检查是否有课意图
struct HasClassTodayIntent: AppIntent {
    static var title: LocalizedStringResource = "intent.has_class_today.title"
    static var description = IntentDescription("intent.has_class_today.description")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        guard let username = UserDefaults.standard.string(forKey: "username") else {
            throw IntentError.notLoggedIn
        }

        guard let courses = await AppIntentsDataCache.shared.getCourses(for: username, on: Date()) else {
            throw IntentError.noDataAvailable
        }
        return .result(value: !courses.isEmpty)
    }
}

/// 获取下一节课意图
struct GetNextClassIntent: AppIntent {
    static var title: LocalizedStringResource = "intent.get_next_class.title"
    static var description = IntentDescription("intent.get_next_class.description")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard let username = UserDefaults.standard.string(forKey: "username") else {
            throw IntentError.notLoggedIn
        }

        let now = Date()
        guard let todayCourses = await AppIntentsDataCache.shared.getCourses(for: username, on: now) else {
            throw IntentError.noDataAvailable
        }
        let nextCourse = await MainActor.run {
            ScheduleSelection.currentOrNext(
                in: todayCourses, at: now, timeSlot: { $0.timeSlot }, duration: { $0.duration },
                classTime: { ClassTimeManager.shared.getClassTime(for: $0) }
            )
        }
        if let course = nextCourse {
            let endSlot = course.timeSlot + course.duration - 1
            var result = "\(intentL("intent.next_class.prefix")):\n\n"
            result += "📚 \(course.name)\n"
            result += "   \(intentL("intent.field.time")): \(course.timeSlot)-\(endSlot)节\n"
            result += "   \(intentL("intent.field.location")): \(course.location)\n"
            result += "   \(intentL("intent.field.teacher")): \(course.teacher)\n"
            return .result(value: result, dialog: IntentDialog(stringLiteral: intentL("intent.next_class.prefix")))
        }

        let speech = intentL("intent.next_class.none_today")
        return .result(value: speech, dialog: IntentDialog(stringLiteral: speech))
    }
}

/// 课程实体
struct CourseEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "intent.entity.course"
    static var defaultQuery = CourseQuery()

    let id: String
    let name: String
    let teacher: String
    let location: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(teacher)")
    }
}

/// 课程查询
struct CourseQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [CourseEntity] {
        []
    }

    func suggestedEntities() async throws -> [CourseEntity] {
        guard let username = UserDefaults.standard.string(forKey: "username") else {
            return []
        }

        guard let courses = await AppIntentsDataCache.shared.getCourses(for: username) else {
            return []
        }

        return courses.prefix(10).map { course in
            CourseEntity(
                id: course.id,
                name: course.name,
                teacher: course.teacher,
                location: course.location
            )
        }
    }
}

/// Intent 错误类型
enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case notLoggedIn
    case noDataAvailable
    case networkError

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notLoggedIn:
            return "intent.error.not_logged_in"
        case .noDataAvailable:
            return "intent.error.no_data"
        case .networkError:
            return "intent.error.network"
        }
    }
}
