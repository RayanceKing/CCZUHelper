//
//  ScheduleGridComponents.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/03.
//

import SwiftUI
import SwiftData
import Combine
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

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
        let effectiveAxisWidth = settings.showTimeRuler ? timeAxisWidth : 0
        let rawDayWidth = (width - effectiveAxisWidth) / 7
        let dayWidth = max(0, rawDayWidth.isFinite ? rawDayWidth : 0)
        
        return HStack(spacing: 0) {
            // 左上角空白（仅当显示时间标尺时）
            if settings.showTimeRuler {
                Color.clear
                    .frame(width: timeAxisWidth, height: headerHeight)
            }
            
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
        .background(
            settings.backgroundImageEnabled
            ? Color.clear
            : Color(nsColor: .controlBackgroundColor).opacity(0.95)
        )
        #else
        .background(
            settings.backgroundImageEnabled
            ? Color.clear
            : Color(.systemBackground).opacity(0.95)
        )
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
                ForEach(1..<ClassTimeManager.classTimes.count + 1, id: \.self) { slot in
                    let classTime = ClassTimeManager.classTimes[slot - 1]
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
                let leadingMinutes = (ClassTimeManager.classTimes.first?.startTimeInMinutes ?? 0) - calendarStartMinutes
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

// MARK: - 重叠布局辅助
struct OverlapInfo {
    let column: Int
    let total: Int
}

/// 根据课程在同一天的时间区间，计算并列显示的列索引与总列数
/// - Parameter courses: 同一天的课程数组
/// - Returns: 以 Course 的 ObjectIdentifier 为键的 OverlapInfo 映射
func computeOverlapColumns(for courses: [Course], settings: AppSettings) -> [ObjectIdentifier: OverlapInfo] {
    struct Interval {
        let id: ObjectIdentifier
        let course: Course
        let start: Int
        let end: Int
    }
    // 将课程转换为时间区间（分钟）
    let intervals: [Interval] = courses.map { c in
        let start = settings.timeSlotToMinutes(c.timeSlot)
        let end = settings.timeSlotEndMinutes(c.timeSlot + c.duration - 1)
        return Interval(id: ObjectIdentifier(c), course: c, start: start, end: end)
    }.sorted { a, b in
        if a.start == b.start { return a.end < b.end }
        return a.start < b.start
    }

    // 扫描线分配列索引
    var active: [(end: Int, col: Int, id: ObjectIdentifier)] = []
    var columnAssignment: [ObjectIdentifier: Int] = [:]
    var groups: [[ObjectIdentifier]] = []
    var currentGroup: [ObjectIdentifier] = []

    for iv in intervals {
        // 移除已结束的课程
        active.removeAll { $0.end <= iv.start }
        // 找到最小可用列
        let used = Set(active.map { $0.col })
        var col = 0
        while used.contains(col) { col += 1 }
        columnAssignment[iv.id] = col
        active.append((end: iv.end, col: col, id: iv.id))

        if active.count == 1 {
            if !currentGroup.isEmpty { groups.append(currentGroup) }
            currentGroup = [iv.id]
        } else {
            currentGroup.append(iv.id)
        }
    }
    if !currentGroup.isEmpty { groups.append(currentGroup) }

    // 生成结果：每个组的总列数为该组内最大列索引+1
    var result: [ObjectIdentifier: OverlapInfo] = [:]
    for group in groups {
        let maxCol = group.compactMap { columnAssignment[$0] }.max() ?? 0
        let total = maxCol + 1
        for id in group {
            if let col = columnAssignment[id] {
                result[id] = OverlapInfo(column: col, total: total)
            }
        }
    }
    return result
}

// MARK: - 课程块
struct CourseBlock: View {
    let course: Course
    let dayWidth: CGFloat
    let hourHeight: CGFloat
    let settings: AppSettings
    let helpers: ScheduleHelpers
    // 新增：并列显示信息（默认单列）
    var overlapColumn: Int = 0
    var totalColumns: Int = 1

    init(course: Course, dayWidth: CGFloat, hourHeight: CGFloat, settings: AppSettings, helpers: ScheduleHelpers, overlapColumn: Int = 0, totalColumns: Int = 1) {
        self.course = course
        self.dayWidth = dayWidth
        self.hourHeight = hourHeight
        self.settings = settings
        self.helpers = helpers
        self.overlapColumn = overlapColumn
        self.totalColumns = totalColumns
    }
    
    private var effectiveCornerRadius: CGFloat {
        if #available(iOS 26, macOS 26, *) {
            return 8.0
        } else {
            return 4.0
        }
    }
    
    @ViewBuilder
    private var courseBackground: some View {
        // Base shape keeps a non-empty background during highlight/compositing
        let radius = effectiveCornerRadius
        if #available(iOS 26, macOS 26, *), settings.useLiquidGlass {
            let glassTint: Color = course.uiColor.opacity(min(settings.courseBlockOpacity * 0.5, 0.3))
            #if os(visionOS)
            // visionOS does not support .glassEffect; use a tinted fill fallback
            ZStack {
                RoundedRectangle(cornerRadius: radius).fill(Color.clear)
                RoundedRectangle(cornerRadius: radius)
                    .fill(course.uiColor.opacity(settings.courseBlockOpacity))
            }
            #else
            ZStack {
                RoundedRectangle(cornerRadius: radius)
                    .fill(Color.clear)
                RoundedRectangle(cornerRadius: radius)
                    .fill(Color.clear)
                    .glassEffect(.clear.tint(glassTint).interactive(), in: .rect(cornerRadius: radius))
            }
            #endif
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: radius)
                    .fill(Color.clear)
                RoundedRectangle(cornerRadius: radius)
                    .fill(course.uiColor.opacity(settings.courseBlockOpacity))
            }
        }
    }
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var showDetailSheet = false
    @Environment(\.modelContext) private var modelContext
    @State private var showRescheduleSheet = false
    @State private var showDeleteAlert = false
    
    @ViewBuilder
    private var courseContent: some View {
        let textShadowColor = Color.black.opacity(colorScheme == .dark ? 0.3 : 0)
        VStack(alignment: .leading, spacing: 1) {
            Text(course.name)
                .font(.caption)
                .fontWeight(.semibold)
                .shadow(color: textShadowColor, radius: 1, x: 0, y: 1)
            Text(course.location)
                .font(.caption2)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: textShadowColor, radius: 1, x: 0, y: 1)
        }
    }
    
    private var strokeOverlay: some View {
        let cornerRadius = effectiveCornerRadius
        return RoundedRectangle(cornerRadius: cornerRadius)
            .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.1 : 0), lineWidth: 0.5)
    }
    
    var body: some View {
        let dayIndex = helpers.adjustedDayIndex(for: course.dayOfWeek, weekStartDay: settings.weekStartDay)
        
        // 根据显示模式计算课程块的位置和高度
        let (yOffset, blockHeight) = calculateCoursePositionAndHeight()
        
        let totalCols = max(totalColumns, 1)
        let columnWidth = (dayWidth - 2) / CGFloat(totalCols)
        let innerPad: CGFloat = 4
        let blockWidthRaw = max(0, columnWidth - innerPad)
        let xOffsetRaw = CGFloat(dayIndex) * dayWidth + 1 + CGFloat(overlapColumn) * columnWidth + innerPad / 2
        
        let xOffset = xOffsetRaw.isFinite ? xOffsetRaw : 0
        let blockWidth = blockWidthRaw.isFinite ? blockWidthRaw : 0
        
        let textStyleColor = course.uiColor.adaptiveTextColor(isDarkMode: colorScheme == .dark)
        
        return courseContent
            .padding(3)
            .frame(width: blockWidth, height: blockHeight, alignment: .topLeading)
            .background(courseBackground)
            .contentShape(RoundedRectangle(cornerRadius: effectiveCornerRadius))
            .foregroundStyle(textStyleColor)
            .clipShape(RoundedRectangle(cornerRadius: effectiveCornerRadius))
            .overlay(strokeOverlay)
            .compositingGroup()
            .allowsHitTesting(true)
            .onTapGesture {
                showDetailSheet = true
            }
            .contextMenu {
                Button {
                    showRescheduleSheet = true
                } label: {
                    Label(NSLocalizedString("schedule_component.reschedule", comment: ""), systemImage: "arrow.triangle.2.circlepath")
                }
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Label(NSLocalizedString("common.delete", comment: ""), systemImage: "trash")
                }
            }
            .alert(NSLocalizedString("schedule_component.delete_confirm_title", comment: ""), isPresented: $showDeleteAlert) {
                Button(NSLocalizedString("common.delete", comment: ""), role: .destructive) {
                    modelContext.delete(course)
                    try? modelContext.save()
                }
                Button(NSLocalizedString("common.cancel", comment: ""), role: .cancel) {}
            } message: {
                Text(NSLocalizedString("schedule_component.delete_confirm_message", comment: ""))
            }
            .sheet(isPresented: $showDetailSheet) {
                CourseDetailSheet(course: course, settings: settings, helpers: helpers)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showRescheduleSheet) {
                RescheduleCourseSheet(course: course, settings: settings)
                    .presentationDetents([.medium, .large])
            }
            .offset(x: xOffset, y: yOffset)
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
            
            let endSlot = min(course.timeSlot + course.duration - 1, ClassTimeManager.classTimes.count)
            
            // 累计开始节次之前的所有节次高度（Y偏移）
            for slot in 1..<course.timeSlot {
                let classTime = ClassTimeManager.classTimes[slot - 1]
                // 只计算在日历范围内的节次
                if classTime.startTimeInMinutes >= calendarStartMinutes && classTime.startTimeInMinutes < (settings.calendarEndHour * 60) {
                    let slotDuration = classTime.durationInMinutes
                    yOffsetAccumulated += CGFloat(slotDuration) * minuteHeight
                }
            }
            
            // 累计课程占用的节次高度（块高度）
            for slot in course.timeSlot...endSlot {
                let classTime = ClassTimeManager.classTimes[slot - 1]
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
    
    @State private var now: Date = Date()
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    private let calendar = Calendar.current
    
    var body: some View {
        // 当时间轴显示方式为课程时间，或者用户关闭了时间线显示时，隐藏当前时间线
        if settings.timelineDisplayMode == .classTime || !settings.showCurrentTimeline {
            Color.clear
        } else {
            GeometryReader { _ in
                // use state-driven current time
                let now = self.now
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
                    .offset(x: -4, y: max(0, yPosition - 5))
                    .zIndex(100)
                } else {
                    Color.clear
                }
            }
            .onReceive(timer) { date in
                self.now = date
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
            ForEach(1..<ClassTimeManager.classTimes.count + 1, id: \.self) { slot in
                let classTime = ClassTimeManager.classTimes[slot - 1]
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
                        Text(String(format: "schedule.period_format".localized, slot))
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                        
                        // 上课时间
                        Text(String(format: "%02d:%02d", classTime.startHourInt, classTime.startMinute))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        
                        // 下课时间（新增）
                        Text(String(format: "%02d:%02d", classTime.endHourInt, classTime.endMinute))
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
                    Button(NSLocalizedString("common.done", comment: "")) {
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
    @Environment(\.modelContext) private var modelContext
    @State private var selectedCourseColor: Color

    init(course: Course, settings: AppSettings, helpers: ScheduleHelpers) {
        self.course = course
        self.settings = settings
        self.helpers = helpers
        _selectedCourseColor = State(initialValue: course.uiColor)
    }
    
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
                        ColorPicker("", selection: $selectedCourseColor, supportsOpacity: false)
                            .labelsHidden()
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .onChange(of: selectedCourseColor) { _, newColor in
                                updateCourseColor(newColor)
                            }
                        
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
                    Button(NSLocalizedString("common.done", comment: "")) {
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

    private func updateCourseColor(_ color: Color) {
        guard let colorHex = color.hexRGBString() else { return }
        guard course.color != colorHex else { return }
        course.color = colorHex
        do {
            try modelContext.save()
        } catch {
            // ignore save error to avoid breaking detail view interaction
        }
    }
}

#if canImport(UIKit)
private extension Color {
    func hexRGBString() -> String? {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }

        let r = Int(round(red * 255))
        let g = Int(round(green * 255))
        let b = Int(round(blue * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
#elseif canImport(AppKit)
private extension Color {
    func hexRGBString() -> String? {
        let nsColor = NSColor(self)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else { return nil }
        let r = Int(round(rgbColor.redComponent * 255))
        let g = Int(round(rgbColor.greenComponent * 255))
        let b = Int(round(rgbColor.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
#endif

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

// MARK: - 调课弹窗
struct RescheduleCourseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // 源周与目标周
    @State private var fromWeek: Int
    @State private var toWeek: Int

    // 选择周几（1-7：周一到周日）
    @State private var selectedDayOfWeek: Int

    @State private var startSlot: Int
    @State private var endSlot: Int
    @State private var locationText: String

    let course: Course
    let settings: AppSettings

    init(course: Course, settings: AppSettings) {
        self.course = course
        self.settings = settings

        let defaultWeek = course.weeks.first ?? 1
        _fromWeek = State(initialValue: defaultWeek)
        _toWeek = State(initialValue: defaultWeek)
        _selectedDayOfWeek = State(initialValue: course.dayOfWeek)

        _startSlot = State(initialValue: max(1, min(12, course.timeSlot)))
        _endSlot = State(initialValue: max(1, min(12, course.timeSlot + course.duration - 1)))
        _locationText = State(initialValue: course.location)
    }

    var body: some View {
        NavigationStack {
            Form {
                // 目标周与周几、节次
                Section(header: Text(NSLocalizedString("schedule_component.reschedule_to", comment: ""))) {
                    Stepper(value: $toWeek, in: 1...30) {
                        Text(String(format: NSLocalizedString("schedule_component.week_format", comment: ""), toWeek))
                    }

                    Picker(NSLocalizedString("schedule_component.day_of_week", comment: ""), selection: $selectedDayOfWeek) {
                        Text(NSLocalizedString("weekday.monday", comment: "")).tag(1)
                        Text(NSLocalizedString("weekday.tuesday", comment: "")).tag(2)
                        Text(NSLocalizedString("weekday.wednesday", comment: "")).tag(3)
                        Text(NSLocalizedString("weekday.thursday", comment: "")).tag(4)
                        Text(NSLocalizedString("weekday.friday", comment: "")).tag(5)
                        Text(NSLocalizedString("weekday.saturday", comment: "")).tag(6)
                        Text(NSLocalizedString("weekday.sunday", comment: "")).tag(7)
                    }

                    Picker(NSLocalizedString("schedule_component.start_slot", comment: ""), selection: $startSlot) {
                        ForEach(1...12, id: \.self) { i in
                            Text("\(i)").tag(i)
                        }
                    }
                    Picker(NSLocalizedString("schedule_component.end_slot", comment: ""), selection: $endSlot) {
                        ForEach(startSlot...12, id: \.self) { i in
                            Text("\(i)").tag(i)
                        }
                    }
                }

                Section(header: Text(NSLocalizedString("schedule_component.location", comment: ""))) {
                    TextField(NSLocalizedString("schedule_component.location_placeholder", comment: ""), text: $locationText)
                        #if os(iOS) || os(tvOS) || os(visionOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .disableAutocorrection(true)
                }
            }
            .navigationTitle(NSLocalizedString("schedule_component.reschedule", comment: ""))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("common.cancel", comment: "")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("confirm", comment: "")) {
                        applyChanges()
                        dismiss()
                    }
                    .disabled(endSlot < startSlot)
                }
            }
        }
    }

    // 仅对某个周次生效的调课：从原课程移除 fromWeek，创建一条仅在 toWeek 的新课程，支持改周几
    private func applyChanges() {
        let newDuration = max(1, endSlot - startSlot + 1)

        // 1) 只有当源周存在于原课程时才进行调整
        guard course.weeks.contains(fromWeek) else {
            return
        }

        // 2) 从原课程中移除源周
        let remainingWeeks = course.weeks.filter { $0 != fromWeek }
        if remainingWeeks.isEmpty {
            // 若移除后没有周次，删除原课程
            modelContext.delete(course)
        } else {
            course.weeks = remainingWeeks
        }

        // 3) 创建新课程，仅在目标周，并使用新的时间、地点、周几
        let newCourse = Course(
            name: course.name,
            teacher: course.teacher,
            location: locationText,
            weeks: [toWeek],
            dayOfWeek: selectedDayOfWeek,   // 使用用户选择的周几
            timeSlot: startSlot,
            duration: newDuration,
            color: course.color,
            scheduleId: course.scheduleId
        )

        modelContext.insert(newCourse)
        try? modelContext.save()
    }
}
