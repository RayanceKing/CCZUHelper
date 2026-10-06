//
//  ScheduleGridHeaderAndLines.swift
//  CCZUHelper
//
//  Split from ScheduleGridComponents.swift
//

import SwiftUI

// MARK: - 星期标题行
struct WeekdayHeader: View {
    @Environment(\.colorScheme) private var colorScheme

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
            if settings.showTimeRuler {
                Color.clear
                    .frame(width: timeAxisWidth, height: headerHeight)
            }

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
            : (colorScheme == .dark ? Color(uiColor: .black) : Color(.systemBackground).opacity(0.95))
        )
        #endif
    }
}

// MARK: - 网格线
struct ScheduleGridLines: View {
    let dayWidth: CGFloat
    let hourHeight: CGFloat
    let totalHours: Int
    /// 底部额外补绘的一行高度（0 表示不补绘）
    var extraRowHeight: CGFloat = 0
    let settings: AppSettings

    var body: some View {
        switch settings.timelineDisplayMode {
        case .standardTime:
            standardTimeGridView
        case .classTime:
            classTimeGridView
        }
    }

    /// 单个网格单元：右侧竖线 + 可选的底部横线
    private func gridCell(height: CGFloat, showsBottomLine: Bool = true) -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: dayWidth, height: height)
            .overlay(
                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    if showsBottomLine {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 1)
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                }
            )
    }

    /// 一整行网格（7 列）
    private func gridRow(height: CGFloat, showsBottomLine: Bool = true) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { _ in
                gridCell(height: height, showsBottomLine: showsBottomLine)
            }
        }
    }

    /// 最右侧收口竖线
    private var trailingBorder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(width: 1)
            .frame(maxHeight: .infinity)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var standardTimeGridView: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            ForEach(0..<totalHours, id: \.self) { _ in
                GridRow {
                    ForEach(0..<7, id: \.self) { _ in
                        gridCell(height: hourHeight)
                    }
                }
            }
            // 底部额外补绘一行：只延伸竖线，不画横线
            GridRow {
                ForEach(0..<7, id: \.self) { _ in
                    gridCell(height: extraRowHeight, showsBottomLine: false)
                }
            }
        }
        .overlay(trailingBorder)
    }

    private var classTimeGridView: some View {
        ZStack(alignment: .topLeading) {
            let calendarStartMinutes = settings.calendarStartHour * 60
            let calendarEndMinutes = settings.calendarEndHour * 60
            let minuteHeight = hourHeight / 60.0

            VStack(spacing: 0) {
                ForEach(1..<ClassTimeManager.classTimes.count + 1, id: \.self) { slot in
                    let classTime = ClassTimeManager.classTimes[slot - 1]
                    let startMinutes = classTime.startTimeInMinutes
                    let endMinutes = classTime.endTimeInMinutes

                    if startMinutes >= calendarStartMinutes && startMinutes < calendarEndMinutes {
                        let durationMinutes = endMinutes - startMinutes
                        let blockHeight = CGFloat(durationMinutes) * minuteHeight

                        gridRow(height: blockHeight)
                    }
                }

                // 底部额外补绘一行：只延伸竖线，不画横线
                gridRow(height: extraRowHeight, showsBottomLine: false)
            }

            trailingBorder
        }
    }
}
