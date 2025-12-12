//
//  ClassTimeConfig.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/12.
//

import Foundation

/// 课程时间配置 - 统一的课程时间管理
/// 从 CCZUKit 的 calendar.json 解析并提供给整个应用使用
public struct ClassTimeConfig: Codable {
    public let slotNumber: Int
    public let name: String
    public let startTime: String  // 格式: HHmm
    public let endTime: String    // 格式: HHmm
    
    /// 开始时间（分钟）
    public var startTimeInMinutes: Int {
        guard startTime.count == 4 else { return 0 }
        let hourStr = String(startTime.prefix(2))
        let minStr = String(startTime.suffix(2))
        guard let hour = Int(hourStr), let min = Int(minStr) else { return 0 }
        return hour * 60 + min
    }
    
    /// 结束时间（分钟）
    public var endTimeInMinutes: Int {
        guard endTime.count == 4 else { return 0 }
        let hourStr = String(endTime.prefix(2))
        let minStr = String(endTime.suffix(2))
        guard let hour = Int(hourStr), let min = Int(minStr) else { return 0 }
        return hour * 60 + min
    }
    
    /// 课程时长（分钟）
    public var durationInMinutes: Int {
        endTimeInMinutes - startTimeInMinutes
    }
    
    /// 开始时间小时
    public var startHour: Double {
        guard startTime.count == 4 else { return 0 }
        let hourStr = String(startTime.prefix(2))
        let minStr = String(startTime.suffix(2))
        guard let hour = Int(hourStr), let min = Int(minStr) else { return 0 }
        return Double(hour) + Double(min) / 60.0
    }
    
    /// 结束时间小时
    public var endHour: Double {
        guard endTime.count == 4 else { return 0 }
        let hourStr = String(endTime.prefix(2))
        let minStr = String(endTime.suffix(2))
        guard let hour = Int(hourStr), let min = Int(minStr) else { return 0 }
        return Double(hour) + Double(min) / 60.0
    }
    
    /// 开始小时（整数部分）
    public var startHourInt: Int {
        guard startTime.count == 4 else { return 0 }
        return Int(String(startTime.prefix(2))) ?? 0
    }
    
    /// 开始分钟
    public var startMinute: Int {
        guard startTime.count == 4 else { return 0 }
        return Int(String(startTime.suffix(2))) ?? 0
    }
    
    /// 结束小时（整数部分）
    public var endHourInt: Int {
        guard endTime.count == 4 else { return 0 }
        return Int(String(endTime.prefix(2))) ?? 0
    }
    
    /// 结束分钟
    public var endMinute: Int {
        guard endTime.count == 4 else { return 0 }
        return Int(String(endTime.suffix(2))) ?? 0
    }
    
    /// 课程时长（小时）
    public var duration: Double {
        endHour - startHour
    }
    
    enum CodingKeys: String, CodingKey {
        case name
        case startTime = "start_time"
        case endTime = "end_time"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let nameStr = try container.decode(String.self, forKey: .name)
        self.name = nameStr
        self.slotNumber = Int(nameStr) ?? 0
        
        self.startTime = try container.decode(String.self, forKey: .startTime)
        self.endTime = try container.decode(String.self, forKey: .endTime)
    }
    
    public init(slotNumber: Int, name: String, startTime: String, endTime: String) {
        self.slotNumber = slotNumber
        self.name = name
        self.startTime = startTime
        self.endTime = endTime
    }
}

// MARK: - JSON 模型
struct ClassTimeJSON: Codable {
    let classtime: [ClassTimeConfig]
}

// MARK: - 全局课程时间管理器
public class ClassTimeManager {
    public static let shared = ClassTimeManager()
    
    private var classTimes: [ClassTimeConfig] = []
    
    private init() {
        loadClassTimes()
    }
    
    /// 从 CCZUKit 的 calendar.json 加载课程时间表
    private func loadClassTimes() {
        // 尝试从 CCZUKit bundle 加载
        if let bundleURL = Bundle.main.url(forResource: "CCZUKit_CCZUKit", withExtension: "bundle"),
           let bundle = Bundle(url: bundleURL),
           let jsonURL = bundle.url(forResource: "calendar", withExtension: "json") {
            do {
                let data = try Data(contentsOf: jsonURL)
                let decoder = JSONDecoder()
                let calendar = try decoder.decode(ClassTimeJSON.self, from: data)
                self.classTimes = calendar.classtime
                print("✅ 成功从 CCZUKit bundle 加载课程时间表")
                return
            } catch {
                print("⚠️ 从 CCZUKit bundle 加载失败: \(error)")
            }
        }
        
        // 降级到默认硬编码值
        loadDefaultClassTimes()
    }
    
    /// 加载默认的课程时间表（作为后备方案）
    private func loadDefaultClassTimes() {
        self.classTimes = [
            ClassTimeConfig(slotNumber: 1, name: "1", startTime: "0800", endTime: "0840"),
            ClassTimeConfig(slotNumber: 2, name: "2", startTime: "0845", endTime: "0925"),
            ClassTimeConfig(slotNumber: 3, name: "3", startTime: "0945", endTime: "1025"),
            ClassTimeConfig(slotNumber: 4, name: "4", startTime: "1035", endTime: "1115"),
            ClassTimeConfig(slotNumber: 5, name: "5", startTime: "1120", endTime: "1200"),
            ClassTimeConfig(slotNumber: 6, name: "6", startTime: "1330", endTime: "1410"),
            ClassTimeConfig(slotNumber: 7, name: "7", startTime: "1415", endTime: "1455"),
            ClassTimeConfig(slotNumber: 8, name: "8", startTime: "1515", endTime: "1555"),
            ClassTimeConfig(slotNumber: 9, name: "9", startTime: "1600", endTime: "1640"),
            ClassTimeConfig(slotNumber: 10, name: "10", startTime: "1830", endTime: "1910"),
            ClassTimeConfig(slotNumber: 11, name: "11", startTime: "1915", endTime: "1955"),
            ClassTimeConfig(slotNumber: 12, name: "12", startTime: "2005", endTime: "2045"),
        ]
        print("⚠️ 使用默认硬编码课程时间表")
    }
    
    /// 获取所有课程时间
    public var allClassTimes: [ClassTimeConfig] {
        return classTimes
    }
    
    /// 获取课程时间数组（用于兼容 AppSettings.classTimes 的调用方式）
    public static var classTimes: [ClassTimeConfig] {
        return shared.allClassTimes
    }
    
    /// 获取指定节次的课程时间
    public func getClassTime(for slotNumber: Int) -> ClassTimeConfig? {
        return classTimes.first { $0.slotNumber == slotNumber }
    }
    
    /// 获取课程的开始和结束时间（格式化为 HH:mm）
    public func getTimeRange(for timeSlot: Int) -> (start: String, end: String)? {
        guard let classTime = getClassTime(for: timeSlot) else { return nil }
        let start = formatTime(classTime.startTime)
        let end = formatTime(classTime.endTime)
        return (start, end)
    }
    
    /// 格式化时间 (HHmm -> HH:mm)
    private func formatTime(_ timeStr: String) -> String {
        guard timeStr.count == 4 else { return timeStr }
        let hour = String(timeStr.prefix(2))
        let minute = String(timeStr.suffix(2))
        return "\(hour):\(minute)"
    }
    
    /// 将节次转换为开始时间(分钟)
    public func timeSlotToMinutes(_ timeSlot: Int) -> Int {
        return getClassTime(for: timeSlot)?.startTimeInMinutes ?? 0
    }
    
    /// 获取节次的结束时间(分钟)
    public func timeSlotEndMinutes(_ timeSlot: Int) -> Int {
        return getClassTime(for: timeSlot)?.endTimeInMinutes ?? 0
    }
    
    /// 获取课程时长(以分钟为单位)
    public func courseDurationInMinutes(startSlot: Int, duration: Int) -> Int {
        guard duration > 0,
              let startTime = getClassTime(for: startSlot),
              let endTime = getClassTime(for: startSlot + duration - 1) else {
            return 0
        }
        return endTime.endTimeInMinutes - startTime.startTimeInMinutes
    }
}
