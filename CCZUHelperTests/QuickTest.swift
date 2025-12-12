//
//  QuickTest.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/04.
//  用途: 快速测试课程解析和时间转换
//
//  使用方法:
//  1. 在任何地方添加: QuickTest.start()
//  2. 在 AppDelegate 或 App 初始化时调用
//  3. 观看 Xcode 控制台的输出

import Foundation
import CCZUKit

/// 快速测试工具
struct QuickTest {
    /// 启动快速测试（输出到 Xcode 控制台）
    static func start() {
        print("\n\n" + "🎯 快速测试已启动".center(length: 80))
        printSeparator()
        
        testStep1_ClassTimeTable()
        testStep2_MockCourses()
        testStep3_TimeConversion()
        testStep4_FullReport()
        
        printSeparator()
        print("✅ 所有测试完成！\n\n")
    }
    
    // MARK: - Test Step 1: 课程时间表
    private static func testStep1_ClassTimeTable() {
        print("\n📚 步骤 1: 课程时间表\n")
        
        print("| 节次 | 开始时间 | 结束时间 | 时长(小时) |")
        print("|------|--------|--------|----------|")
        
        for slot in 1...12 {
            if let classTime = ClassTimeManager.shared.getClassTime(for: slot) {
                let duration = String(format: "%.2f", classTime.duration)
                let slotStr = String(format: "%2d", slot)
                print("| \(slotStr)   | \(classTime.startTime) | \(classTime.endTime) | \(duration)     |")
            }
        }
        
        print()
    }
    
    // MARK: - Test Step 2: 模拟课表
    private static func testStep2_MockCourses() {
        print("\n📋 步骤 2: 模拟课程数据\n")
        
        let mockCourses = CourseTimeCalculatorTests.mockParsedCourses
        
        print("共有 \(mockCourses.count) 门课程：\n")
        
        for (index, course) in mockCourses.enumerated() {
            let dayName = getDayName(course.dayOfWeek)
            print("\(index + 1). [\(dayName)] \(course.name)")
            print("   - 授课教师: \(course.teacher)")
            print("   - 上课地点: \(course.location)")
            print("   - 节次: 第 \(course.timeSlot) 节")
            print("   - 周次: \(course.weeks.count) 周")
            print()
        }
    }
    
    // MARK: - Test Step 3: 时间转换
    private static func testStep3_TimeConversion() {
        print("\n⏰ 步骤 3: 时间转换测试\n")
        
        let calculator = CourseTimeCalculator()
        
        let testSlots = [1, 3, 6, 9, 12]
        
        for slot in testSlots {
            if let (start, end) = calculator.getTimeRange(for: slot) {
                print("第 \(slot)  节课: \(start) - \(end)")
            }
        }
        
        print()
    }
    
    // MARK: - Test Step 4: 完整报告
    private static func testStep4_FullReport() {
        print("\n📊 步骤 4: 完整课程转换报告\n")
        
        let calculator = CourseTimeCalculator()
        let scheduleId = UUID().uuidString
        let mockCourses = CourseTimeCalculatorTests.mockParsedCourses
        
        let generatedCourses = calculator.generateCourses(from: mockCourses, scheduleId: scheduleId)
        
        print("✅ 成功转换 \(generatedCourses.count) 门课程\n")
        
        for (index, course) in generatedCourses.enumerated() {
            print("[\(index + 1)] \(course.name)")
            if let (start, end) = calculator.getTimeRange(for: course.timeSlot) {
                print("    时间: \(start) - \(end)")
                print("    时长: \(course.duration) 小时")
                print("    颜色: \(course.color)")
                print()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private static func getDayName(_ day: Int) -> String {
        let days = ["", "周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        return days[safe: day] ?? "未知"
    }
    
    private static func printSeparator() {
        print(String(repeating: "─", count: 80))
    }
}

// MARK: - String Extension
extension String {
    func center(length: Int) -> String {
        let padding = max(0, length - self.count) / 2
        return String(repeating: " ", count: padding) + self
    }
}

// MARK: - Array Extension
//extension Array {
//    subscript(safe index: Int) -> Element? {
//        return indices.contains(index) ? self[index] : nil
//    }
//}
