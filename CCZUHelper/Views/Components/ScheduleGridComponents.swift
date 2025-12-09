//
//  ScheduleGridComponents.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/03.
//

import SwiftUI

// MARK: - 星期标题行
struct WeekdayHeader: View {
    let width: CGFloat
    let timeAxisWidth: CGFloat
    let headerHeight: CGFloat
    let weekDates: [Date]
    let settings: AppSettings
    let helpers: ScheduleHelpers
    
    private let calendar = Calendar.current
    
    var body: some View {
        let rawDayWidth = (width - timeAxisWidth) / 7
        let dayWidth = max(0, rawDayWidth.isFinite ? rawDayWidth : 0)
        
        return HStack(spacing: 0) {
            // 左上角空白
            Color.clear
                .frame(width: timeAxisWidth, height: headerHeight)
            
            // 星期标题
            ForEach(Array(0..<7), id: \.self) { index in
                let date = weekDates[index]
                let isToday = calendar.isDateInToday(date)
                
                VStack(spacing: 4) {
                    Text(helpers.weekdayName(for: index, weekStartDay: settings.weekStartDay))
                        .font(.caption)
                        .foregroundStyle(isToday ? .blue : .secondary)
                    
                    Text("\(calendar.component(.day, from: date))")
                        .font(.headline)
                        .fontWeight(isToday ? .bold : .regular)
                        .foregroundStyle(isToday ? .white : .primary)
                        .frame(width: 28, height: 28)
                        .background(isToday ? Color.blue : Color.clear)
                        .clipShape(Circle())
                }
                .frame(width: dayWidth, height: headerHeight)
            }
        }
        #if os(macOS)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.95))
        #else
        .background(Color(.systemBackground).opacity(0.95))
        #endif
    }
}

// MARK: - 网格线
struct ScheduleGridLines: View {
    let dayWidth: CGFloat
    let hourHeight: CGFloat
    let totalHours: Int
    let settings: AppSettings

    var body: some View {
        switch settings.timelineDisplayMode {
        case .standardTime:
            standardTimeGridView
        case .classTime:
            classTimeGridView
        }
    }
    
    // 标准时间网格（按小时绘制）
    private var standardTimeGridView: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            // 行分割线（每个小时一行）
            ForEach(0..<totalHours, id: \.self) { _ in
                GridRow {
                    // 7 列
                    ForEach(0..<7, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: dayWidth, height: hourHeight)
                            .overlay(
                                // 单元格边框（右和下），避免重复绘制左/上边界
                                ZStack(alignment: .topLeading) {
                                    // 右边界
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 1)
                                        .frame(maxHeight: .infinity)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                    // 下边界
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 1)
                                        .frame(maxWidth: .infinity)
                                        .frame(maxHeight: .infinity, alignment: .bottom)
                                }
                            )
                    }
                }
            }
            // 追加一行用于绘制最底部横线
            GridRow {
                ForEach(0..<7, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: dayWidth, height: 0)
                        .overlay(
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 1)
                                .frame(maxWidth: .infinity)
                                .frame(maxHeight: .infinity, alignment: .bottom)
                        )
                }
            }
        }
        // 最右侧竖线
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 1)
                .frame(maxHeight: .infinity)
                .frame(maxWidth: .infinity, alignment: .trailing)
        )
    }
    
    // 课程时间网格（按节次绘制）
    private var classTimeGridView: some View {
        ZStack(alignment: .topLeading) {
            // 计算日历时间范围（分钟）
            let calendarStartMinutes = settings.calendarStartHour * 60
            let calendarEndMinutes = settings.calendarEndHour * 60
            let minuteHeight = hourHeight / 60.0
            
            // 绘制课程时间块的网格线
            VStack(spacing: 0) {
                ForEach(1..<AppSettings.classTimes.count + 1, id: \.self) { slot in
                    let classTime = AppSettings.classTimes[slot - 1]
                    let startMinutes = classTime.startTimeInMinutes
                    let endMinutes = classTime.endTimeInMinutes
                    
                    // 检查该课时是否在日历范围内
                    if startMinutes >= calendarStartMinutes && startMinutes < calendarEndMinutes {
                        let durationMinutes = endMinutes - startMinutes
                        let blockHeight = CGFloat(durationMinutes) * minuteHeight
                        
                        // 绘制该课时的网格行
                        HStack(spacing: 0) {
                            ForEach(0..<7, id: \.self) { _ in
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(width: dayWidth, height: blockHeight)
                                    .overlay(
                                        ZStack(alignment: .topLeading) {
                                            // 右边界
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.2))
                                                .frame(width: 1)
                                                .frame(maxHeight: .infinity)
                                                .frame(maxWidth: .infinity, alignment: .trailing)
                                            // 下边界
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.2))
                                                .frame(height: 1)
                                                .frame(maxWidth: .infinity)
                                                .frame(maxHeight: .infinity, alignment: .bottom)
                                        }
                                    )
                            }
                        }
                    }
                }
            }
            
            // 处理日历开始时间之前的空白区域网格
            VStack(spacing: 0) {
                let leadingMinutes = (AppSettings.classTimes.first?.startTimeInMinutes ?? 0) - calendarStartMinutes
                if leadingMinutes > 0 {
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: dayWidth, height: CGFloat(leadingMinutes) * minuteHeight)
                                .overlay(
                                    ZStack(alignment: .topLeading) {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.15))
                                            .frame(width: 1)
                                            .frame(maxHeight: .infinity)
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.15))
                                            .frame(height: 1)
                                            .frame(maxWidth: .infinity)
                                            .frame(maxHeight: .infinity, alignment: .bottom)
                                    }
                                )
                        }
                    }
                }
                
                Spacer()
            }
            .frame(height: CGFloat(totalHours) * hourHeight)
            
            // 最右侧竖线
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 1)
                .frame(maxHeight: .infinity)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

// MARK: - 课程块
struct CourseBlock: View {
    let course: Course
    let dayWidth: CGFloat
    let hourHeight: CGFloat
    let settings: AppSettings
    let helpers: ScheduleHelpers
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var showDetailSheet = false
    
    var body: some View {
        let dayIndex = helpers.adjustedDayIndex(for: course.dayOfWeek, weekStartDay: settings.weekStartDay)
        
        // 根据显示模式计算课程块的位置和高度
        let (yOffset, blockHeight) = calculateCoursePositionAndHeight()
        
        let xOffsetRaw = CGFloat(dayIndex) * dayWidth + 1
        let blockWidthRaw = dayWidth - 2
        
        let xOffset = xOffsetRaw.isFinite ? xOffsetRaw : 0
        let blockWidth = max(0, blockWidthRaw.isFinite ? blockWidthRaw : 0)
        
        return VStack(alignment: .leading, spacing: 1) {
            Text(course.name)
                .font(.caption)
                .fontWeight(.semibold)
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0), radius: 1, x: 0, y: 1)
            
            Text(course.location)
                .font(.caption2)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0), radius: 1, x: 0, y: 1)
        }
        .padding(3)
        .frame(width: blockWidth, height: blockHeight, alignment: .topLeading)
        .background(course.uiColor.opacity(settings.courseBlockOpacity))
        .foregroundStyle(course.uiColor.adaptiveTextColor(isDarkMode: colorScheme == .dark))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.1 : 0), lineWidth: 0.5)
        )
        .offset(x: xOffset, y: yOffset)
        .onTapGesture {
            showDetailSheet = true
        }
        .sheet(isPresented: $showDetailSheet) {
            CourseDetailSheet(course: course, settings: settings, helpers: helpers)
                .presentationDetents([.medium, .large])
        }
    }
    
    // MARK: - 位置和高度计算
    
    /// 根据显示模式计算课程块的Y坐标和高度
    private func calculateCoursePositionAndHeight() -> (yOffset: CGFloat, blockHeight: CGFloat) {
        let calendarStartMinutes = settings.calendarStartHour * 60
        let minuteHeight = hourHeight / 60.0
        
        // 计算课程时长(以分钟为单位)
        let durationMinutes = settings.courseDurationInMinutes(startSlot: course.timeSlot, duration: course.duration)
        
        switch settings.timelineDisplayMode {
        case .standardTime:
            // 标准时间模式：直接按照分钟计算
            let startMinutes = settings.timeSlotToMinutes(course.timeSlot)
            let yOffsetRaw = CGFloat(startMinutes - calendarStartMinutes) * minuteHeight + 1
            let blockHeightRaw = CGFloat(durationMinutes) * minuteHeight - 2
            
            let yOffset = yOffsetRaw.isFinite ? yOffsetRaw : 0
            let blockHeight = max(30, blockHeightRaw.isFinite ? blockHeightRaw : 30)
            
            return (yOffset, blockHeight)
            
        case .classTime:
            // 课程时间模式：直接对齐到对应节次的格子
            // 计算课程开始前有多少个节次及其高度之和作为Y偏移
            var yOffsetAccumulated: CGFloat = 0
            var blockHeightAccumulated: CGFloat = 0
            
            let endSlot = min(course.timeSlot + course.duration - 1, AppSettings.classTimes.count)
            
            // 累计开始节次之前的所有节次高度（Y偏移）
            for slot in 1..<course.timeSlot {
                let classTime = AppSettings.classTimes[slot - 1]
                // 只计算在日历范围内的节次
                if classTime.startTimeInMinutes >= calendarStartMinutes && classTime.startTimeInMinutes < (settings.calendarEndHour * 60) {
                    let slotDuration = classTime.durationInMinutes
                    yOffsetAccumulated += CGFloat(slotDuration) * minuteHeight
                }
            }
            
            // 累计课程占用的节次高度（块高度）
            for slot in course.timeSlot...endSlot {
                let classTime = AppSettings.classTimes[slot - 1]
                // 只计算在日历范围内的节次
                if classTime.startTimeInMinutes >= calendarStartMinutes && classTime.startTimeInMinutes < (settings.calendarEndHour * 60) {
                    let slotDuration = classTime.durationInMinutes
                    blockHeightAccumulated += CGFloat(slotDuration) * minuteHeight
                }
            }
            
            let blockHeight = max(30, blockHeightAccumulated - 2)
            let yOffset = yOffsetAccumulated + 1
            
            return (yOffset, blockHeight)
        }
    }
}

// MARK: - 当前时间线
struct CurrentTimeLine: View {
    let dayWidth: CGFloat
    let hourHeight: CGFloat
    let totalWidth: CGFloat
    let settings: AppSettings
    
    private let calendar = Calendar.current
    
    var body: some View {
        // 当时间轴显示方式为课程时间，或者用户关闭了时间线显示时，隐藏当前时间线
        if settings.timelineDisplayMode == .classTime || !settings.showCurrentTimeline {
            Color.clear
        } else {
            GeometryReader { _ in
                let now = Date()
                let isToday = Calendar.current.isDateInToday(now)

                let hour = calendar.component(.hour, from: now)
                let minute = calendar.component(.minute, from: now)
                let second = calendar.component(.second, from: now)
                let inRange = hour >= settings.calendarStartHour && hour < settings.calendarEndHour

                if isToday && inRange {
                    let hoursFromStart = CGFloat(hour - settings.calendarStartHour)
                    let minuteOffset = CGFloat(minute) / 60.0 + CGFloat(second) / 3600.0
                    let yPosition = (hoursFromStart + minuteOffset) * hourHeight

                    HStack(spacing: 0) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)

                        Rectangle()
                            .fill(Color.red)
                            .frame(height: 2)
                    }
                    .frame(width: totalWidth + 8)
                    .offset(x: -4, y: max(0, yPosition - 1))
                    .zIndex(100)
                } else {
                    Color.clear
                }
            }
        }
    }
}

// MARK: - 时间轴
struct TimeAxis: View {
    let timeAxisWidth: CGFloat
    let hourHeight: CGFloat
    let settings: AppSettings
    
    var body: some View {
        if settings.showTimeRuler {
            VStack(spacing: 0) {
                switch settings.timelineDisplayMode {
                case .standardTime:
                    standardTimeAxisView
                case .classTime:
                    classTimeAxisView
                }
            }
        } else {
            Color.clear
                .frame(width: timeAxisWidth)
        }
    }
    
    // 标准时间轴显示（以小时为单位）
    private var standardTimeAxisView: some View {
        VStack(spacing: 0) {
            ForEach(Array(settings.calendarStartHour..<settings.calendarEndHour), id: \.self) { hour in
                Text(String(format: "%02d:00", hour))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: timeAxisWidth, height: hourHeight, alignment: .topTrailing)
                    .padding(.trailing, 4)
            }
        }
    }
    
    // 课程时间轴显示（按节次显示）- 同时显示上课与下课时间
    private var classTimeAxisView: some View {
        VStack(spacing: 0) {
            ForEach(1..<AppSettings.classTimes.count + 1, id: \.self) { slot in
                let classTime = AppSettings.classTimes[slot - 1]
                let startMinutes = classTime.startTimeInMinutes
                let endMinutes = classTime.endTimeInMinutes
                let calendarStartMinutes = settings.calendarStartHour * 60
                let calendarEndMinutes = settings.calendarEndHour * 60
                
                // 检查该课时是否在日历范围内
                if startMinutes >= calendarStartMinutes && startMinutes < calendarEndMinutes {
                    let durationMinutes = endMinutes - startMinutes
                    let minuteHeight = hourHeight / 60.0
                    let blockHeight = CGFloat(durationMinutes) * minuteHeight
                    
                    VStack(spacing: 2) {
                        Text("第\(slot)节")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                        
                        // 上课时间
                        Text(String(format: "%02d:%02d", classTime.startHour, classTime.startMinute))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        
                        // 下课时间（新增）
                        Text(String(format: "%02d:%02d", classTime.endHour, classTime.endMinute))
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(width: timeAxisWidth, height: blockHeight, alignment: .center)
                    .padding(.trailing, 2)
                }
            }
        }
    }
}

// MARK: - 日期选择器弹窗
struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    NSLocalizedString("schedule_component.select_date", comment: ""),
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .frame(minHeight: 400)
                .padding()
                
                Spacer()
            }
            .navigationTitle(NSLocalizedString("schedule_component.select_date", comment: ""))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("schedule_component.done", comment: "")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 课程详情模态窗口
struct CourseDetailSheet: View {
    let course: Course
    let settings: AppSettings
    let helpers: ScheduleHelpers
    
    @Environment(\.dismiss) private var dismiss
    
    private var timeSlotRange: String {
        let startMinutes = settings.timeSlotToMinutes(course.timeSlot)
        let endMinutes = settings.timeSlotEndMinutes(course.timeSlot + course.duration - 1)
        
        let startHour = startMinutes / 60
        let startMin = startMinutes % 60
        let endHour = endMinutes / 60
        let endMin = endMinutes % 60
        
        return String(format: "%02d:%02d - %02d:%02d", startHour, startMin, endHour, endMin)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 课程颜色指示器
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(course.uiColor)
                            .frame(width: 48, height: 48)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(course.name)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(NSLocalizedString("schedule_component.course", comment: ""))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    Divider()
                    
                    // 课程详情
                    VStack(alignment: .leading, spacing: 12) {
                        DetailRow(label: NSLocalizedString("schedule_component.class_time", comment: ""), value: timeSlotRange)
                        DetailRow(label: NSLocalizedString("schedule_component.location", comment: ""), value: course.location)
                        DetailRow(label: NSLocalizedString("schedule_component.teacher", comment: ""), value: course.teacher)
                        DetailRow(label: NSLocalizedString("schedule_component.duration", comment: ""), value: String(format: NSLocalizedString("schedule_component.duration_classes", comment: ""), course.duration))
                        DetailRow(label: NSLocalizedString("schedule_component.weeks", comment: ""), value: course.weeks.isEmpty ? NSLocalizedString("schedule_component.weeks_not_set", comment: "") : formatWeeks(course.weeks))
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle(NSLocalizedString("schedule_component.course_detail", comment: ""))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("schedule_component.done", comment: "")) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatWeeks(_ weeks: [Int]) -> String {
        if weeks.isEmpty {
            return NSLocalizedString("schedule_component.weeks_not_set", comment: "")
        }
        
        // 如果是连续的周，显示范围；否则显示列表
        var result = ""
        var rangeStart = weeks[0]
        var rangeEnd = weeks[0]
        
        for i in 1..<weeks.count {
            if weeks[i] == rangeEnd + 1 {
                rangeEnd = weeks[i]
            } else {
                result += (result.isEmpty ? "" : ", ")
                if rangeStart == rangeEnd {
                    result += String(format: NSLocalizedString("schedule_component.week_format", comment: ""), rangeStart)
                } else {
                    result += String(format: NSLocalizedString("schedule_component.week_range_format", comment: ""), rangeStart, rangeEnd)
                }
                rangeStart = weeks[i]
                rangeEnd = weeks[i]
            }
        }
        
        // 添加最后一段
        result += (result.isEmpty ? "" : ", ")
        if rangeStart == rangeEnd {
            result += String(format: NSLocalizedString("schedule_component.week_format", comment: ""), rangeStart)
        } else {
            result += String(format: NSLocalizedString("schedule_component.week_range_format", comment: ""), rangeStart, rangeEnd)
        }
        
        return result
    }
}

// MARK: - 详情行组件
struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.body)
                .foregroundStyle(.primary)
        }
    }
}

