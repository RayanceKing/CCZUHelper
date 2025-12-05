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
    
    init(timeHelper: CalendarTimeHelper? = nil) {
        self.timeHelper = timeHelper ?? CalendarTimeHelper()
    }
    
    /// 生成课程 - 处理相同课程的合并和时长计算
    /// - Parameters:
    ///   - parsedCourses: CCZUKit解析出的课程列表
    ///   - scheduleId: 课表ID
    /// - Returns: 带有精确时间的课程模型列表
    func generateCourses(from parsedCourses: [ParsedCourse], scheduleId: String) -> [Course] {
        var courses: [Course] = []
        
        // 首先，按课程名称、教师、位置、星期分组以找到重复课程
        var grouped: [String: [ParsedCourse]] = [:]
        for parsedCourse in parsedCourses {
            let key = "\(parsedCourse.name)_\(parsedCourse.teacher)_\(parsedCourse.location)_\(parsedCourse.dayOfWeek)"
            if grouped[key] == nil {
                grouped[key] = []
            }
            grouped[key]?.append(parsedCourse)
        }
        
        // 处理每组课程（合并相同的课程）
        for (_, groupedCourses) in grouped {
            // 按节次排序
            let sorted = groupedCourses.sorted { $0.timeSlot < $1.timeSlot }
            
            // 找出所有连续的节次块
            var i = 0
            while i < sorted.count {
                let startCourse = sorted[i]
                let startSlot = startCourse.timeSlot
                var endSlot = startSlot
                var duration = 1
                
                // 查找连续的节次
                while i + duration < sorted.count {
                    let nextCourse = sorted[i + duration]
                    if nextCourse.timeSlot == endSlot + 1 {
                        endSlot = nextCourse.timeSlot
                        duration += 1
                    } else {
                        break
                    }
                }
                
                // 计算节次数（用于存储在duration字段）
                let slotCount = endSlot - startSlot + 1
                
                // 基于课程名称生成确定性的高对比度颜色
                let color = generateDeterministicColor(for: startCourse.name)
                
                let course = Course(
                    name: startCourse.name,
                    teacher: startCourse.teacher,
                    location: startCourse.location,
                    weeks: startCourse.weeks,
                    dayOfWeek: startCourse.dayOfWeek,
                    timeSlot: startSlot,
                    duration: slotCount,  // 存储节次数
                    color: color,
                    scheduleId: scheduleId
                )
                
                courses.append(course)
                i += duration
            }
        }
        
        return courses
    }
    
    /// 基于课程名称生成确定性的高对比度颜色
    /// - Parameter courseName: 课程名称
    /// - Returns: 十六进制颜色字符串
    private func generateDeterministicColor(for courseName: String) -> String {
        // 使用自定义的确定性哈希函数确保相同课程名始终得到相同颜色
        let hashValue = determinisitcHash(for: courseName)
        
        // 高对比度颜色池 - 精心选择的颜色，具有高饱和度和亮度
        // 这些颜色在浅色和深色模式下都有很好的可读性
        let highContrastColors = [
            "#FF6B6B",  // 鲜红
            "#4ECDC4",  // 青绿
            "#45B7D1",  // 天蓝
            "#96CEB4",  // 薄荷绿
            "#FFD93D",  // 金黄（优化后的亮度）
            "#FF9E9E",  // 浅红
            "#A8D8EA",  // 浅蓝
            "#FF90EE",  // 热粉
            "#98FB98",  // 浅绿
            "#FFA500",  // 橙色
            "#87CEEB",  // 天空蓝
            "#F08080",  // 浅珊瑚红
            "#20B2AA",  // 深青色
            "#FFB6C1",  // 浅粉
            "#3CB371",  // 中海绿
            "#DDA0DD",  // 梅紫
            "#F7DC6F",  // 明黄
            "#BB8FCE",  // 紫罗兰
            "#85C1E9",  // 淡蓝
            "#F8B88B",  // 沙色
        ]
        
        // 使用hash值选择颜色
        let colorIndex = hashValue % highContrastColors.count
        return highContrastColors[colorIndex]
    }
    
    /// 确定性哈希函数 - 基于DJB2算法
    /// 确保相同输入在不同运行中产生相同的哈希值
    private func determinisitcHash(for string: String) -> Int {
        var hash: UInt = 5381
        
        for byte in string.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt(byte)
        }
        
        return Int(hash & 0x7FFFFFFF)  // 确保返回正数
    }
    
    /// 计算实际课程时长（从开始节次到结束节次）
    /// - Parameters:
    ///   - startSlot: 开始节次
    /// - Returns: 课程时长（小时）
    private func calculateActualDuration(startSlot: Int, endSlot: Int) -> Int {
        guard let startTime = timeHelper.getStartHour(for: startSlot),
              let endTime = timeHelper.getEndHour(for: endSlot) else {
            // 如果无法获取时间，根据节次数估算
            return max(1, endSlot - startSlot + 1)
        }
        
        // 计算实际时间差（小时），向上取整
        let durationHours = endTime - startTime
        return max(1, Int(ceil(durationHours)))
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
