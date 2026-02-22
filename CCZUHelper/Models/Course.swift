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
    var name: String = ""
    var teacher: String = ""
    var location: String = ""
    var weeks: [Int] = []
    var dayOfWeek: Int = 1  // 1-7 表示周一到周日
    var timeSlot: Int = 1   // 第几节课（开始节次）
    var duration: Int = 2   // 课程持续的节次数（1表示1节课，2表示连续2节课）
    var color: String = "#007AFF"   // 颜色的十六进制值
    var scheduleId: String = ""  // 关联的课表ID
    
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
    var id: String = UUID().uuidString
    var name: String = ""
    var termName: String = ""
    var createdAt: Date = Date()
    var isActive: Bool = false
    
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
    
    /// 获取自适应文字颜色 - 返回背景颜色的深色版本或白色
    /// 在深色模式下优化文字可读性
    func adaptiveTextColor(isDarkMode: Bool) -> Color {
        // 获取当前颜色的RGB值
        guard let cgColor = self.cgColor else { return isDarkMode ? .white : .black }
        guard let components = cgColor.components, components.count >= 3 else { return isDarkMode ? .white : .black }
        
        let r = components[0]
        let g = components[1]
        let b = components[2]
        let a = components.count > 3 ? components[3] : 1.0
        
        // 计算相对亮度
        let luminance = calculateRelativeLuminance(r: r, g: g, b: b)
        
        if isDarkMode {
            // 深色模式：优先使用白色文字以提高可读性
            // 只有在背景非常暗时才使用浅色版本的原色
            if luminance < 0.2 {
                // 非常暗的背景，使用浅色版本
                return Color(red: min(1.0, r * 1.5), green: min(1.0, g * 1.5), blue: min(1.0, b * 1.5), opacity: a)
            } else {
                // 中等或浅色背景，使用白色文字确保对比度
                return Color.white
            }
        } else {
            // 浅色模式：使用深色版本的相同颜色
            let darkFactor = luminance > 0.5 ? 0.3 : 0.5  // 更深的颜色以提高对比度
            return Color(red: r * darkFactor, green: g * darkFactor, blue: b * darkFactor, opacity: a)
        }
    }
    
    /// 计算相对亮度（WCAG标准）
    /// 用于判断背景颜色是深还是浅，以调整文字颜色深度
    private func calculateRelativeLuminance(r: Double, g: Double, b: Double) -> Double {
        // 将sRGB转换为线性RGB
        let rLinear = r <= 0.03928 ? r / 12.92 : pow((r + 0.055) / 1.055, 2.4)
        let gLinear = g <= 0.03928 ? g / 12.92 : pow((g + 0.055) / 1.055, 2.4)
        let bLinear = b <= 0.03928 ? b / 12.92 : pow((b + 0.055) / 1.055, 2.4)
        
        // 计算相对亮度
        let luminance = 0.2126 * rLinear + 0.7152 * gLinear + 0.0722 * bLinear
        return luminance
    }
}
