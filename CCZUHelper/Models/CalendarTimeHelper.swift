//
//  CalendarTimeHelper.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/04.
//

import Foundation

/// 课程时间段模型
struct ClassTime {
    let slotNumber: Int           // 节次编号 (1-12)
    let name: String              // 节次名称
    let startTime: String         // 开始时间 (格式: HHmm, 如 "0800")
    let endTime: String           // 结束时间 (格式: HHmm, 如 "0840")
    
    /// 开始时间小时
    var startHour: Double {
        guard startTime.count == 4 else { return 0 }
        let hourStr = String(startTime.prefix(2))
        let minStr = String(startTime.suffix(2))
        guard let hour = Int(hourStr), let min = Int(minStr) else { return 0 }
        return Double(hour) + Double(min) / 60.0
    }
    
    /// 结束时间小时
    var endHour: Double {
        guard endTime.count == 4 else { return 0 }
        let hourStr = String(endTime.prefix(2))
        let minStr = String(endTime.suffix(2))
        guard let hour = Int(hourStr), let min = Int(minStr) else { return 0 }
        return Double(hour) + Double(min) / 60.0
    }
    
    /// 课程时长（小时）
    var duration: Double {
        endHour - startHour
    }
}

/// 日历时间助手类
class CalendarTimeHelper {
    /// 课程时间表（节次对应的时间）
    private let classTimeTable: [ClassTime]
    
    init() {
        // 初始化默认的课程时间表
        self.classTimeTable = [
            ClassTime(slotNumber: 1, name: "1", startTime: "0800", endTime: "0840"),
            ClassTime(slotNumber: 2, name: "2", startTime: "0845", endTime: "0925"),
            ClassTime(slotNumber: 3, name: "3", startTime: "0945", endTime: "1025"),
            ClassTime(slotNumber: 4, name: "4", startTime: "1035", endTime: "1115"),
            ClassTime(slotNumber: 5, name: "5", startTime: "1120", endTime: "1200"),
            ClassTime(slotNumber: 6, name: "6", startTime: "1330", endTime: "1410"),
            ClassTime(slotNumber: 7, name: "7", startTime: "1415", endTime: "1455"),
            ClassTime(slotNumber: 8, name: "8", startTime: "1515", endTime: "1555"),
            ClassTime(slotNumber: 9, name: "9", startTime: "1600", endTime: "1640"),
            ClassTime(slotNumber: 10, name: "10", startTime: "1830", endTime: "1910"),
            ClassTime(slotNumber: 11, name: "11", startTime: "1915", endTime: "1955"),
            ClassTime(slotNumber: 12, name: "12", startTime: "2005", endTime: "2045"),
        ]
    }
    
    /// 通过JSON文件初始化（支持自定义课程时间表）
    /// - Parameter jsonURL: calendar.json 文件的URL
    init?(jsonURL: URL) {
        do {
            let data = try Data(contentsOf: jsonURL)
            let decoder = JSONDecoder()
            let calendar = try decoder.decode(CalendarJSON.self, from: data)
            self.classTimeTable = calendar.classtime
        } catch {
            print("Failed to load calendar.json: \(error)")
            return nil
        }
    }
    
    /// 获取指定节次的课程时间
    /// - Parameter slotNumber: 节次编号 (1-12)
    /// - Returns: ClassTime对象，如果节次无效则返回nil
    func getClassTime(for slotNumber: Int) -> ClassTime? {
        return classTimeTable.first { $0.slotNumber == slotNumber }
    }
    
    /// 获取课程开始时间（小时）
    /// - Parameter slotNumber: 节次编号
    /// - Returns: 开始时间小时值
    func getStartHour(for slotNumber: Int) -> Double? {
        return getClassTime(for: slotNumber)?.startHour
    }
    
    /// 获取课程结束时间（小时）
    /// - Parameter slotNumber: 节次编号
    /// - Returns: 结束时间小时值
    func getEndHour(for slotNumber: Int) -> Double? {
        return getClassTime(for: slotNumber)?.endHour
    }
    
    /// 获取多节课程的总时长
    /// - Parameters:
    ///   - startSlot: 开始节次
    ///   - duration: 课程持续的节次数
    /// - Returns: 总时长（小时）
    func getDuration(startSlot: Int, duration: Int) -> Double? {
        guard let startTime = getClassTime(for: startSlot),
              let endTime = getClassTime(for: startSlot + duration - 1) else {
            return nil
        }
        return endTime.endHour - startTime.startHour
    }
    
    /// 获取课程在一天中的位置信息
    /// - Parameters:
    ///   - slotNumber: 开始节次
    ///   - totalHours: 一天总课时数（用于计算百分比位置）
    /// - Returns: (顶部偏移百分比, 高度百分比)
    func getPositionInfo(for slotNumber: Int, totalHours: Int) -> (topPercent: Double, heightPercent: Double)? {
        guard let classTime = getClassTime(for: slotNumber) else {
            return nil
        }
        
        let minHour = 8.0  // 通常最早的课程开始时间
        let relativeStart = classTime.startHour - minHour
        
        let topPercent = relativeStart / Double(totalHours)
        let heightPercent = classTime.duration / Double(totalHours)
        
        return (topPercent, heightPercent)
    }
}

// MARK: - JSON 模型
struct CalendarJSON: Codable {
    let classtime: [ClassTime]
    
    enum CodingKeys: String, CodingKey {
        case classtime
    }
}

extension ClassTime: Codable {
    enum CodingKeys: String, CodingKey {
        case name
        case startTime = "start_time"
        case endTime = "end_time"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let nameStr = try container.decode(String.self, forKey: .name)
        self.name = nameStr
        self.slotNumber = Int(nameStr) ?? 0
        
        self.startTime = try container.decode(String.self, forKey: .startTime)
        self.endTime = try container.decode(String.self, forKey: .endTime)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
    }
}
