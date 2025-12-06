//
//  GetScheduleIntent.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/6.
//

import AppIntents
import SwiftUI

/// 获取课程表意图
struct GetScheduleIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Class Schedule"
    static var description = IntentDescription("Get your class schedule for today or a specific date")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Date", description: "The date to get schedule for (optional, defaults to today)")
    var date: Date?
    
    static var parameterSummary: some ParameterSummary {
        Summary("Get class schedule for \(\.$date)")
    }
    
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let targetDate = date ?? Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: targetDate)
        
        // 转换为课程表使用的星期格式(1=周一, 7=周日)
        let dayOfWeek = weekday == 1 ? 7 : weekday - 1
        
        // 直接从 UserDefaults 读取用户名
        guard let username = UserDefaults.standard.string(forKey: "username") else {
            throw IntentError.notLoggedIn
        }
        
        guard let courses = await AppIntentsDataCache.shared.getCourses(for: username) else {
            throw IntentError.noDataAvailable
        }
        
        // 筛选指定日期的课程
        let todayCourses = courses.filter { course in
            course.weeks.contains(1) && course.dayOfWeek == dayOfWeek
        }
        
        if todayCourses.isEmpty {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return .result(value: "No classes scheduled for \(formatter.string(from: targetDate)).")
        }
        
        // 按节次排序
        let sortedCourses = todayCourses.sorted { $0.timeSlot < $1.timeSlot }
        
        // 构建课程列表文本
        var result = "Classes for \(formatDate(targetDate)):\n\n"
        for course in sortedCourses {
            let endSlot = course.timeSlot + course.duration - 1
            let timeRange = "\(course.timeSlot)-\(endSlot)节"
            result += "📚 \(course.name)\n"
            result += "   Time: \(timeRange)\n"
            result += "   Location: \(course.location)\n"
            result += "   Teacher: \(course.teacher)\n\n"
        }
        
        return .result(value: result)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

/// 获取考试安排意图
struct GetExamScheduleIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Exam Schedule"
    static var description = IntentDescription("Get your exam schedule")
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let username = UserDefaults.standard.string(forKey: "username") else {
            throw IntentError.notLoggedIn
        }
        
        guard let exams = await AppIntentsDataCache.shared.getExams(for: username) else {
            throw IntentError.noDataAvailable
        }
        
        if exams.isEmpty {
            return .result(value: "No exams scheduled.")
        }
        
        var result = "Exam Schedule:\n\n"
        for exam in exams {
            result += "📝 \(exam.courseName)\n"
            if let examTime = exam.examTime {
                result += "   Time: \(examTime)\n"
            }
            if let examLocation = exam.examLocation {
                result += "   Location: \(examLocation)\n"
            }
            result += "\n"
        }
        
        return .result(value: result)
    }
}

/// 获取成绩意图
struct GetGradesIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Grades"
    static var description = IntentDescription("Get your course grades")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Term", description: "Specific term (optional)", default: "All Terms")
    var term: String?
    
    static var parameterSummary: some ParameterSummary {
        Summary("Get grades for \(\.$term)")
    }
    
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let settings = await AppSettings()
        guard let username = await settings.username else {
            throw IntentError.notLoggedIn
        }
        
        guard let grades = await AppIntentsDataCache.shared.getGrades(for: username) else {
            throw IntentError.noDataAvailable
        }
        
        // 如果指定学期，筛选该学期的成绩
        let filteredGrades: [CCZUHelper.GradeItem]
        if let term = term, term != "All Terms" {
            filteredGrades = grades.filter { $0.term == term }
        } else {
            filteredGrades = grades
        }
        
        if filteredGrades.isEmpty {
            return .result(value: "No grades available.")
        }
        
        var result = "Grades"
        if let term = term, term != "All Terms" {
            result += " for \(term)"
        }
        result += ":\n\n"
        
        for grade in filteredGrades {
            result += "📖 \(grade.courseName)\n"
            result += "   Score: \(grade.score)\n"
            result += "   Credit: \(grade.credit)\n"
            result += "   GPA: \(String(format: "%.2f", grade.gradePoint))\n\n"
        }
        
        return .result(value: result)
    }
}

/// 获取学分绩点意图
struct GetGPAIntent: AppIntent {
    static var title: LocalizedStringResource = "Get GPA"
    static var description = IntentDescription("Get your GPA and credit information")
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let settings = await AppSettings()
        guard let username = await settings.username else {
            throw IntentError.notLoggedIn
        }
        
        guard let grades = await AppIntentsDataCache.shared.getGrades(for: username) else {
            throw IntentError.noDataAvailable
        }
        
        if grades.isEmpty {
            return .result(value: "No grade data available to calculate GPA.")
        }
        
        // 计算总学分和加权绩点
        var totalCredits: Double = 0
        var totalGradePoints: Double = 0
        var passedCount = 0
        
        for grade in grades {
            let credit = grade.credit
            let gradePoint = grade.gradePoint
            
            totalCredits += credit
            totalGradePoints += credit * gradePoint
            
            // 判断是否通过（成绩不为不及格）
            if grade.score != "不及格" && !grade.score.contains("不及格") {
                passedCount += 1
            }
        }
        
        let gpa = totalCredits > 0 ? totalGradePoints / totalCredits : 0
        
        var result = "📊 GPA Summary\n\n"
        result += "Overall GPA: \(String(format: "%.2f", gpa))\n"
        result += "Total Credits: \(String(format: "%.1f", totalCredits))\n"
        result += "Passed Courses: \(passedCount)/\(grades.count)\n"
        result += "Course Count: \(grades.count)\n"
        
        return .result(value: result)
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
            return "Please login to the app first"
        case .noDataAvailable:
            return "No data available. Please open the app to sync data"
        case .networkError:
            return "Network error. Please try again later"
        }
    }
}
