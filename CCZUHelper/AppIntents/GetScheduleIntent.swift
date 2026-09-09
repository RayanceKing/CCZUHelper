//
//  GetScheduleIntent.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/6.
//

import AppIntents
import SwiftUI

nonisolated private func intentL(_ key: String) -> String {
    Bundle.main.localizedString(forKey: key, value: key, table: nil)
}

nonisolated private func intentLF(_ key: String, _ args: CVarArg...) -> String {
    String(format: intentL(key), arguments: args)
}

nonisolated private func intentDialog(_ text: String) -> IntentDialog {
    IntentDialog(stringLiteral: text)
}

nonisolated private func uniqueCourseNames(from courses: [CourseDTO]) -> [String] {
    var seen = Set<String>()
    var names: [String] = []
    for course in courses {
        if seen.insert(course.name).inserted {
            names.append(course.name)
        }
    }
    return names
}

/// 获取课程表意图
struct GetScheduleIntent: AppIntent {
    static var title: LocalizedStringResource = "intent.get_schedule.title"
    static var description = IntentDescription("intent.get_schedule.description")
    static var openAppWhenRun: Bool = false

    @Parameter(
        title: "intent.param.date.title",
        description: "intent.param.date.description"
    )
    var date: Date?

    static var parameterSummary: some ParameterSummary {
        Summary("intent.summary.get_schedule \(\.$date)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let targetDate = date ?? Date()
        guard let username = UserDefaults.standard.string(forKey: "username") else {
            throw IntentError.notLoggedIn
        }

        guard let todayCourses = await AppIntentsDataCache.shared.getCourses(for: username, on: targetDate) else {
            throw IntentError.noDataAvailable
        }

        let dateText = await AppDateFormatting.mediumDateString(from: targetDate)

        if todayCourses.isEmpty {
            let speech = intentLF("intent.result.no_classes_for_date", dateText)
            return .result(value: speech, dialog: intentDialog(speech))
        }

        let sortedCourses = todayCourses.sorted { $0.timeSlot < $1.timeSlot }

        var result = "\(intentLF("intent.result.classes_for_date", dateText)):\n\n"
        for course in sortedCourses {
            let endSlot = course.timeSlot + course.duration - 1
            let timeRange = "\(course.timeSlot)-\(endSlot)节"
            result += "📚 \(course.name)\n"
            result += "   \(intentL("intent.field.time")): \(timeRange)\n"
            result += "   \(intentL("intent.field.location")): \(course.location)\n"
            result += "   \(intentL("intent.field.teacher")): \(course.teacher)\n\n"
        }

        let courseNames = uniqueCourseNames(from: sortedCourses)
        let namesText = courseNames.prefix(5).joined(separator: "、")
        let speech = namesText.isEmpty
            ? intentLF("intent.schedule.courses_today", sortedCourses.count)
            : intentLF("intent.speech.schedule_courses", dateText, namesText)
        return .result(value: result, dialog: intentDialog(speech))
    }
}

/// 获取考试安排意图
struct GetExamScheduleIntent: AppIntent {
    static var title: LocalizedStringResource = "intent.get_exam_schedule.title"
    static var description = IntentDescription("intent.get_exam_schedule.description")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard let username = UserDefaults.standard.string(forKey: "username") else {
            throw IntentError.notLoggedIn
        }

        guard let exams = await AppIntentsDataCache.shared.getExams(for: username) else {
            throw IntentError.noDataAvailable
        }

        if exams.isEmpty {
            let speech = intentL("intent.result.no_exams")
            return .result(value: speech, dialog: intentDialog(speech))
        }

        var result = "\(intentL("intent.result.exam_schedule_header")):\n\n"
        for exam in exams {
            result += "📝 \(exam.courseName)\n"
            if let examTime = exam.examTime {
                result += "   \(intentL("intent.field.time")): \(examTime)\n"
            }
            if let examLocation = exam.examLocation {
                result += "   \(intentL("intent.field.location")): \(examLocation)\n"
            }
            result += "\n"
        }

        let speech = intentLF("intent.exam.exams_found", exams.count)
        return .result(value: result, dialog: intentDialog(speech))
    }
}

/// 获取成绩意图
struct GetGradesIntent: AppIntent {
    static var title: LocalizedStringResource = "intent.get_grades.title"
    static var description = IntentDescription("intent.get_grades.description")
    static var openAppWhenRun: Bool = false

    @Parameter(
        title: "intent.param.term.title",
        description: "intent.param.term.description"
    )
    var term: String?

    static var parameterSummary: some ParameterSummary {
        Summary("intent.summary.get_grades \(\.$term)")
    }

    private func speechPreviewItems(from grades: [CCZUHelper.GradeItem]) -> String {
        grades.map { intentLF("intent.grades.speech.item", $0.courseName, $0.score) }
            .joined(separator: intentL("intent.grades.speech.separator"))
    }

    private func buildResultText(
        for grades: [CCZUHelper.GradeItem],
        term: String?,
        allTermText: String
    ) -> String {
        var result = intentL("intent.result.grades_header")
        if let term, !term.isEmpty, term != allTermText {
            result += " " + intentLF("intent.result.for_term", term)
        }
        result += ":\n\n"

        for grade in grades {
            result += "📖 \(grade.courseName)\n"
            result += "   \(intentL("intent.field.score")): \(grade.score)\n"
            result += "   \(intentL("intent.field.credit")): \(grade.credit)\n"
            result += "   \(intentL("intent.field.gpa")): \(String(format: "%.2f", grade.gradePoint))\n\n"
        }
        return result
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let settings = await AppSettings()
        guard let username = await settings.username else {
            throw IntentError.notLoggedIn
        }

        guard let grades = await AppIntentsDataCache.shared.getGrades(for: username) else {
            throw IntentError.noDataAvailable
        }

        let allTermText = intentL("intent.term.all")
        let filteredGrades: [CCZUHelper.GradeItem]
        if let term, !term.isEmpty, term != allTermText {
            filteredGrades = grades.filter { $0.term == term }
        } else {
            filteredGrades = grades
        }

        if filteredGrades.isEmpty {
            let speech = intentL("intent.result.no_grades")
            return .result(value: speech, dialog: intentDialog(speech))
        }

        let previewCount = 3
        let previewGrades = Array(filteredGrades.prefix(previewCount))
        let previewSpeech = speechPreviewItems(from: previewGrades)

        if filteredGrades.count > previewCount {
            let remainingCount = filteredGrades.count - previewCount
            let continuePrompt = intentLF(
                "intent.grades.speech.preview_and_continue",
                filteredGrades.count,
                previewSpeech,
                remainingCount
            )

            do {
                if #available(iOS 18.0, *) {
                    try await requestConfirmation(
                        conditions: [],
                        actionName: .continue,
                        dialog: intentDialog(continuePrompt)
                    )
                } else {
                    try await requestConfirmation()
                }
            } catch {
                let previewResult = buildResultText(
                    for: previewGrades,
                    term: term,
                    allTermText: allTermText
                )
                let stopSpeech = intentLF("intent.grades.speech.stopped_after_preview", previewGrades.count)
                return .result(value: previewResult, dialog: intentDialog(stopSpeech))
            }
        }

        let result = buildResultText(
            for: filteredGrades,
            term: term,
            allTermText: allTermText
        )
        let fullSpeech = intentLF("intent.grades.speech.full_list", filteredGrades.count, previewSpeech)
        return .result(value: result, dialog: intentDialog(fullSpeech))
    }
}

/// 获取学分绩点意图
struct GetGPAIntent: AppIntent {
    static var title: LocalizedStringResource = "intent.get_gpa.title"
    static var description = IntentDescription("intent.get_gpa.description")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let settings = await AppSettings()
        guard let username = await settings.username else {
            throw IntentError.notLoggedIn
        }

        guard let grades = await AppIntentsDataCache.shared.getGrades(for: username) else {
            throw IntentError.noDataAvailable
        }

        if grades.isEmpty {
            let speech = intentL("intent.result.no_gpa_data")
            return .result(value: speech, dialog: intentDialog(speech))
        }

        var totalCredits: Double = 0
        var totalGradePoints: Double = 0
        var passedCount = 0

        for grade in grades {
            let credit = grade.credit
            let gradePoint = grade.gradePoint

            totalCredits += credit
            totalGradePoints += credit * gradePoint

            if grade.score != "不及格" && !grade.score.contains("不及格") {
                passedCount += 1
            }
        }

        let gpa = totalCredits > 0 ? totalGradePoints / totalCredits : 0

        var result = "\(intentL("intent.result.gpa_summary_header"))\n\n"
        result += intentLF("intent.result.gpa_overall", String(format: "%.2f", gpa)) + "\n"
        result += intentLF("intent.result.gpa_total_credits", String(format: "%.1f", totalCredits)) + "\n"
        result += intentLF("intent.result.gpa_passed_count", passedCount, grades.count) + "\n"
        result += intentLF("intent.result.gpa_course_count", grades.count) + "\n"

        let speech = intentLF("intent.gpa.your_gpa", gpa)
        return .result(value: result, dialog: intentDialog(speech))
    }
}
