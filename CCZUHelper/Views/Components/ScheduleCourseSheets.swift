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

private func resyncCalendarIfEnabled(scheduleId: String, modelContext: ModelContext, settings: AppSettings) {
    guard settings.enableCalendarSync else { return }
    let scheduleDescriptor = FetchDescriptor<Schedule>(predicate: #Predicate { $0.id == scheduleId })
    let courseDescriptor = FetchDescriptor<Course>(predicate: #Predicate { $0.scheduleId == scheduleId })
    guard let schedule = try? modelContext.fetch(scheduleDescriptor).first,
          let courses = try? modelContext.fetch(courseDescriptor) else { return }

    Task {
        try? await CalendarSyncManager.sync(schedule: schedule, courses: courses, settings: settings)
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

// MARK: - 调课共用表单（详情页「仅调整本周」与独立调课弹窗共用）
struct RescheduleCourseForm: View {
    @Binding var toWeek: Int
    @Binding var selectedDayOfWeek: Int
    @Binding var startSlot: Int
    @Binding var endSlot: Int
    @Binding var locationText: String

    var body: some View {
        Section(header: Text(NSLocalizedString("schedule_component.reschedule_to", comment: ""))) {
            Stepper(value: $toWeek, in: 1...RescheduleSupport.maxWeek) {
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
            .onChange(of: startSlot) { _, newValue in
                if endSlot < newValue {
                    endSlot = newValue
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
}

// MARK: - 调课共用逻辑
enum RescheduleSupport {
    /// 保存范围，对应系统日历的「仅此活动 / 此活动及未来所有活动」。
    enum Scope {
        case thisOccurrence
        case thisAndFollowing
    }

    /// 与周次 Stepper 的取值范围保持一致。
    static let maxWeek = 30

    /// 默认操作的周次：优先当前查看周，不在上课周内则取第一个周次。
    static func defaultWeek(for course: Course, currentViewWeek: Int) -> Int {
        let viewWeek = max(1, min(maxWeek, currentViewWeek))
        return course.weeks.contains(viewWeek) ? viewWeek : (course.weeks.first ?? viewWeek)
    }

    /// 本次之后还排了课才需要问范围，只剩一节时直接保存。
    static func hasFollowingOccurrences(course: Course, fromWeek: Int) -> Bool {
        course.weeks.contains { $0 > fromWeek }
    }

    /// 什么都没改就不必写库，也避免把课程自己当成合并目标。
    static func hasChanges(
        course: Course,
        fromWeek: Int,
        toWeek: Int,
        dayOfWeek: Int,
        startSlot: Int,
        endSlot: Int,
        location: String
    ) -> Bool {
        toWeek != fromWeek
            || dayOfWeek != course.dayOfWeek
            || startSlot != course.timeSlot
            || endSlot != course.timeSlot + course.duration - 1
            || location != course.location
    }

    static func apply(
        course: Course,
        modelContext: ModelContext,
        settings: AppSettings,
        fromWeek: Int,
        toWeek: Int,
        dayOfWeek: Int,
        startSlot: Int,
        endSlot: Int,
        location: String,
        scope: Scope
    ) {
        let newDuration = max(1, endSlot - startSlot + 1)
        let scheduleId = course.scheduleId

        guard course.weeks.contains(fromWeek) else { return }

        // 「及后续」沿用系统日历的语义：把本周的位移量套到之后每一次上课。
        let movedWeeks: [Int]
        switch scope {
        case .thisOccurrence:
            movedWeeks = [fromWeek]
        case .thisAndFollowing:
            movedWeeks = course.weeks.filter { $0 >= fromWeek }
        }

        let weekDelta = toWeek - fromWeek
        let targetWeeks = movedWeeks
            .map { $0 + weekDelta }
            .filter { (1...maxWeek).contains($0) }
            .sorted()
        guard !targetWeeks.isEmpty else { return }

        // 合并目标要在改动原课程之前找，否则删空后的课程会被当成候选。
        let mergeTarget = existingCourse(
            modelContext: modelContext,
            course: course,
            location: location,
            dayOfWeek: dayOfWeek,
            startSlot: startSlot,
            duration: newDuration
        )

        let movedSet = Set(movedWeeks)
        let remainingWeeks = course.weeks.filter { !movedSet.contains($0) }
        if remainingWeeks.isEmpty {
            modelContext.delete(course)
        } else {
            course.weeks = remainingWeeks
        }

        if let mergeTarget {
            // 调回原位或与同名同时段的课重合时并周次，避免叠出两个同样的课程块。
            mergeTarget.weeks = Array(Set(mergeTarget.weeks).union(targetWeeks)).sorted()
        } else {
            let newCourse = Course(
                name: course.name,
                teacher: course.teacher,
                location: location,
                weeks: targetWeeks,
                dayOfWeek: dayOfWeek,
                timeSlot: startSlot,
                duration: newDuration,
                color: course.color,
                scheduleId: scheduleId
            )
            modelContext.insert(newCourse)
        }

        try? modelContext.save()
        resyncCalendarIfEnabled(scheduleId: scheduleId, modelContext: modelContext, settings: settings)
    }

    /// 同课表里名称、教师、地点、星期与节次都相同的另一门课。
    static func existingCourse(
        modelContext: ModelContext,
        course: Course,
        location: String,
        dayOfWeek: Int,
        startSlot: Int,
        duration: Int
    ) -> Course? {
        let scheduleId = course.scheduleId
        let descriptor = FetchDescriptor<Course>(predicate: #Predicate<Course> { $0.scheduleId == scheduleId })
        guard let candidates = try? modelContext.fetch(descriptor) else { return nil }
        return candidates.first { candidate in
            candidate !== course
                && candidate.name == course.name
                && candidate.teacher == course.teacher
                && candidate.location == location
                && candidate.dayOfWeek == dayOfWeek
                && candidate.timeSlot == startSlot
                && candidate.duration == duration
        }
    }
}

// MARK: - 课程详情模态窗口

struct CourseDetailSheet: View {
    let course: Course
    let settings: AppSettings
    let helpers: ScheduleHelpers
    let currentViewWeek: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// 顶部模式切换，默认停在「编辑课程信息」。
    private enum DetailMode: Hashable {
        case adjustWeek
        case editInfo
    }

    @State private var mode: DetailMode = .editInfo

    // MARK: 编辑课程信息

    @State private var selectedCourseColor: Color
    @State private var editedDayOfWeek: Int
    @State private var editedTimeSlot: Int
    @State private var editedDuration: Int
    @State private var editedLocation: String
    @State private var editedTeacher: String
    @State private var editedNote: String
    @State private var editedWeeks: [Int]
    @State private var showSaveConfirmation = false

    // MARK: 仅调整本周（调课）

    @State private var fromWeek: Int
    @State private var toWeek: Int
    @State private var adjustDayOfWeek: Int
    @State private var adjustStartSlot: Int
    @State private var adjustEndSlot: Int
    @State private var adjustLocation: String
    @State private var showRescheduleScopeDialog = false

    @State private var showDeleteConfirmation = false

    init(course: Course, settings: AppSettings, helpers: ScheduleHelpers, currentViewWeek: Int) {
        self.course = course
        self.settings = settings
        self.helpers = helpers
        self.currentViewWeek = currentViewWeek
        _selectedCourseColor = State(initialValue: course.uiColor)
        _editedDayOfWeek = State(initialValue: course.dayOfWeek)
        _editedTimeSlot = State(initialValue: course.timeSlot)
        _editedDuration = State(initialValue: course.duration)
        _editedLocation = State(initialValue: course.location)
        _editedTeacher = State(initialValue: course.teacher)
        _editedNote = State(initialValue: course.note)
        _editedWeeks = State(initialValue: course.weeks.sorted())

        let defaultWeek = RescheduleSupport.defaultWeek(for: course, currentViewWeek: currentViewWeek)
        _fromWeek = State(initialValue: defaultWeek)
        _toWeek = State(initialValue: defaultWeek)
        _adjustDayOfWeek = State(initialValue: course.dayOfWeek)
        _adjustStartSlot = State(initialValue: max(1, min(12, course.timeSlot)))
        _adjustEndSlot = State(initialValue: max(1, min(12, course.timeSlot + course.duration - 1)))
        _adjustLocation = State(initialValue: course.location)
    }

    private var timeSlotRange: String {
        let startMinutes = settings.timeSlotToMinutes(editedTimeSlot)
        let endMinutes = settings.timeSlotEndMinutes(editedTimeSlot + editedDuration - 1)

        let startHour = startMinutes / 60
        let startMin = startMinutes % 60
        let endHour = endMinutes / 60
        let endMin = endMinutes % 60

        return String(format: "%02d:%02d - %02d:%02d", startHour, startMin, endHour, endMin)
    }

    private var maxDuration: Int {
        max(1, 12 - editedTimeSlot + 1)
    }

    /// 周次是课程级属性（不是某一次课的属性），单独判断以便保存时不做周次拆分。
    private var weeksChanged: Bool {
        Set(editedWeeks) != Set(course.weeks)
    }

    private var isModified: Bool {
        editedDayOfWeek != course.dayOfWeek
        || editedTimeSlot != course.timeSlot
        || editedDuration != course.duration
        || editedLocation != course.location
        || editedTeacher != course.teacher
        || editedNote != course.note
        || weeksChanged
    }

    /// 本周之后还有同课程的课次时才需要二选一，只剩本周这一节就直接保存。
    private var adjustHasFollowingOccurrences: Bool {
        RescheduleSupport.hasFollowingOccurrences(course: course, fromWeek: fromWeek)
    }

    private var adjustHasChanges: Bool {
        RescheduleSupport.hasChanges(
            course: course,
            fromWeek: fromWeek,
            toWeek: toWeek,
            dayOfWeek: adjustDayOfWeek,
            startSlot: adjustStartSlot,
            endSlot: adjustEndSlot,
            location: adjustLocation
        )
    }

    @ViewBuilder
    private var editInfoContent: some View {
        Section {
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
        }
        Section(header: Text(NSLocalizedString("schedule_component.class_time", comment: ""))) {
            Picker(NSLocalizedString("schedule_component.day_of_week", comment: ""), selection: $editedDayOfWeek) {
                Text(NSLocalizedString("weekday.monday", comment: "")).tag(1)
                Text(NSLocalizedString("weekday.tuesday", comment: "")).tag(2)
                Text(NSLocalizedString("weekday.wednesday", comment: "")).tag(3)
                Text(NSLocalizedString("weekday.thursday", comment: "")).tag(4)
                Text(NSLocalizedString("weekday.friday", comment: "")).tag(5)
                Text(NSLocalizedString("weekday.saturday", comment: "")).tag(6)
                Text(NSLocalizedString("weekday.sunday", comment: "")).tag(7)
            }

            Picker(NSLocalizedString("schedule_component.start_slot", comment: ""), selection: $editedTimeSlot) {
                ForEach(1...12, id: \.self) { slot in
                    Text("\(slot)").tag(slot)
                }
            }
            .onChange(of: editedTimeSlot) { _, newValue in
                if editedDuration > maxDuration {
                    editedDuration = maxDuration
                }
                if newValue < 1 {
                    editedTimeSlot = 1
                }
            }

            Text(String(format: NSLocalizedString("schedule_component.duration_classes", comment: ""), editedDuration))
                .font(.body)
                .foregroundStyle(.secondary)

            Text(timeSlotRange)
                .font(.body)
                .foregroundStyle(.secondary)
        }

        Section(header: Text(NSLocalizedString("schedule_component.location", comment: ""))) {
            TextField(NSLocalizedString("schedule_component.location_placeholder", comment: ""), text: $editedLocation)
                #if os(iOS) || os(tvOS) || os(visionOS)
                .textInputAutocapitalization(.never)
                #endif
                .disableAutocorrection(true)
        }

        Section(header: Text(NSLocalizedString("schedule_component.teacher", comment: ""))) {
            TextField(NSLocalizedString("schedule_component.teacher", comment: ""), text: $editedTeacher)
                #if os(iOS) || os(tvOS) || os(visionOS)
                .textInputAutocapitalization(.never)
                #endif
                .disableAutocorrection(true)
        }

        Section(header: Text(NSLocalizedString("schedule_component.note", comment: ""))) {
            TextField(
                NSLocalizedString("schedule_component.note_placeholder", comment: ""),
                text: $editedNote,
                axis: .vertical
            )
            .lineLimit(3...8)
        }

        Section {
            NavigationLink {
                WeekSelectionView(selection: $editedWeeks)
            } label: {
                HStack {
                    Text(NSLocalizedString("schedule_component.weeks_effective_title", comment: ""))
                    Spacer()
                    Text(editedWeeks.isEmpty ? NSLocalizedString("schedule_component.weeks_not_set", comment: "") : formatWeeks(editedWeeks))
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(NSLocalizedString("schedule_component.weeks", comment: ""))
        } footer: {
            if editedWeeks.isEmpty {
                Text(NSLocalizedString("schedule_component.weeks_empty_hint", comment: ""))
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("", selection: $mode) {
                        Text(NSLocalizedString("schedule_component.detail_mode_adjust_week", comment: ""))
                            .tag(DetailMode.adjustWeek)
                        Text(NSLocalizedString("schedule_component.detail_mode_edit_info", comment: ""))
                            .tag(DetailMode.editInfo)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))

                switch mode {
                case .adjustWeek:
                    RescheduleCourseForm(
                        toWeek: $toWeek,
                        selectedDayOfWeek: $adjustDayOfWeek,
                        startSlot: $adjustStartSlot,
                        endSlot: $adjustEndSlot,
                        locationText: $adjustLocation
                    )
                case .editInfo:
                    editInfoContent
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text(NSLocalizedString("schedule_component.delete_course", comment: ""))
                            Spacer()
                        }
                    }
                } footer: {
                    Text(NSLocalizedString("schedule_component.delete_whole_course_hint", comment: ""))
                }
            }
            .navigationTitle(NSLocalizedString("schedule_component.course_detail", comment: ""))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                if mode == .adjustWeek {
                    ToolbarItem(placement: .cancellationAction) {
                        if #available(iOS 26.0, macOS 26.0, visionOS 2, *) {
                            Button(role: .cancel) { dismiss() }
                        } else {
                            Button(NSLocalizedString("common.cancel", comment: "")) { dismiss() }
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if #available(iOS 26.0, macOS 26.0, visionOS 2, *) {
                        Button(role: .confirm) { confirmTapped() }
                            .disabled(mode == .adjustWeek && adjustEndSlot < adjustStartSlot)
                    } else {
                        Button(NSLocalizedString("common.done", comment: "")) { confirmTapped() }
                            .disabled(mode == .adjustWeek && adjustEndSlot < adjustStartSlot)
                    }
                }
            }
            .alert(NSLocalizedString("schedule_component.edit_confirm_title", comment: ""), isPresented: $showSaveConfirmation) {
                Button(NSLocalizedString("schedule_component.edit_current_only", comment: "")) {
                    applyChangesToCurrentOccurrence()
                    dismiss()
                }
                Button(NSLocalizedString("schedule_component.edit_following_courses", comment: "")) {
                    applyChangesToFollowingOccurrences()
                    dismiss()
                }
                Button(NSLocalizedString("common.cancel", comment: ""), role: .cancel) { }
            }
            .confirmationDialog(
                NSLocalizedString("schedule_component.reschedule_scope_title", comment: ""),
                isPresented: $showRescheduleScopeDialog,
                titleVisibility: .visible
            ) {
                Button(NSLocalizedString("schedule_component.reschedule_scope_this", comment: "")) {
                    applyReschedule(scope: .thisOccurrence)
                }
                Button(NSLocalizedString("schedule_component.reschedule_scope_following", comment: "")) {
                    applyReschedule(scope: .thisAndFollowing)
                }
                Button(NSLocalizedString("common.cancel", comment: ""), role: .cancel) {}
            }
            .alert(NSLocalizedString("schedule_component.delete_confirm_title", comment: ""), isPresented: $showDeleteConfirmation) {
                Button(NSLocalizedString("common.delete", comment: ""), role: .destructive) {
                    deleteCourse()
                }
                Button(NSLocalizedString("common.cancel", comment: ""), role: .cancel) {}
            } message: {
                Text(NSLocalizedString("schedule_component.delete_confirm_message", comment: ""))
            }
        }
    }

    private func confirmTapped() {
        switch mode {
        case .adjustWeek:
            confirmReschedule()
        case .editInfo:
            guard isModified else {
                dismiss()
                return
            }
            // 周次改动是课程级的，按周拆分没有意义，直接作用于整门课。
            if weeksChanged {
                applyChangesToCourse(course)
                dismiss()
            } else {
                showSaveConfirmation = true
            }
        }
    }

    private func confirmReschedule() {
        guard adjustHasChanges else {
            dismiss()
            return
        }
        if adjustHasFollowingOccurrences {
            showRescheduleScopeDialog = true
        } else {
            applyReschedule(scope: .thisOccurrence)
        }
    }

    private func applyReschedule(scope: RescheduleSupport.Scope) {
        RescheduleSupport.apply(
            course: course,
            modelContext: modelContext,
            settings: settings,
            fromWeek: fromWeek,
            toWeek: toWeek,
            dayOfWeek: adjustDayOfWeek,
            startSlot: adjustStartSlot,
            endSlot: adjustEndSlot,
            location: adjustLocation,
            scope: scope
        )
        dismiss()
    }

    private func deleteCourse() {
        let scheduleId = course.scheduleId
        modelContext.delete(course)
        try? modelContext.save()
        resyncCalendarIfEnabled(scheduleId: scheduleId, modelContext: modelContext, settings: settings)
        dismiss()
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

    /// - Parameter resyncCalendar: 批量修改时传 false，由调用方在最后统一同步一次。
    private func applyChangesToCourse(_ target: Course, resyncCalendar: Bool = true) {
        target.dayOfWeek = editedDayOfWeek
        target.timeSlot = editedTimeSlot
        target.duration = editedDuration
        target.location = editedLocation
        target.teacher = editedTeacher
        target.note = editedNote
        target.weeks = editedWeeks.sorted()
        try? modelContext.save()
        if resyncCalendar {
            resyncCalendarIfEnabled(scheduleId: target.scheduleId, modelContext: modelContext, settings: settings)
        }
    }

    private func applyChangesToCurrentOccurrence() {
        let targetWeek = currentViewWeek

        // 周次被改过就不再拆分，否则编辑结果会被两段周次切碎。
        guard !weeksChanged else {
            applyChangesToCourse(course)
            return
        }

        guard course.weeks.contains(targetWeek) else {
            applyChangesToCourse(course)
            return
        }

        if course.weeks.count == 1 {
            applyChangesToCourse(course)
            return
        }

        let remainingWeeks = course.weeks.filter { $0 != targetWeek }.sorted()
        guard !remainingWeeks.isEmpty else {
            applyChangesToCourse(course)
            return
        }

        course.weeks = remainingWeeks

        let detachedCourse = Course(
            name: course.name,
            teacher: editedTeacher,
            location: editedLocation,
            note: editedNote,
            weeks: [targetWeek],
            dayOfWeek: editedDayOfWeek,
            timeSlot: editedTimeSlot,
            duration: editedDuration,
            color: course.color,
            scheduleId: course.scheduleId
        )

        modelContext.insert(detachedCourse)
        try? modelContext.save()
        resyncCalendarIfEnabled(scheduleId: course.scheduleId, modelContext: modelContext, settings: settings)
    }

    /// 本周及之后的课次拆成新课程，之前的保持原样，对应系统日历的「此活动及未来所有活动」。
    /// 只作用于当前这一条课程记录：同名但排在别的星期的课属于另一组重复，本周更早上过的也不动。
    private func applyChangesToFollowingOccurrences() {
        let targetWeek = currentViewWeek

        // 同上：周次被改过就没必要按周次切分。
        guard !weeksChanged else {
            applyChangesToCourse(course)
            return
        }

        let followingWeeks = course.weeks.filter { $0 >= targetWeek }.sorted()
        let earlierWeeks = course.weeks.filter { $0 < targetWeek }.sorted()

        // 本周之前没有排过课时就等同于整门课都改，不必拆出一份重复的课程。
        guard !followingWeeks.isEmpty, !earlierWeeks.isEmpty else {
            applyChangesToCourse(course)
            return
        }

        course.weeks = earlierWeeks

        let detachedCourse = Course(
            name: course.name,
            teacher: editedTeacher,
            location: editedLocation,
            note: editedNote,
            weeks: followingWeeks,
            dayOfWeek: editedDayOfWeek,
            timeSlot: editedTimeSlot,
            duration: editedDuration,
            color: course.color,
            scheduleId: course.scheduleId
        )

        modelContext.insert(detachedCourse)
        try? modelContext.save()
        resyncCalendarIfEnabled(scheduleId: course.scheduleId, modelContext: modelContext, settings: settings)
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

    @State private var showScopeDialog = false

    let course: Course
    let settings: AppSettings
    let currentViewWeek: Int

    /// 本次之后还排了课才需要问范围，只剩一节时直接保存。
    private var hasFollowingOccurrences: Bool {
        RescheduleSupport.hasFollowingOccurrences(course: course, fromWeek: fromWeek)
    }

    /// 什么都没改就不必写库，也避免把课程自己当成合并目标。
    private var hasChanges: Bool {
        RescheduleSupport.hasChanges(
            course: course,
            fromWeek: fromWeek,
            toWeek: toWeek,
            dayOfWeek: selectedDayOfWeek,
            startSlot: startSlot,
            endSlot: endSlot,
            location: locationText
        )
    }

    init(course: Course, settings: AppSettings, currentViewWeek: Int) {
        self.course = course
        self.settings = settings
        self.currentViewWeek = currentViewWeek

        let defaultWeek = RescheduleSupport.defaultWeek(for: course, currentViewWeek: currentViewWeek)
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
                RescheduleCourseForm(
                    toWeek: $toWeek,
                    selectedDayOfWeek: $selectedDayOfWeek,
                    startSlot: $startSlot,
                    endSlot: $endSlot,
                    locationText: $locationText
                )
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
                        Button(role: .confirm) { confirmSave() }
                            .disabled(endSlot < startSlot)
                    } else {
                        Button(NSLocalizedString("confirm", comment: "")) { confirmSave() }
                            .disabled(endSlot < startSlot)
                    }
                }
            }
            .confirmationDialog(
                NSLocalizedString("schedule_component.reschedule_scope_title", comment: ""),
                isPresented: $showScopeDialog,
                titleVisibility: .visible
            ) {
                Button(NSLocalizedString("schedule_component.reschedule_scope_this", comment: "")) {
                    applyChanges(scope: .thisOccurrence)
                    dismiss()
                }
                Button(NSLocalizedString("schedule_component.reschedule_scope_following", comment: "")) {
                    applyChanges(scope: .thisAndFollowing)
                    dismiss()
                }
                Button(NSLocalizedString("common.cancel", comment: ""), role: .cancel) {}
            }
        }
    }

    private func confirmSave() {
        guard hasChanges else {
            dismiss()
            return
        }
        if hasFollowingOccurrences {
            showScopeDialog = true
        } else {
            applyChanges(scope: .thisOccurrence)
            dismiss()
        }
    }

    private func applyChanges(scope: RescheduleSupport.Scope) {
        RescheduleSupport.apply(
            course: course,
            modelContext: modelContext,
            settings: settings,
            fromWeek: fromWeek,
            toWeek: toWeek,
            dayOfWeek: selectedDayOfWeek,
            startSlot: startSlot,
            endSlot: endSlot,
            location: locationText,
            scope: scope
        )
    }
}
