//
//  CCZUHelperWidget.swift
//  CCZUHelperWidget
//
//  Created by rayanceking on 2025/12/4.
//

import WidgetKit
import SwiftUI

// MARK: - 课程时间配置（Widget独立版）
struct ClassTimeConfig {
    let slotNumber: Int
    let name: String
    let startTime: String  // 格式: HHmm
    let endTime: String    // 格式: HHmm
    
    var startTimeInMinutes: Int {
        guard startTime.count == 4 else { return 0 }
        let hourStr = String(startTime.prefix(2))
        let minStr = String(startTime.suffix(2))
        guard let hour = Int(hourStr), let min = Int(minStr) else { return 0 }
        return hour * 60 + min
    }
    
    var endTimeInMinutes: Int {
        guard endTime.count == 4 else { return 0 }
        let hourStr = String(endTime.prefix(2))
        let minStr = String(endTime.suffix(2))
        guard let hour = Int(hourStr), let min = Int(minStr) else { return 0 }
        return hour * 60 + min
    }
}

// MARK: - Widget课程时间表
let widgetClassTimes: [ClassTimeConfig] = [
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

// MARK: - 获取课程时间的辅助函数
func getWidgetClassTime(for slotNumber: Int) -> ClassTimeConfig? {
    return widgetClassTimes.first { $0.slotNumber == slotNumber }
}

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
    let dayOfWeek: Int  // 1-7 表示周一到周日
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
    
    @available(visionOS 26.0, *)
    func getTimeline(in context: Context, completion: @escaping (Timeline<CourseEntry>) -> Void) {
        let currentDate = Date()
        let allCourses = loadCourses()
        let todayCourses = allCourses.sorted { $0.timeSlot < $1.timeSlot }
        
        // 创建当前时刻的entry
        let currentEntry = CourseEntry(date: currentDate, courses: todayCourses)
        
        // 每分钟更新一次，生成接下来4小时的时间线
        var entries: [CourseEntry] = [currentEntry]
        for minuteOffset in stride(from: 1, to: 240, by: 1) {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentDate)!
            let entry = CourseEntry(date: entryDate, courses: todayCourses)
            entries.append(entry)
        }
        
        // 在时间线结束后重新请求更新，确保实时性
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
    
    // 从共享容器加载课程数据
    private func loadCourses() -> [WidgetCourse] {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.cczu.helper"
        ) else {
            print("🔴 Widget: 无法访问共享容器")
            return []
        }
        
        let fileURL = containerURL.appendingPathComponent("widget_courses.json")
        
        guard let data = try? Data(contentsOf: fileURL),
              let courses = try? JSONDecoder().decode([WidgetCourse].self, from: data) else {
            print("🔴 Widget: 无法读取课程文件")
            return []
        }
        
        print("✅ Widget加载课程:")
        print("  总数: \(courses.count)")
        for course in courses {
            print("    - \(course.name) (dayOfWeek: \(course.dayOfWeek), timeSlot: \(course.timeSlot))")
        }
        
        return courses
    }
    
    // 示例数据
    private func sampleCourses() -> [WidgetCourse] {
        return [
            WidgetCourse(name: "高等数学", teacher: "张老师", location: "A101", timeSlot: 1, duration: 2, color: "#FF6B6B", dayOfWeek: 1),
            WidgetCourse(name: "大学英语", teacher: "李老师", location: "B202", timeSlot: 3, duration: 2, color: "#4ECDC4", dayOfWeek: 1)
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
    
    var nextCourse: WidgetCourse? {
        let currentDate = entry.date
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: currentDate)
        let currentMinute = calendar.component(.minute, from: currentDate)
        let currentMinutes = currentHour * 60 + currentMinute
        
        // 找到当前或最接近的课程
        // 1. 先找正在进行的课程
        if let ongoingCourse = entry.courses.first(where: { course in
            let startMinutes = getWidgetClassTime(for: course.timeSlot)?.startTimeInMinutes ?? 0
            let endSlot = course.timeSlot + course.duration - 1
            let endMinutes = getWidgetClassTime(for: endSlot)?.endTimeInMinutes ?? 1440
            return currentMinutes >= startMinutes && currentMinutes < endMinutes
        }) {
            return ongoingCourse
        }
        
        // 2. 如果没有正在进行的课程，找最接近的未来课程
        return entry.courses.first { course in
            let startMinutes = getWidgetClassTime(for: course.timeSlot)?.startTimeInMinutes ?? 0
            return startMinutes > currentMinutes
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 顶部标题
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                Text("widget.today_courses".localized)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            
            if let course = nextCourse {
                // 显示临近课程，横向拉长
                VStack(alignment: .leading, spacing: 0) {
                    // 课程标题行
                    HStack(alignment: .top, spacing: 8) {
                        // 左侧色条
                        RoundedRectangle(cornerRadius: 2)
                            .fill(colorFromHex(course.color))
                            .frame(width: 4)
                        
                        // 课程名称
                        Text(course.name)
                            .font(.system(size: 13, weight: .bold))
                            .lineLimit(2)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    
                    Divider()
                        .padding(.horizontal, 8)
                    
                    // 课程详情行
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.blue)
                            Text(course.location)
                                .font(.system(size: 10, weight: .semibold))
                                .lineLimit(1)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.orange)
                            Text(timeRangeText(course))
                                .font(.system(size: 10, weight: .semibold))
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                .background(Color.gray.opacity(0.08))
                .cornerRadius(8)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            } else {
                // 无课程状态
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.green)
                    Text("widget.no_courses".localized)
                        .font(.system(size: 12, weight: .semibold))
                    Text("widget.no_courses_rest".localized)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
    }
    
    private func timeRangeText(_ course: WidgetCourse) -> String {
        let startTimeStr: String
        if let startClass = getWidgetClassTime(for: course.timeSlot) {
            startTimeStr = startClass.startTime
        } else {
            startTimeStr = "00:00"
        }
        
        let endSlot = course.timeSlot + course.duration - 1
        let endTimeStr: String
        if let endClass = getWidgetClassTime(for: endSlot) {
            endTimeStr = endClass.endTime
        } else {
            endTimeStr = "00:00"
        }
        
        let startFormatted = formatTimeDisplay(startTimeStr)
        let endFormatted = formatTimeDisplay(endTimeStr)
        
        return "\(startFormatted)-\(endFormatted)"
    }
    
}


// MARK: - 中等尺寸小组件 (4x2) - 当前/临近左右显示
struct MediumWidgetView: View {
    let entry: CourseEntry

    private var sortedCourses: [WidgetCourse] {
        entry.courses.sorted { $0.timeSlot < $1.timeSlot }
    }
    
    private var currentAndNext: (current: WidgetCourse?, next: WidgetCourse?) {
        let now = entry.date
        let calendar = Calendar.current
        let minutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        
        let current = sortedCourses.first { course in
            let start = getWidgetClassTime(for: course.timeSlot)?.startTimeInMinutes ?? 0
            let endSlot = course.timeSlot + course.duration - 1
            let end = getWidgetClassTime(for: endSlot)?.endTimeInMinutes ?? 1440
            return minutes >= start && minutes < end
        }
        
        var next: WidgetCourse?
        if let current = current {
            let endSlot = current.timeSlot + current.duration - 1
            let currentEnd = getWidgetClassTime(for: endSlot)?.endTimeInMinutes ?? 1440
            next = sortedCourses.first { course in
                let start = getWidgetClassTime(for: course.timeSlot)?.startTimeInMinutes ?? 0
                return start >= currentEnd && course.timeSlot != current.timeSlot
            }
        } else {
            next = sortedCourses.first { course in
                let start = getWidgetClassTime(for: course.timeSlot)?.startTimeInMinutes ?? 0
                return start > minutes
            }
        }
        
        return (current: current, next: next)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 13))
                    .foregroundColor(.blue)
                Text("widget.today_courses".localized)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(entry.date, style: .time)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)
            
            if let current = currentAndNext.current {
                HStack(spacing: 8) {
                    CompactCourseCardView(course: current, status: "widget.status.current".localized, statusColor: .orange)
                    if let next = currentAndNext.next {
                        CompactCourseCardView(course: next, status: "widget.status.next".localized, statusColor: .blue)
                    } else {
                        VStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.green)
                            Text("widget.status.done".localized)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(Color.gray.opacity(0.08))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 8)
            } else if let next = currentAndNext.next {
                HStack(spacing: 8) {
                    CompactCourseCardView(course: next, status: "widget.status.upcoming".localized, statusColor: .blue)
                    Spacer()
                }
                .padding(.horizontal, 8)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.green)
                    Text("widget.no_courses".localized)
                        .font(.system(size: 13, weight: .semibold))
                    Text("widget.no_courses_rest".localized)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.bottom, 8)
    }
}

// MARK: - 紧凑课程卡片（左右布局用）
struct CompactCourseCardView: View {
    let course: WidgetCourse
    let status: String
    let statusColor: Color
    
    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3)
                .fill(colorFromHex(course.color))
                .frame(width: 5)
                .padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 4, height: 4)
                    Text(status)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(statusColor)
                    Spacer()
                }
                
                Text(course.name)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(2)
                
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.orange)
                    Text(courseTimeDisplay(course))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.blue)
                    Text(course.location)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(8)
    }
    
    private func courseTimeDisplay(_ course: WidgetCourse) -> String {
        let startTimeStr: String
        if let startClass = getWidgetClassTime(for: course.timeSlot) {
            startTimeStr = formatTimeDisplay(startClass.startTime)
        } else {
            startTimeStr = "00:00"
        }
        
        let endSlot = course.timeSlot + course.duration - 1
        let endTimeStr: String
        if let endClass = getWidgetClassTime(for: endSlot) {
            endTimeStr = formatTimeDisplay(endClass.endTime)
        } else {
            endTimeStr = "00:00"
        }
        
        return "\(startTimeStr) - \(endTimeStr)"
    }
}

// MARK: - 通用时间格式化（HHmm -> HH:MM）
private func formatTimeDisplay(_ timeStr: String) -> String {
    guard timeStr.count == 4 else { return timeStr }
    let hour = String(timeStr.prefix(2))
    let minute = String(timeStr.suffix(2))
    return "\(hour):\(minute)"
}

// MARK: - 大尺寸小组件 (4x4)
@available(visionOS 26.0, *)
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
            
            if entry.courses.isEmpty || !hasUpcomingCourses() {
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
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(entry.courses.prefix(3).enumerated()), id: \.offset) { index, course in
                        CourseCardView(course: course, currentTime: entry.date)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    private func hasUpcomingCourses() -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: entry.date)
        let minute = calendar.component(.minute, from: entry.date)
        let currentMinutes = hour * 60 + minute
        
        return entry.courses.contains { course in
            guard let startClass = getWidgetClassTime(for: course.timeSlot) else { return false }
            _ = startClass.startTimeInMinutes
            let endSlot = course.timeSlot + course.duration - 1
            let endMinutes = getWidgetClassTime(for: endSlot)?.endTimeInMinutes ?? 1440
            return currentMinutes < endMinutes
        }
    }
    
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "widget.date_format".localized
        formatter.locale = Locale.current
        return formatter.string(from: entry.date)
    }
}

// MARK: - 超大尺寸小组件 (6x6)
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
            
            if entry.courses.isEmpty || !hasUpcomingCourses() {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    Text("widget.no_courses".localized)
                        .font(.system(size: 18, weight: .semibold))
                    Text("widget.no_courses_rest".localized)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                Divider()
                
                HStack(alignment: .top, spacing: 12) {
                    // 左侧统计栏
                    VStack(alignment: .leading, spacing: 10) {
                        StatItemView(title: "widget.total_courses".localized, value: "\(entry.courses.count)")
                        StatItemView(title: "widget.total_duration".localized, value: "\(totalDuration())")
                        if let current = currentCourse() {
                            StatItemView(title: "widget.current_course".localized, value: current.name)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: 180, alignment: .leading)
                    
                    // 右侧课程列表
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(entry.courses.prefix(5).enumerated()), id: \.offset) { _, course in
                            DetailedCourseCardView(course: course, currentTime: entry.date)
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
            guard let startClass = getWidgetClassTime(for: course.timeSlot),
                  let endClass = getWidgetClassTime(for: course.timeSlot + course.duration - 1) else {
                continue
            }
            
            let startMinutes = startClass.startTimeInMinutes
            let endMinutes = endClass.endTimeInMinutes
            
            if currentMinutes >= startMinutes && currentMinutes < endMinutes {
                return course
            }
        }
        return nil
    }
    
    private func getStartTime(for slot: Int) -> Int {
        if let classTime = getWidgetClassTime(for: slot) {
            return classTime.startTimeInMinutes
        }
        return 0
    }
    
    private func hasUpcomingCourses() -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: entry.date)
        let minute = calendar.component(.minute, from: entry.date)
        let currentMinutes = hour * 60 + minute
        
        return entry.courses.contains { course in
            guard let startClass = getWidgetClassTime(for: course.timeSlot) else { return false }
            _ = startClass.startTimeInMinutes
            let endSlot = course.timeSlot + course.duration - 1
            let endMinutes = getWidgetClassTime(for: endSlot)?.endTimeInMinutes ?? 1440
            return currentMinutes < endMinutes
        }
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
            
            Text(timeSlotStartText())
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.blue)
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func timeSlotStartText() -> String {
        if let classTime = getWidgetClassTime(for: course.timeSlot) {
            return formatTimeDisplay(classTime.startTime)
        }
        return "00:00"
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
                    Text(startTime())
                        .font(.system(size: 13, weight: .medium))
                    Text(endTime())
                        .font(.system(size: 13, weight: .medium))
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
        
        guard let startClass = getWidgetClassTime(for: course.timeSlot) else {
            return nil
        }
        
        let endSlot = course.timeSlot + course.duration - 1
        guard endSlot <= 12, let endClass = getWidgetClassTime(for: endSlot) else {
            return nil
        }
        
        let startMinutes = startClass.startTimeInMinutes
        let endMinutes = endClass.endTimeInMinutes
        
        if currentMinutes >= startMinutes && currentMinutes < endMinutes {
            return Double(currentMinutes - startMinutes) / Double(endMinutes - startMinutes)
        }
        return nil
    }
    
    private func timeSlotStartText() -> String {
        if let classTime = getWidgetClassTime(for: course.timeSlot) {
            return formatTimeDisplay(classTime.startTime)
        }
        return "00:00"
    }

    private func startTime() -> String {
        if let startClass = getWidgetClassTime(for: course.timeSlot) {
            return formatTimeDisplay(startClass.startTime)
        }
        return "00:00"
    }

    private func endTime() -> String {
        let endSlot = course.timeSlot + course.duration - 1
        if let endClass = getWidgetClassTime(for: endSlot) {
            return formatTimeDisplay(endClass.endTime)
        }
        return "00:00"
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
                
                Text(timeSlotStartText())
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
                    Label("\(startTime()) - \(endTime())", systemImage: "clock.fill")
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
        
        guard let startClass = getWidgetClassTime(for: course.timeSlot) else {
            return nil
        }
        
        let endSlot = course.timeSlot + course.duration - 1
        guard endSlot <= 12, let endClass = getWidgetClassTime(for: endSlot) else {
            return nil
        }
        
        let startMinutes = startClass.startTimeInMinutes
        let endMinutes = endClass.endTimeInMinutes
        
        if currentMinutes >= startMinutes && currentMinutes < endMinutes {
            return Double(currentMinutes - startMinutes) / Double(endMinutes - startMinutes)
        }
        return nil
    }
    
    private func timeSlotStartText() -> String {
        if let classTime = getWidgetClassTime(for: course.timeSlot) {
            return formatTimeDisplay(classTime.startTime)
        }
        return "00:00"
    }
    
    private func startTime() -> String {
        if let startClass = getWidgetClassTime(for: course.timeSlot) {
            return formatTimeDisplay(startClass.startTime)
        }
        return "00:00"
    }
    
    private func endTime() -> String {
        let endSlot = course.timeSlot + course.duration - 1
        if let endClass = getWidgetClassTime(for: endSlot) {
            return formatTimeDisplay(endClass.endTime)
        }
        return "00:00"
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

// MARK: - 锁屏小组件 - Rectangular (矩形)
struct AccessoryRectangularView: View {
    let entry: CourseEntry
    
    private var nextCourse: WidgetCourse? {
        let currentDate = entry.date
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: currentDate)
        let currentMinute = calendar.component(.minute, from: currentDate)
        let currentMinutes = currentHour * 60 + currentMinute
        
        // 1. 先找正在进行的课程
        if let ongoingCourse = entry.courses.first(where: { course in
            let startMinutes = getWidgetClassTime(for: course.timeSlot)?.startTimeInMinutes ?? 0
            let endSlot = course.timeSlot + course.duration - 1
            let endMinutes = getWidgetClassTime(for: endSlot)?.endTimeInMinutes ?? 1440
            return currentMinutes >= startMinutes && currentMinutes < endMinutes
        }) {
            return ongoingCourse
        }
        
        // 2. 如果没有正在进行的课程，找最接近的未来课程
        return entry.courses.first { course in
            let startMinutes = getWidgetClassTime(for: course.timeSlot)?.startTimeInMinutes ?? 0
            return startMinutes > currentMinutes
        }
    }
    
    var body: some View {
        if let course = nextCourse {
            HStack(spacing: 6) {
                // 左侧竖条
                RoundedRectangle(cornerRadius: 2)
                    .fill(colorFromHex(course.color))
                    .frame(width: 4)
                
                VStack(alignment: .leading, spacing: 3) {
                    // 课程名称
                    Text(course.name)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    
                    // 地点
                    HStack(spacing: 3) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 9))
                        Text(course.location)
                            .font(.system(size: 11))
                            .lineLimit(1)
                    }
                    
                    // 时间
                    HStack(spacing: 3) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 9))
                        Text(timeRangeText(course))
                            .font(.system(size: 11))
                    }
                }
                
                Spacer(minLength: 0)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                    Text("widget.lockscreen.no_course".localized)
                        .font(.system(size: 13, weight: .semibold))
                }
                Text("widget.lockscreen.rest".localized)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func timeRangeText(_ course: WidgetCourse) -> String {
        let startTimeStr: String
        if let startClass = getWidgetClassTime(for: course.timeSlot) {
            startTimeStr = startClass.startTime
        } else {
            startTimeStr = "0000"
        }
        
        let endSlot = course.timeSlot + course.duration - 1
        let endTimeStr: String
        if let endClass = getWidgetClassTime(for: endSlot) {
            endTimeStr = endClass.endTime
        } else {
            endTimeStr = "0000"
        }
        
        let startFormatted = formatTimeDisplay(startTimeStr)
        let endFormatted = formatTimeDisplay(endTimeStr)
        
        return "\(startFormatted)-\(endFormatted)"
    }
    
}

// MARK: - 锁屏小组件 - Inline (内联)
struct AccessoryInlineView: View {
    let entry: CourseEntry
    
    private var nextCourse: WidgetCourse? {
        let currentDate = entry.date
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: currentDate)
        let currentMinute = calendar.component(.minute, from: currentDate)
        let currentMinutes = currentHour * 60 + currentMinute
        
        // 1. 先找正在进行的课程
        if let ongoingCourse = entry.courses.first(where: { course in
            let startMinutes = getWidgetClassTime(for: course.timeSlot)?.startTimeInMinutes ?? 0
            let endSlot = course.timeSlot + course.duration - 1
            let endMinutes = getWidgetClassTime(for: endSlot)?.endTimeInMinutes ?? 1440
            return currentMinutes >= startMinutes && currentMinutes < endMinutes
        }) {
            return ongoingCourse
        }
        
        // 2. 如果没有正在进行的课程，找最接近的未来课程
        return entry.courses.first { course in
            let startMinutes = getWidgetClassTime(for: course.timeSlot)?.startTimeInMinutes ?? 0
            return startMinutes > currentMinutes
        }
    }
    
    var body: some View {
        if let course = nextCourse {
            // 开始时间 | 地点 | 课程
            Text("\(startTimeText(course)) | \(course.location) | \(course.name)")
        } else {
            Text("widget.lockscreen.no_course".localized)
        }
    }
    
    private func startTimeText(_ course: WidgetCourse) -> String {
        if let startClass = getWidgetClassTime(for: course.timeSlot) {
            return formatTimeDisplay(startClass.startTime)
        }
        return "00:00"
    }
    
    // formatTimeDisplay is a global private func, no need to redefine here
}

// MARK: - 锁屏小组件 - Circular (圆形)
struct AccessoryCircularView: View {
    let entry: CourseEntry
    
    private var nextCourse: WidgetCourse? {
        let currentDate = entry.date
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: currentDate)
        let currentMinute = calendar.component(.minute, from: currentDate)
        let currentMinutes = currentHour * 60 + currentMinute
        
        // 1. 先找正在进行的课程
        if let ongoingCourse = entry.courses.first(where: { course in
            let startMinutes = getWidgetClassTime(for: course.timeSlot)?.startTimeInMinutes ?? 0
            let endSlot = course.timeSlot + course.duration - 1
            let endMinutes = getWidgetClassTime(for: endSlot)?.endTimeInMinutes ?? 1440
            return currentMinutes >= startMinutes && currentMinutes < endMinutes
        }) {
            return ongoingCourse
        }
        
        // 2. 如果没有正在进行的课程，找最接近的未来课程
        return entry.courses.first { course in
            let startMinutes = getWidgetClassTime(for: course.timeSlot)?.startTimeInMinutes ?? 0
            return startMinutes > currentMinutes
        }
    }
    
    var body: some View {
        if let course = nextCourse {
            VStack {
                Text(startTimeText(course))
                    .font(.footnote)
                    .bold()
                    .widgetAccentable() // Makes text stand out
                
                Text(course.name)
                    .font(.caption2)
                    .lineLimit(1)
            }
        } else {
            VStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("widget.lockscreen.no_course".localized)
                    .font(.caption2)
            }
        }
    }
    
    private func startTimeText(_ course: WidgetCourse) -> String {
        if let startClass = getWidgetClassTime(for: course.timeSlot) {
            return formatTimeDisplay(startClass.startTime)
        }
        return "00:00"
    }
    
    // formatTimeDisplay is a global private func, no need to redefine here
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
        .supportedFamilies({
            #if os(visionOS)
            return [
                .systemSmall,
                .systemMedium,
                .systemLarge,
                .systemExtraLarge
            ]
            #else
            return [
                .systemSmall,
                .systemMedium,
                .systemLarge,
                .systemExtraLarge,
                .accessoryRectangular,
                .accessoryInline,
                .accessoryCircular
            ]
            #endif
        }())

    }
}

// MARK: - 主视图（根据尺寸选择）
@available(visionOS 26.0, *)
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

        #if !os(visionOS)
        case .accessoryRectangular:
            AccessoryRectangularView(entry: entry)
        case .accessoryInline:
            AccessoryInlineView(entry: entry)
        case .accessoryCircular:
            AccessoryCircularView(entry: entry)
        #endif

        case .systemExtraLargePortrait:
            // Placeholder replaced with ExtraLargeWidgetView
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
        WidgetCourse(name: "高等数学", teacher: "张老师", location: "A101", timeSlot: 1, duration: 2, color: "#FF6B6B", dayOfWeek: 1),
        WidgetCourse(name: "大学英语", teacher: "李老师", location: "B202", timeSlot: 3, duration: 2, color: "#4ECDC4", dayOfWeek: 1)
    ])
}

#Preview(as: .systemMedium) {
    CCZUHelperWidget()
} timeline: {
    CourseEntry(date: .now, courses: [
        WidgetCourse(name: "高等数学", teacher: "张老师", location: "A101", timeSlot: 1, duration: 2, color: "#FF6B6B", dayOfWeek: 1),
        WidgetCourse(name: "大学英语", teacher: "李老师", location: "B202", timeSlot: 3, duration: 2, color: "#4ECDC4", dayOfWeek: 1),
        WidgetCourse(name: "计算机导论", teacher: "王老师", location: "C303", timeSlot: 5, duration: 2, color: "#95E1D3", dayOfWeek: 1)
    ])
}

#Preview(as: .systemLarge) {
    CCZUHelperWidget()
} timeline: {
    CourseEntry(date: .now, courses: [
        WidgetCourse(name: "高等数学", teacher: "张老师", location: "A101", timeSlot: 1, duration: 2, color: "#FF6B6B", dayOfWeek: 1),
        WidgetCourse(name: "大学英语", teacher: "李老师", location: "B202", timeSlot: 3, duration: 2, color: "#4ECDC4", dayOfWeek: 1),
        WidgetCourse(name: "计算机导论", teacher: "王老师", location: "C303", timeSlot: 5, duration: 2, color: "#95E1D3", dayOfWeek: 1),
        WidgetCourse(name: "体育", teacher: "赵老师", location: "操场", timeSlot: 7, duration: 2, color: "#F38181", dayOfWeek: 1)
    ])
}

//#Preview(as: .accessoryCircular) {
//    CCZUHelperWidget()
//} timeline: {
//    CourseEntry(date: .now, courses: [
//        WidgetCourse(name: "高等数学", teacher: "张老师", location: "A101", timeSlot: 1, duration: 2, color: "#FF6B6B", dayOfWeek: 1),
//        WidgetCourse(name: "大学英语", teacher: "李老师", location: "B202", timeSlot: 3, duration: 2, color: "#4ECDC4", dayOfWeek: 1)
//    ])
//}

