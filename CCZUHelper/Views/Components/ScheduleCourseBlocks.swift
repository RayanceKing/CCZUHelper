//
//  ScheduleCourseBlocks.swift
//  CCZUHelper
//
//  Split from ScheduleGridComponents.swift
//

import SwiftUI
import SwiftData
import Combine

// MARK: - 重叠布局辅助
struct OverlapInfo {
    let column: Int
    let total: Int
}

func computeOverlapColumns(for courses: [Course], settings: AppSettings) -> [ObjectIdentifier: OverlapInfo] {
    struct Interval {
        let id: ObjectIdentifier
        let course: Course
        let start: Int
        let end: Int
    }

    let intervals: [Interval] = courses.map { c in
        let start = settings.timeSlotToMinutes(c.timeSlot)
        let end = settings.timeSlotEndMinutes(c.timeSlot + c.duration - 1)
        return Interval(id: ObjectIdentifier(c), course: c, start: start, end: end)
    }.sorted { a, b in
        if a.start == b.start { return a.end < b.end }
        return a.start < b.start
    }

    var active: [(end: Int, col: Int, id: ObjectIdentifier)] = []
    var columnAssignment: [ObjectIdentifier: Int] = [:]
    var groups: [[ObjectIdentifier]] = []
    var currentGroup: [ObjectIdentifier] = []

    for iv in intervals {
        active.removeAll { $0.end <= iv.start }
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
    let currentViewWeek: Int
    var overlapColumn: Int = 0
    var totalColumns: Int = 1

    init(course: Course, dayWidth: CGFloat, hourHeight: CGFloat, settings: AppSettings, helpers: ScheduleHelpers, currentViewWeek: Int, overlapColumn: Int = 0, totalColumns: Int = 1) {
        self.course = course
        self.dayWidth = dayWidth
        self.hourHeight = hourHeight
        self.settings = settings
        self.helpers = helpers
        self.currentViewWeek = currentViewWeek
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
        let radius = effectiveCornerRadius
        if #available(iOS 26, macOS 26, *), settings.useLiquidGlass {
            let glassTint: Color = course.uiColor.opacity(min(settings.courseBlockOpacity * 0.5, 0.3))
            #if os(visionOS)
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
                RescheduleCourseSheet(course: course, settings: settings, currentViewWeek: currentViewWeek)
                    .presentationDetents([.medium, .large])
            }
            .offset(x: xOffset, y: yOffset)
    }

    private func calculateCoursePositionAndHeight() -> (yOffset: CGFloat, blockHeight: CGFloat) {
        let calendarStartMinutes = settings.calendarStartHour * 60
        let minuteHeight = hourHeight / 60.0
        let durationMinutes = settings.courseDurationInMinutes(startSlot: course.timeSlot, duration: course.duration)

        switch settings.timelineDisplayMode {
        case .standardTime:
            let startMinutes = settings.timeSlotToMinutes(course.timeSlot)
            let yOffsetRaw = CGFloat(startMinutes - calendarStartMinutes) * minuteHeight + 1
            let blockHeightRaw = CGFloat(durationMinutes) * minuteHeight - 2

            let yOffset = yOffsetRaw.isFinite ? yOffsetRaw : 0
            let blockHeight = max(30, blockHeightRaw.isFinite ? blockHeightRaw : 30)

            return (yOffset, blockHeight)

        case .classTime:
            var yOffsetAccumulated: CGFloat = 0
            var blockHeightAccumulated: CGFloat = 0

            let endSlot = min(course.timeSlot + course.duration - 1, ClassTimeManager.classTimes.count)

            for slot in 1..<course.timeSlot {
                let classTime = ClassTimeManager.classTimes[slot - 1]
                if classTime.startTimeInMinutes >= calendarStartMinutes && classTime.startTimeInMinutes < (settings.calendarEndHour * 60) {
                    let slotDuration = classTime.durationInMinutes
                    yOffsetAccumulated += CGFloat(slotDuration) * minuteHeight
                }
            }

            for slot in course.timeSlot...endSlot {
                let classTime = ClassTimeManager.classTimes[slot - 1]
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
        if settings.timelineDisplayMode == .classTime || !settings.showCurrentTimeline {
            Color.clear
        } else {
            GeometryReader { _ in
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

    private var classTimeAxisView: some View {
        VStack(spacing: 0) {
            ForEach(1..<ClassTimeManager.classTimes.count + 1, id: \.self) { slot in
                let classTime = ClassTimeManager.classTimes[slot - 1]
                let startMinutes = classTime.startTimeInMinutes
                let endMinutes = classTime.endTimeInMinutes
                let calendarStartMinutes = settings.calendarStartHour * 60
                let calendarEndMinutes = settings.calendarEndHour * 60

                if startMinutes >= calendarStartMinutes && startMinutes < calendarEndMinutes {
                    let durationMinutes = endMinutes - startMinutes
                    let minuteHeight = hourHeight / 60.0
                    let blockHeight = CGFloat(durationMinutes) * minuteHeight

                    VStack(spacing: 2) {
                        Text(String(format: "schedule.period_format".localized, slot))
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)

                        Text(String(format: "%02d:%02d", classTime.startHourInt, classTime.startMinute))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)

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
