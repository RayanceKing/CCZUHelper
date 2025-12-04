//
//  CourseTimeCalculator.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/04.
//

import Foundation
import CCZUKit

/// 课程时间计算器 - 将ParsedCourse转换为包含精确时间的Course对象
class CourseTimeCalculator {
    private let timeHelper: CalendarTimeHelper
    private let courseColorHexes: [String]
    private var colorIndex = 0
    
    init(timeHelper: CalendarTimeHelper? = nil) {
        self.timeHelper = timeHelper ?? CalendarTimeHelper()
        self.courseColorHexes = [
            "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7",
            "#DDA0DD", "#98D8C8", "#F7DC6F", "#BB8FCE", "#85C1E9",
        ]
    }
    
    /// 从ParsedCourse生成带有精确时间信息的课程数据
    /// - Parameters:
    ///   - parsedCourses: CCZUKit解析出的课程列表
    ///   - scheduleId: 课表ID
    /// - Returns: 带有精确时间的课程模型列表
    func generateCourses(from parsedCourses: [ParsedCourse], scheduleId: String) -> [Course] {
        var courses: [Course] = []
        var courseColorMap: [String: String] = [:]
        
        for parsedCourse in parsedCourses {
            // 根据课程名称分配颜色
            let colorKey = parsedCourse.name
            if courseColorMap[colorKey] == nil {
                courseColorMap[colorKey] = courseColorHexes[colorIndex % courseColorHexes.count]
                colorIndex += 1
            }
            
            // 计算课程时长
            let duration = calculateDuration(
                startSlot: parsedCourse.timeSlot,
                weeks: parsedCourse.weeks
            )
            
            let course = Course(
                name: parsedCourse.name,
                teacher: parsedCourse.teacher,
                location: parsedCourse.location,
                weeks: parsedCourse.weeks,
                dayOfWeek: parsedCourse.dayOfWeek,
                timeSlot: parsedCourse.timeSlot,
                duration: duration,
                color: courseColorMap[colorKey] ?? "#007AFF",
                scheduleId: scheduleId
            )
            
            courses.append(course)
        }
        
        return courses
    }
    
    /// 计算课程时长（通过检查相邻时段）
    /// - Parameters:
    ///   - startSlot: 起始节次
    ///   - weeks: 课程周次列表
    /// - Returns: 课程时长（小时）
    private func calculateDuration(startSlot: Int, weeks: [Int]) -> Int {
        // 对于大多数情况，一节课是45分钟，两节课是90分钟
        // 如果起始节次是1-5，通常持续2节课（90分钟）
        // 如果起始节次是6-9，也通常持续2节课
        // 如果起始节次是10-12，通常持续2节课
        
        // 根据节次判断标准时长
        switch startSlot {
        case 1...5, 6...9, 10...12:
            // 假设大多数课程是2个小时（从时间表看，相邻节次之间）
            // 节次1-5: 08:00-12:00，共4小时，5节课
            // 节次6-9: 13:30-16:40，共3小时10分钟，4节课
            // 节次10-12: 18:30-20:45，共2小时15分钟，3节课
            
            // 计算连续两节课的时长
            if let endTime = timeHelper.getEndHour(for: startSlot + 1),
               let startTime = timeHelper.getStartHour(for: startSlot) {
                let hours = Int(ceil(endTime - startTime))
                return max(1, hours)  // 至少1小时
            }
            return 2  // 默认2小时
        default:
            return 2
        }
    }
    
    /// 获取课程在时间轴上的位置
    /// - Parameters:
    ///   - slot: 节次号
    ///   - totalHours: 一天总课时数
    /// - Returns: (顶部偏移百分比, 高度百分比)
    func getPositionInTimeline(slot: Int, totalHours: Int = 12) -> (top: Double, height: Double)? {
        guard let (topPercent, heightPercent) = timeHelper.getPositionInfo(
            for: slot,
            totalHours: totalHours
        ) else {
            return nil
        }
        
        return (top: topPercent, height: heightPercent)
    }
    
    /// 获取课程的开始和结束时间字符串
    /// - Parameter slot: 节次号
    /// - Returns: (开始时间字符串, 结束时间字符串) 格式: "HH:mm"
    func getTimeRange(for slot: Int) -> (start: String, end: String)? {
        guard let classTime = timeHelper.getClassTime(for: slot) else {
            return nil
        }
        
        let startStr = formatTime(classTime.startTime)
        let endStr = formatTime(classTime.endTime)
        
        return (start: startStr, end: endStr)
    }
    
    /// 将时间字符串从"HHmm"格式转换为"HH:mm"格式
    private func formatTime(_ time: String) -> String {
        guard time.count == 4 else { return time }
        let hour = String(time.prefix(2))
        let minute = String(time.suffix(2))
        return "\(hour):\(minute)"
    }
}

// MARK: - 使用示例注释
/*
 使用方式：
 
 1. 基础用法（使用默认课程时间表）：
 ```swift
 let calculator = CourseTimeCalculator()
 let courses = calculator.generateCourses(from: parsedCourses, scheduleId: scheduleId)
 ```
 
 2. 使用自定义calendar.json：
 ```swift
 if let calendarURL = Bundle.main.url(forResource: "calendar", withExtension: "json"),
    let timeHelper = CalendarTimeHelper(jsonURL: calendarURL) {
     let calculator = CourseTimeCalculator(timeHelper: timeHelper)
     let courses = calculator.generateCourses(from: parsedCourses, scheduleId: scheduleId)
 }
 ```
 
 3. 获取课程时间范围：
 ```swift
 let calculator = CourseTimeCalculator()
 if let (start, end) = calculator.getTimeRange(for: 3) {
     print("第3节课：\(start) - \(end)")  // 输出：第3节课：09:45 - 10:25
 }
 ```
 
 4. 获取课程在时间轴上的位置（用于UI布局）：
 ```swift
 if let (top, height) = calculator.getPositionInTimeline(slot: 3, totalHours: 16) {
     let topOffset = top * totalHeight
     let courseHeight = height * totalHeight
 }
 ```
 */
