//
//  ScheduleGridHeaderAndLines.swift
//  CCZUHelper
//
//  Split from ScheduleGridComponents.swift
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

    private var standardTimeGridView: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            ForEach(0..<totalHours, id: \.self) { _ in
                GridRow {
                    ForEach(0..<7, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: dayWidth, height: hourHeight)
                            .overlay(
                                ZStack(alignment: .topLeading) {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 1)
                                        .frame(maxHeight: .infinity)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
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
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 1)
                .frame(maxHeight: .infinity)
                .frame(maxWidth: .infinity, alignment: .trailing)
        )
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

                        HStack(spacing: 0) {
                            ForEach(0..<7, id: \.self) { _ in
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(width: dayWidth, height: blockHeight)
                                    .overlay(
                                        ZStack(alignment: .topLeading) {
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.2))
                                                .frame(width: 1)
                                                .frame(maxHeight: .infinity)
                                                .frame(maxWidth: .infinity, alignment: .trailing)
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

            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 1)
                .frame(maxHeight: .infinity)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}
