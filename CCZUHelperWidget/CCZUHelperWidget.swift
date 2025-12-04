//
//  CCZUHelperWidget.swift
//  CCZUHelperWidget
//
//  Created by rayanceking on 2025/12/4.
//

import WidgetKit
import SwiftUI

// MARK: - 本地化辅助
extension String {
    var localized: String {
        NSLocalizedString(self, bundle: Bundle.main, comment: "")
    }
    
    func localized(_ args: CVarArg...) -> String {
        String(format: NSLocalizedString(self, bundle: Bundle.main, comment: ""), arguments: args)
    }
}

// MARK: - 课程数据模型
struct WidgetCourse: Codable {
    let name: String
    let teacher: String
    let location: String
    let timeSlot: Int
    let duration: Int
    let color: String
}

// MARK: - Timeline Provider
struct CourseProvider: TimelineProvider {
    typealias Entry = CourseEntry
    
    func placeholder(in context: Context) -> CourseEntry {
        CourseEntry(date: Date(), courses: sampleCourses())
    }
    
    func getSnapshot(in context: Context, completion: @escaping (CourseEntry) -> Void) {
        let entry = CourseEntry(date: Date(), courses: loadCourses())
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<CourseEntry>) -> Void) {
        let currentDate = Date()
        let courses = loadCourses()
        
        // 每30分钟更新一次
        var entries: [CourseEntry] = []
        for minuteOffset in stride(from: 0, to: 60 * 12, by: 30) {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentDate)!
            let entry = CourseEntry(date: entryDate, courses: courses)
            entries.append(entry)
        }
        
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
    
    // 从共享容器加载课程数据
    private func loadCourses() -> [WidgetCourse] {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.cczu.helper"
        ) else {
            return []
        }
        
        let fileURL = containerURL.appendingPathComponent("widget_courses.json")
        
        guard let data = try? Data(contentsOf: fileURL),
              let courses = try? JSONDecoder().decode([WidgetCourse].self, from: data) else {
            return []
        }
        
        return courses
    }
    
    // 示例数据
    private func sampleCourses() -> [WidgetCourse] {
        return [
            WidgetCourse(name: "高等数学", teacher: "张老师", location: "A101", timeSlot: 1, duration: 2, color: "#FF6B6B"),
            WidgetCourse(name: "大学英语", teacher: "李老师", location: "B202", timeSlot: 3, duration: 2, color: "#4ECDC4")
        ]
    }
}

// MARK: - Timeline Entry
struct CourseEntry: TimelineEntry {
    let date: Date
    let courses: [WidgetCourse]
}

// MARK: - 小尺寸小组件 (2x2)
struct SmallWidgetView: View {
    let entry: CourseEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.blue)
                Text("widget.today_courses".localized)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
            }
            
            if entry.courses.isEmpty {
                Spacer()
                Text("widget.no_courses".localized)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                Spacer()
                Text("widget.courses_count".localized(entry.courses.count))
                    .font(.system(size: 20, weight: .bold))
                
                if entry.courses.count > 0 {
                    Text(entry.courses[0].name)
                        .font(.system(size: 12))
                        .lineLimit(1)
                }
                
                if entry.courses.count > 1 {
                    Text(entry.courses[1].name)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
        }
        .padding()
    }
}

// MARK: - 中等尺寸小组件 (2x3)
struct MediumWidgetView: View {
    let entry: CourseEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(.blue)
                Text("widget.today_courses".localized)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Text(entry.date, style: .time)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            if entry.courses.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                    Text("widget.no_courses".localized)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                ForEach(Array(entry.courses.prefix(3).enumerated()), id: \.offset) { index, course in
                    CourseRowView(course: course)
                }
                Spacer()
            }
        }
        .padding()
    }
}

// MARK: - 大尺寸小组件 (4x4) - 包含时间线
struct LargeWidgetView: View {
    let entry: CourseEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 头部
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("widget.today_courses".localized)
                        .font(.system(size: 18, weight: .bold))
                    Text(formattedDate())
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(entry.date, style: .time)
                        .font(.system(size: 16, weight: .semibold))
                    Text("widget.current_time".localized)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            if entry.courses.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                    Text("widget.no_courses".localized)
                        .font(.system(size: 16))
                    Text("widget.no_courses_rest".localized)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(entry.courses.enumerated()), id: \.offset) { index, course in
                            CourseCardView(course: course, currentTime: entry.date)
                        }
                    }
                }
            }
        }
        .padding()
    }
    
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "widget.date_format".localized
        formatter.locale = Locale.current
        return formatter.string(from: entry.date)
    }
}

// MARK: - 超大尺寸小组件 (6x6) - 完整时间线视图
struct ExtraLargeWidgetView: View {
    let entry: CourseEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 头部信息
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("widget.today_schedule".localized)
                        .font(.system(size: 20, weight: .bold))
                    Text(formattedDate())
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(entry.date, style: .time)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.blue)
                    Text("widget.current_time".localized)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            if entry.courses.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    Text("widget.no_courses".localized)
                        .font(.system(size: 18, weight: .semibold))
                    Text("widget.no_courses_enjoy".localized)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                Divider()
                
                // 课程统计
                HStack(spacing: 20) {
                    StatItemView(title: "widget.total_courses".localized, value: "\(entry.courses.count)")
                    StatItemView(title: "widget.total_duration".localized, value: "\(totalDuration())")
                    if let current = currentCourse() {
                        StatItemView(title: "widget.current_course".localized, value: current.name)
                    }
                }
                .padding(.vertical, 8)
                
                Divider()
                
                // 课程列表
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(entry.courses.enumerated()), id: \.offset) { index, course in
                            DetailedCourseCardView(course: course, currentTime: entry.date)
                        }
                    }
                }
            }
        }
        .padding()
    }
    
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "widget.date_format_full".localized
        formatter.locale = Locale.current
        return formatter.string(from: entry.date)
    }
    
    private func totalDuration() -> Int {
        return entry.courses.reduce(0) { $0 + $1.duration }
    }
    
    private func currentCourse() -> WidgetCourse? {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: entry.date)
        let minute = calendar.component(.minute, from: entry.date)
        let currentMinutes = hour * 60 + minute
        
        for course in entry.courses {
            let startMinutes = getStartTime(for: course.timeSlot)
            let endMinutes = startMinutes + course.duration * 45
            if currentMinutes >= startMinutes && currentMinutes < endMinutes {
                return course
            }
        }
        return nil
    }
    
    private func getStartTime(for slot: Int) -> Int {
        let times = [
            1: 8 * 60,      // 8:00
            2: 8 * 60 + 50, // 8:50
            3: 10 * 60,     // 10:00
            4: 10 * 60 + 50,// 10:50
            5: 14 * 60,     // 14:00
            6: 14 * 60 + 50,// 14:50
            7: 16 * 60,     // 16:00
            8: 16 * 60 + 50,// 16:50
            9: 19 * 60,     // 19:00
            10: 19 * 60 + 50// 19:50
        ]
        return times[slot] ?? 0
    }
}

// MARK: - 课程行视图（简洁版）
struct CourseRowView: View {
    let course: WidgetCourse
    
    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 4)
                .fill(colorFromHex(course.color))
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(course.name)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Label(course.location, systemImage: "location.fill")
                    Label(course.teacher, systemImage: "person.fill")
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(timeSlotText(course.timeSlot))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.blue)
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func timeSlotText(_ slot: Int) -> String {
        let times = [
            1: "8:00", 2: "8:50", 3: "10:00", 4: "10:50",
            5: "14:00", 6: "14:50", 7: "16:00", 8: "16:50",
            9: "19:00", 10: "19:50"
        ]
        return times[slot] ?? ""
    }
}

// MARK: - 课程卡片视图（带进度条）
struct CourseCardView: View {
    let course: WidgetCourse
    let currentTime: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(colorFromHex(course.color))
                    .frame(width: 6, height: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(course.name)
                        .font(.system(size: 15, weight: .semibold))
                    HStack(spacing: 12) {
                        Label(course.location, systemImage: "location.fill")
                        Label(course.teacher, systemImage: "person.fill")
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(timeSlotText(course.timeSlot))
                        .font(.system(size: 13, weight: .medium))
                    Text("\(course.duration)节")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            // 时间进度条
            if let progress = courseProgress() {
                ProgressView(value: progress)
                    .tint(colorFromHex(course.color))
            }
        }
        .padding(10)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(10)
    }
    
    private func courseProgress() -> Double? {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentTime)
        let minute = calendar.component(.minute, from: currentTime)
        let currentMinutes = hour * 60 + minute
        
        let startMinutes = getStartTime(for: course.timeSlot)
        let endMinutes = startMinutes + course.duration * 45
        
        if currentMinutes >= startMinutes && currentMinutes < endMinutes {
            return Double(currentMinutes - startMinutes) / Double(endMinutes - startMinutes)
        }
        return nil
    }
    
    private func timeSlotText(_ slot: Int) -> String {
        let times = [
            1: "8:00", 2: "8:50", 3: "10:00", 4: "10:50",
            5: "14:00", 6: "14:50", 7: "16:00", 8: "16:50",
            9: "19:00", 10: "19:50"
        ]
        return times[slot] ?? ""
    }
    
    private func getStartTime(for slot: Int) -> Int {
        let times = [
            1: 8 * 60, 2: 8 * 60 + 50, 3: 10 * 60, 4: 10 * 60 + 50,
            5: 14 * 60, 6: 14 * 60 + 50, 7: 16 * 60, 8: 16 * 60 + 50,
            9: 19 * 60, 10: 19 * 60 + 50
        ]
        return times[slot] ?? 0
    }
}

// MARK: - 详细课程卡片视图
struct DetailedCourseCardView: View {
    let course: WidgetCourse
    let currentTime: Date
    
    var body: some View {
        HStack(spacing: 12) {
            // 左侧色条和时间
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(colorFromHex(course.color))
                    .frame(width: 8, height: 60)
                
                Text(timeSlotText(course.timeSlot))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            // 课程信息
            VStack(alignment: .leading, spacing: 6) {
                Text(course.name)
                    .font(.system(size: 16, weight: .semibold))
                
                HStack(spacing: 16) {
                    Label(course.location, systemImage: "location.fill")
                    Label(course.teacher, systemImage: "person.fill")
                    Label("\(course.duration)节", systemImage: "clock.fill")
                }
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                
                // 进度条
                if let progress = courseProgress() {
                    HStack(spacing: 8) {
                        ProgressView(value: progress)
                            .tint(colorFromHex(course.color))
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(colorFromHex(course.color))
                    }
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(courseProgress() != nil ? 0.15 : 0.08))
        )
    }
    
    private func courseProgress() -> Double? {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentTime)
        let minute = calendar.component(.minute, from: currentTime)
        let currentMinutes = hour * 60 + minute
        
        let startMinutes = getStartTime(for: course.timeSlot)
        let endMinutes = startMinutes + course.duration * 45
        
        if currentMinutes >= startMinutes && currentMinutes < endMinutes {
            return Double(currentMinutes - startMinutes) / Double(endMinutes - startMinutes)
        }
        return nil
    }
    
    private func timeSlotText(_ slot: Int) -> String {
        let times = [
            1: "8:00", 2: "8:50", 3: "10:00", 4: "10:50",
            5: "14:00", 6: "14:50", 7: "16:00", 8: "16:50",
            9: "19:00", 10: "19:50"
        ]
        return times[slot] ?? ""
    }
    
    private func getStartTime(for slot: Int) -> Int {
        let times = [
            1: 8 * 60, 2: 8 * 60 + 50, 3: 10 * 60, 4: 10 * 60 + 50,
            5: 14 * 60, 6: 14 * 60 + 50, 7: 16 * 60, 8: 16 * 60 + 50,
            9: 19 * 60, 10: 19 * 60 + 50
        ]
        return times[slot] ?? 0
    }
}

// MARK: - 统计项视图
struct StatItemView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.blue)
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 辅助函数
private func colorFromHex(_ hex: String) -> Color {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)
    let r, g, b: UInt64
    switch hex.count {
    case 3:
        (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
    case 6:
        (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
    default:
        (r, g, b) = (0, 0, 0)
    }
    return Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
}

// MARK: - Widget配置
struct CCZUHelperWidget: Widget {
    let kind: String = "CCZUHelperWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CourseProvider()) { entry in
            WidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("widget.title".localized)
        .description("widget.description".localized)
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

// MARK: - 主视图（根据尺寸选择）
struct WidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: CourseEntry
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        case .systemExtraLarge:
            ExtraLargeWidgetView(entry: entry)
        @unknown default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Preview
#Preview(as: .systemSmall) {
    CCZUHelperWidget()
} timeline: {
    CourseEntry(date: .now, courses: [
        WidgetCourse(name: "高等数学", teacher: "张老师", location: "A101", timeSlot: 1, duration: 2, color: "#FF6B6B"),
        WidgetCourse(name: "大学英语", teacher: "李老师", location: "B202", timeSlot: 3, duration: 2, color: "#4ECDC4")
    ])
}

#Preview(as: .systemMedium) {
    CCZUHelperWidget()
} timeline: {
    CourseEntry(date: .now, courses: [
        WidgetCourse(name: "高等数学", teacher: "张老师", location: "A101", timeSlot: 1, duration: 2, color: "#FF6B6B"),
        WidgetCourse(name: "大学英语", teacher: "李老师", location: "B202", timeSlot: 3, duration: 2, color: "#4ECDC4"),
        WidgetCourse(name: "计算机导论", teacher: "王老师", location: "C303", timeSlot: 5, duration: 2, color: "#95E1D3")
    ])
}

#Preview(as: .systemLarge) {
    CCZUHelperWidget()
} timeline: {
    CourseEntry(date: .now, courses: [
        WidgetCourse(name: "高等数学", teacher: "张老师", location: "A101", timeSlot: 1, duration: 2, color: "#FF6B6B"),
        WidgetCourse(name: "大学英语", teacher: "李老师", location: "B202", timeSlot: 3, duration: 2, color: "#4ECDC4"),
        WidgetCourse(name: "计算机导论", teacher: "王老师", location: "C303", timeSlot: 5, duration: 2, color: "#95E1D3"),
        WidgetCourse(name: "体育", teacher: "赵老师", location: "操场", timeSlot: 7, duration: 2, color: "#F38181")
    ])
}
