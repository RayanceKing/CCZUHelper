//
//  CourseTimeCalculatorTests.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/04.
//

import Foundation
//import CCZUKit
import CCZUNISwiftBridge


/// 测试课程时间计算器
class CourseTimeCalculatorTests {
    
    /// 测试用的模拟数据
    static let mockParsedCourses: [ParsedCourse] = [
        ParsedCourse(
            name: "高等数学",
            teacher: "张三",
            location: "教学楼A101",
            weeks: [1, 3, 5, 7, 9, 11, 13, 15],
            dayOfWeek: 1,
            timeSlot: 3
        ),
        ParsedCourse(
            name: "大学英语",
            teacher: "李四",
            location: "图书馆C202",
            weeks: [2, 4, 6, 8, 10, 12, 14, 16],
            dayOfWeek: 3,
            timeSlot: 6
        ),
        ParsedCourse(
            name: "程序设计基础",
            teacher: "王五",
            location: "计算机楼B305",
            weeks: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
            dayOfWeek: 2,
            timeSlot: 8
        ),
        ParsedCourse(
            name: "线性代数",
            teacher: "刘六",
            location: "教学楼A205",
            weeks: [1, 3, 5, 7, 9, 11, 13, 15],
            dayOfWeek: 4,
            timeSlot: 1
        ),
        ParsedCourse(
            name: "物理实验",
            teacher: "陈七",
            location: "实验楼D101",
            weeks: [2, 4, 6, 8, 10, 12, 14, 16],
            dayOfWeek: 5,
            timeSlot: 10
        ),
    ]
    
    /// 打印课程时间表
    static func printClassTimeTable() {
        print("\n" + String(repeating: "=", count: 80))
        print("📚 课程时间表")
        print(String(repeating: "=", count: 80))
        
        for slot in 1...12 {
            if let classTime = ClassTimeManager.shared.getClassTime(for: slot) {
                print("第 \(slot) 节课：\(classTime.startTime) - \(classTime.endTime) (时长: \(String(format: "%.2f", classTime.duration))小时)")
            }
        }
        
        print(String(repeating: "=", count: 80) + "\n")
    }
    
    /// 测试课程转换
    static func testCourseConversion() {
        print("\n" + String(repeating: "=", count: 80))
        print("🔄 测试课程转换")
        print(String(repeating: "=", count: 80) + "\n")
        
        let calculator = CourseTimeCalculator()
        let scheduleId = UUID().uuidString
        
        // 生成课程
        let courses = calculator.generateCourses(from: mockParsedCourses, scheduleId: scheduleId)
        
        print("✅ 成功转换 \(courses.count) 门课程\n")
        
        // 打印每门课程的详细信息
        for (index, course) in courses.enumerated() {
            printCourseDetails(course, index: index + 1, calculator: calculator)
        }
        
        print(String(repeating: "=", count: 80) + "\n")
    }
    
    /// 打印单门课程的详细信息
    private static func printCourseDetails(_ course: Course, index: Int, calculator: CourseTimeCalculator) {
        print("课程 #\(index)")
        print("─" + String(repeating: "─", count: 78))
        print("📖 课程名称: \(course.name)")
        print("👨‍🏫 授课教师: \(course.teacher)")
        print("📍 上课地点: \(course.location)")
        print("📅 上课周次: \(course.weeks.min() ?? 0)-\(course.weeks.max() ?? 0) (共 \(course.weeks.count) 周)")
        print("📆 星期: \(formatDayOfWeek(course.dayOfWeek))")
        print("⏰ 节次: 第 \(course.timeSlot) 节课")
        print("⏱️  时长: \(course.duration) 小时")
        print("🎨 颜色: \(course.color)")
        
        // 获取时间范围
        if let (start, end) = calculator.getTimeRange(for: course.timeSlot) {
            print("🕐 具体时间: \(start) - \(end)")
        }
        
        // 获取位置信息
        if let (top, height) = calculator.getPositionInTimeline(slot: course.timeSlot, totalHours: 16) {
            print("📊 UI 位置: top = \(String(format: "%.2f", top)) | height = \(String(format: "%.2f", height))")
        }
        
        print("─" + String(repeating: "─", count: 78) + "\n")
    }
    
    /// 格式化星期
    private static func formatDayOfWeek(_ day: Int) -> String {
        let days = ["", "周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        return days[safe: day] ?? "未知"
    }
    
    /// 测试时间计算
    static func testTimeCalculation() {
        print("\n" + String(repeating: "=", count: 80))
        print("⏰ 测试时间计算")
        print(String(repeating: "=", count: 80) + "\n")
        
        let calculator = CourseTimeCalculator()
        
        // 测试几个关键节次
        let testSlots = [1, 3, 6, 9, 12]
        
        for slot in testSlots {
            if let (start, end) = calculator.getTimeRange(for: slot) {
                print("第 \(String(format: "%2d", slot)) 节课: \(start) - \(end)", terminator: "")
                
                if let classTime = ClassTimeManager.shared.getClassTime(for: slot) {
                    let duration = classTime.duration
                    print(" (时长: \(String(format: "%.2f", duration)) 小时)")
                } else {
                    print("")
                }
            }
        }
        
        print("\n" + String(repeating: "=", count: 80) + "\n")
    }
    
    /// 运行所有测试
    static func runAllTests() {
        print("\n🚀 开始运行课表处理测试\n")
        
        // 测试 1: 打印课程时间表
        printClassTimeTable()
        
        // 测试 2: 打印时间计算
        testTimeCalculation()
        
        // 测试 3: 测试课程转换
        testCourseConversion()
        
        print("✨ 所有测试完成！\n")
    }
}

// MARK: - Array 扩展
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
