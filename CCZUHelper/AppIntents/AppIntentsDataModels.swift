//
//  AppIntentsDataModels.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/6.
//

import Foundation
import AppIntents

/// 课程数据传输对象（用于序列化 Course 模型）
struct CourseDTO: Codable, Identifiable {
    let id: String
    let name: String
    let teacher: String
    let location: String
    let weeks: [Int]
    let dayOfWeek: Int
    let timeSlot: Int
    let duration: Int
    let color: String
    let scheduleId: String
    
    init(from course: Course) {
        self.id = UUID().uuidString
        self.name = course.name
        self.teacher = course.teacher
        self.location = course.location
        self.weeks = course.weeks
        self.dayOfWeek = course.dayOfWeek
        self.timeSlot = course.timeSlot
        self.duration = course.duration
        self.color = course.color
        self.scheduleId = course.scheduleId
    }
    
    init(id: String = UUID().uuidString, name: String, teacher: String, location: String, weeks: [Int], dayOfWeek: Int, timeSlot: Int, duration: Int, color: String, scheduleId: String) {
        self.id = id
        self.name = name
        self.teacher = teacher
        self.location = location
        self.weeks = weeks
        self.dayOfWeek = dayOfWeek
        self.timeSlot = timeSlot
        self.duration = duration
        self.color = color
        self.scheduleId = scheduleId
    }
}

/// App Intents 数据缓存管理器
class AppIntentsDataCache {
    static let shared = AppIntentsDataCache()
    
    private init() {}
    
    /// 保存课程表数据供 App Intents 使用
    func saveCourses(_ courses: [Course], for username: String) {
        let cacheKey = "cachedCourses_\(username)"
        // 转换为 DTO 进行序列化
        let courseDTOs = courses.map { CourseDTO(from: $0) }
        if let encoded = try? JSONEncoder().encode(courseDTOs) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
        }
    }
    
    /// 保存考试安排数据供 App Intents 使用
    func saveExams(_ exams: [CCZUHelper.ExamItem], for username: String) {
        let cacheKey = "cachedExams_\(username)"
        if let encoded = try? JSONEncoder().encode(exams) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
        }
    }
    
    /// 保存成绩数据供 App Intents 使用
    func saveGrades(_ grades: [CCZUHelper.GradeItem], for username: String) {
        let cacheKey = "cachedGrades_\(username)"
        if let encoded = try? JSONEncoder().encode(grades) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
        }
    }
    
    /// 获取课程表数据
    func getCourses(for username: String) -> [CourseDTO]? {
        let cacheKey = "cachedCourses_\(username)"
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let courses = try? JSONDecoder().decode([CourseDTO].self, from: data) else {
            return nil
        }
        return courses
    }
    
    /// 获取考试安排数据
    func getExams(for username: String) -> [CCZUHelper.ExamItem]? {
        let cacheKey = "cachedExams_\(username)"
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let exams = try? JSONDecoder().decode([CCZUHelper.ExamItem].self, from: data) else {
            return nil
        }
        return exams
    }
    
    /// 获取成绩数据
    func getGrades(for username: String) -> [CCZUHelper.GradeItem]? {
        let cacheKey = "cachedGrades_\(username)"
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let grades = try? JSONDecoder().decode([CCZUHelper.GradeItem].self, from: data) else {
            return nil
        }
        return grades
    }
}
