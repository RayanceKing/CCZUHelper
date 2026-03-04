//
//  ScheduleCourseSheets.swift
//  CCZUHelper
//
//  Split from ScheduleGridComponents.swift
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

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
                    if #available(iOS 26.0, macOS 26.0, visionOS 2, *) {
                        Button(role: .confirm) {
                            dismiss()
                        }
                    } else {
                        Button(NSLocalizedString("common.done", comment: "")) {
                            dismiss()
                        }
                    }
                }
            }
        }
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
                    if #available(iOS 26.0, macOS 26.0, visionOS 2, *) {
                        Button(role: .confirm) {
                            dismiss()
                        }
                    } else {
                        Button(NSLocalizedString("common.done", comment: "")) {
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    private func formatWeeks(_ weeks: [Int]) -> String {
        if weeks.isEmpty {
            return NSLocalizedString("schedule_component.weeks_not_set", comment: "")
        }

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

// MARK: - 调课弹窗
struct RescheduleCourseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var fromWeek: Int
    @State private var toWeek: Int
    @State private var selectedDayOfWeek: Int

    @State private var startSlot: Int
    @State private var endSlot: Int
    @State private var locationText: String

    let course: Course
    let settings: AppSettings
    let currentViewWeek: Int

    init(course: Course, settings: AppSettings, currentViewWeek: Int) {
        self.course = course
        self.settings = settings
        self.currentViewWeek = currentViewWeek

        let viewWeek = max(1, min(30, currentViewWeek))
        let defaultWeek = course.weeks.contains(viewWeek) ? viewWeek : (course.weeks.first ?? viewWeek)
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
                    if #available(iOS 26.0, macOS 26.0, visionOS 2, *) {
                        Button(role: .cancel) { dismiss() }
                    } else {
                        Button(NSLocalizedString("common.cancel", comment: "")) { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if #available(iOS 26.0, macOS 26.0, visionOS 2, *) {
                        Button(role: .confirm) {
                            applyChanges()
                            dismiss()
                        }
                        .disabled(endSlot < startSlot)
                    } else {
                        Button(NSLocalizedString("confirm", comment: "")) {
                            applyChanges()
                            dismiss()
                        }
                        .disabled(endSlot < startSlot)
                    }
                }
            }
        }
    }

    private func applyChanges() {
        let newDuration = max(1, endSlot - startSlot + 1)

        guard course.weeks.contains(fromWeek) else {
            return
        }

        let remainingWeeks = course.weeks.filter { $0 != fromWeek }
        if remainingWeeks.isEmpty {
            modelContext.delete(course)
        } else {
            course.weeks = remainingWeeks
        }

        let newCourse = Course(
            name: course.name,
            teacher: course.teacher,
            location: locationText,
            weeks: [toWeek],
            dayOfWeek: selectedDayOfWeek,
            timeSlot: startSlot,
            duration: newDuration,
            color: course.color,
            scheduleId: course.scheduleId
        )

        modelContext.insert(newCourse)
        try? modelContext.save()
    }
}
