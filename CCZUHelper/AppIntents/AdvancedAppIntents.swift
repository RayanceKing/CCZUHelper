//
//  AdvancedAppIntents.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/6.
//

import AppIntents
import Foundation

/// 打开课表意图
struct OpenScheduleIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Class Schedule"
    static var description = IntentDescription("Open the class schedule in CCZUHelper")
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}

/// 打开成绩查询意图
struct OpenGradesIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Grades"
    static var description = IntentDescription("Open the grades view in CCZUHelper")
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}

/// 获取今日课程意图
struct GetTodayScheduleIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Today's Schedule"
    static var description = IntentDescription("Get your class schedule for today")
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let intent = GetScheduleIntent()
        intent.date = Date()
        return try await intent.perform()
    }
}

/// 获取明日课程意图
struct GetTomorrowScheduleIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Tomorrow's Schedule"
    static var description = IntentDescription("Get your class schedule for tomorrow")
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let intent = GetScheduleIntent()
        intent.date = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        return try await intent.perform()
    }
}

/// 检查是否有课意图
struct HasClassTodayIntent: AppIntent {
    static var title: LocalizedStringResource = "Do I Have Class Today"
    static var description = IntentDescription("Check if you have any classes today")
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        let settings = await AppSettings()
        guard let username = await settings.username else {
            throw IntentError.notLoggedIn
        }
        
        guard let courses = await AppIntentsDataCache.shared.getCourses(for: username) else {
            throw IntentError.noDataAvailable
        }
        
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        let dayOfWeek = weekday == 1 ? 7 : weekday - 1
        
        let hasClass = courses.contains { course in
            course.weeks.contains(1) && course.dayOfWeek == dayOfWeek
        }
        
        return .result(value: hasClass)
    }
}

/// 获取下一节课意图
struct GetNextClassIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Next Class"
    static var description = IntentDescription("Get information about your next class")
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let settings = await AppSettings()
        guard let username = await settings.username else {
            throw IntentError.notLoggedIn
        }
        
        guard let courses = await AppIntentsDataCache.shared.getCourses(for: username) else {
            throw IntentError.noDataAvailable
        }
        
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let dayOfWeek = weekday == 1 ? 7 : weekday - 1
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentTimeInMinutes = currentHour * 60 + currentMinute
        
        // 获取今天的课程
        let todayCourses = courses.filter { course in
            course.weeks.contains(1) && course.dayOfWeek == dayOfWeek
        }.sorted { $0.timeSlot < $1.timeSlot }
        
        // 查找下一节课（简化逻辑，假设每节课从特定时间开始）
        // 这里需要根据实际的上课时间表来判断
        for course in todayCourses {
            // 简化判断：如果当前时间早于课程开始节次对应的时间
            let courseStartTime = getCourseStartTime(section: course.timeSlot)
            if currentTimeInMinutes < courseStartTime {
                let endSlot = course.timeSlot + course.duration - 1
                var result = "Your next class:\n\n"
                result += "📚 \(course.name)\n"
                result += "   Time: \(course.timeSlot)-\(endSlot)节\n"
                result += "   Location: \(course.location)\n"
                result += "   Teacher: \(course.teacher)\n"
                return .result(value: result)
            }
        }
        
        return .result(value: "No more classes today.")
    }
    
    private func getCourseStartTime(section: Int) -> Int {
        // 简化的上课时间映射（单位：分钟）
        let timeTable: [Int: Int] = [
            1: 8 * 60,      // 8:00
            2: 8 * 60 + 50, // 8:50
            3: 10 * 60,     // 10:00
            4: 10 * 60 + 50,// 10:50
            5: 14 * 60,     // 14:00
            6: 14 * 60 + 50,// 14:50
            7: 16 * 60,     // 16:00
            8: 16 * 60 + 50,// 16:50
        ]
        return timeTable[section] ?? 8 * 60
    }
}

/// 课程实体
struct CourseEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Course"
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
        // 实现根据ID查询课程
        return []
    }
    
    func suggestedEntities() async throws -> [CourseEntity] {
        let settings = await AppSettings()
        guard let username = await settings.username else {
            return []
        }
        
        guard let courses = await AppIntentsDataCache.shared.getCourses(for: username) else {
            return []
        }
        
        // 返回所有课程作为建议
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
