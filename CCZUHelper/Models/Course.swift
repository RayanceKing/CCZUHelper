//
//  Course.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/11/30.
//

import SwiftUI
import SwiftData

/// 课程数据模型
@Model
final class Course {
    var name: String
    var teacher: String
    var location: String
    var weeks: [Int]
    var dayOfWeek: Int  // 1-7 表示周一到周日
    var timeSlot: Int   // 第几节课（开始节次）
    var duration: Int   // 课程持续的节次数（1表示1节课，2表示连续2节课）
    var color: String   // 颜色的十六进制值
    var scheduleId: String  // 关联的课表ID
    
    init(
        name: String,
        teacher: String,
        location: String,
        weeks: [Int],
        dayOfWeek: Int,
        timeSlot: Int,
        duration: Int = 2,
        color: String = "#007AFF",
        scheduleId: String
    ) {
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
    
    /// 从HEX字符串获取Color
    var uiColor: Color {
        Color(hex: color) ?? .blue
    }
}

/// 课表数据模型
@Model
final class Schedule {
    @Attribute(.unique) var id: String
    var name: String
    var termName: String
    var createdAt: Date
    var isActive: Bool
    
    init(
        id: String = UUID().uuidString,
        name: String,
        termName: String,
        createdAt: Date = Date(),
        isActive: Bool = false
    ) {
        self.id = id
        self.name = name
        self.termName = termName
        self.createdAt = createdAt
        self.isActive = isActive
    }
}

// MARK: - Color Extension for Hex
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }
        
        let length = hexSanitized.count
        
        let r, g, b, a: Double
        
        switch length {
        case 6: // RGB (24-bit)
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
            a = 1.0
        case 8: // ARGB (32-bit)
            a = Double((rgb & 0xFF000000) >> 24) / 255.0
            r = Double((rgb & 0x00FF0000) >> 16) / 255.0
            g = Double((rgb & 0x0000FF00) >> 8) / 255.0
            b = Double(rgb & 0x000000FF) / 255.0
        default:
            return nil
        }
        
        self.init(red: r, green: g, blue: b, opacity: a)
    }
    
    /// 预定义的课程颜色
    static let courseColors: [Color] = [
        Color(hex: "#FF6B6B")!,  // 红色
        Color(hex: "#4ECDC4")!,  // 青色
        Color(hex: "#45B7D1")!,  // 蓝色
        Color(hex: "#96CEB4")!,  // 绿色
        Color(hex: "#FFEAA7")!,  // 黄色
        Color(hex: "#DDA0DD")!,  // 紫色
        Color(hex: "#98D8C8")!,  // 薄荷色
        Color(hex: "#F7DC6F")!,  // 金色
        Color(hex: "#BB8FCE")!,  // 淡紫色
        Color(hex: "#85C1E9")!,  // 天蓝色
    ]
    
    /// 预定义的颜色HEX值
    static let courseColorHexes: [String] = [
        "#FF6B6B",
        "#4ECDC4",
        "#45B7D1",
        "#96CEB4",
        "#FFEAA7",
        "#DDA0DD",
        "#98D8C8",
        "#F7DC6F",
        "#BB8FCE",
        "#85C1E9",
    ]
    
    /// 生成更深的颜色版本（用于提高对比度的文字）
    func darkerColor() -> Color {
        // 获取当前颜色的RGB值
        guard let cgColor = self.cgColor else { return self }
        guard let components = cgColor.components, components.count >= 3 else { return self }
        
        let r = components[0]
        let g = components[1]
        let b = components[2]
        let a = components.count > 3 ? components[3] : 1.0
        
        // 使颜色变深50%
        let factor = 0.5
        return Color(red: r * factor, green: g * factor, blue: b * factor, opacity: a)
    }
    
    /// 获取自适应文字颜色（深色模式始终用白色获得最大对比度）
    func adaptiveTextColor(isDarkMode: Bool) -> Color {
        if isDarkMode {
            return .white
        }
        return darkerColor()
    }
}
