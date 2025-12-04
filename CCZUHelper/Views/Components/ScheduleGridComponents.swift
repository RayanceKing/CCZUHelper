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
        .background(Color(.systemBackground).opacity(0.95))
    }
}

// MARK: - 网格线
struct ScheduleGridLines: View {
    let dayWidth: CGFloat
    let hourHeight: CGFloat
    let totalHours: Int

    var body: some View {
        // 使用 Grid 绘制 7 列（天） × totalHours 行（小时）
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
}

// MARK: - 课程块
struct CourseBlock: View {
    let course: Course
    let dayWidth: CGFloat
    let hourHeight: CGFloat
    let settings: AppSettings
    let helpers: ScheduleHelpers
    
    var body: some View {
        let dayIndex = helpers.adjustedDayIndex(for: course.dayOfWeek, weekStartDay: settings.weekStartDay)
        
        // 计算开始位置(以分钟为单位)
        let startMinutes = settings.timeSlotToMinutes(course.timeSlot)
        let calendarStartMinutes = settings.calendarStartHour * 60
        let minuteHeight = hourHeight / 60.0
        
        // 计算课程时长(以分钟为单位)
        let durationMinutes = settings.courseDurationInMinutes(startSlot: course.timeSlot, duration: course.duration)
        
        let xOffsetRaw = CGFloat(dayIndex) * dayWidth + 1
        let yOffsetRaw = CGFloat(startMinutes - calendarStartMinutes) * minuteHeight + 1
        let blockHeightRaw = CGFloat(durationMinutes) * minuteHeight - 2
        let blockWidthRaw = dayWidth - 2
        
        let xOffset = xOffsetRaw.isFinite ? xOffsetRaw : 0
        let yOffset = yOffsetRaw.isFinite ? yOffsetRaw : 0
        let blockHeight = max(30, blockHeightRaw.isFinite ? blockHeightRaw : 30)  // 最小高度30，确保内容可见
        let blockWidth = max(0, blockWidthRaw.isFinite ? blockWidthRaw : 0)
        
        return VStack(alignment: .leading, spacing: 1) {
            Text(course.name)
                .font(.caption)
                .fontWeight(.semibold)
            
            Text(course.location)
                .font(.caption2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(3)
        .frame(width: blockWidth, height: blockHeight, alignment: .topLeading)
        .background(course.uiColor.opacity(settings.courseBlockOpacity))
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .offset(x: xOffset, y: yOffset)
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
        GeometryReader { geometry in
            let now = Date()
            
            // 检查是否是今天
            guard calendar.isDateInToday(now) else {
                return AnyView(EmptyView())
            }
            
            let hour = calendar.component(.hour, from: now)
            let minute = calendar.component(.minute, from: now)
            let second = calendar.component(.second, from: now)
            
            // 检查当前时间是否在显示范围内
            guard hour >= settings.calendarStartHour && hour < settings.calendarEndHour else {
                return AnyView(EmptyView())
            }
            
            let hoursFromStart = CGFloat(hour - settings.calendarStartHour)
            let minuteOffset = CGFloat(minute + second / 60) / 60.0
            let yPosition = (hoursFromStart + minuteOffset) * hourHeight
            
            return AnyView(
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
            )
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
                ForEach(Array(settings.calendarStartHour..<settings.calendarEndHour), id: \.self) { hour in
                    Text(String(format: "%02d:00", hour))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: timeAxisWidth, height: hourHeight, alignment: .topTrailing)
                        .padding(.trailing, 4)
                }
            }
        } else {
            Color.clear
                .frame(width: timeAxisWidth)
        }
    }
}

// MARK: - 日期选择器弹窗
struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            DatePicker(
                "选择日期",
                selection: $selectedDate,
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .padding()
            .navigationTitle("选择日期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

