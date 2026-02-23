//
//  ScheduleAndSemesterSettingsSection.swift
//  CCZUHelper
//
//  Created by rayanceking on 2026/2/23.
//

import SwiftUI

/// 课表和学期设置组件
struct ScheduleAndSemesterSettingsSection: View {
    @Environment(AppSettings.self) private var settings
    
    #if os(macOS)
    let onSelectManageSchedules: () -> Void
    let onSelectSemesterSettings: () -> Void
    #else
    let onNavigateToManageSchedules: () -> Void
    #endif
    
    @Binding var showSemesterDatePicker: Bool
    @Binding var showCalendarPermissionError: Bool
    var calendarPermissionError: String?
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }
    
    var body: some View {
        Group {
            // 课表管理
            scheduleManagementSection
            
            // 学期设置
            semesterSettingsSection
        }
    }
    
    private var scheduleManagementSection: some View {
        Section {
            #if os(macOS)
            Button(action: onSelectManageSchedules) {
                Label("settings.manage_schedules".localized, systemImage: "list.bullet")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            #else
            NavigationLink {
                ManageSchedulesView().environment(settings)
            } label: {
                Label("settings.manage_schedules".localized, systemImage: "list.bullet")
            }
            #endif
            
            Toggle(
                isOn: Binding(
                    get: { settings.enableCalendarSync },
                    set: { settings.enableCalendarSync = $0 }
                )
            ) {
                Label("calendar.sync_to_system".localized, systemImage: "calendar")
            }
        } header: {
            Text("settings.schedule_management".localized)
        }
    }
    
    private var semesterSettingsSection: some View {
        Section {
            Button(action: { showSemesterDatePicker = true }) {
                HStack {
                    Label("settings.semester_start".localized, systemImage: "calendar.badge.clock")
                        .foregroundStyle(.blue)
                    Spacer()
                    Text(dateFormatter.string(from: settings.semesterStartDate))
                        .foregroundStyle(.secondary)
                        .font(.body)
                }
            }
            .foregroundStyle(.primary)
            
            Picker(selection: Binding(
                get: { settings.weekStartDay },
                set: { settings.weekStartDay = $0 }
            )) {
                ForEach(AppSettings.WeekStartDay.allCases, id: \.rawValue) { day in
                    Text(day.displayName).tag(day)
                }
            } label: {
                Label("settings.week_start_day".localized, systemImage: "calendar")
            }
        } header: {
            Text("settings.semester_settings".localized)
        } footer: {
            Text("settings.semester_hint".localized)
        }
    }
}

#if os(macOS)
#Preview {
    ScheduleAndSemesterSettingsSection(
        onSelectManageSchedules: {},
        onSelectSemesterSettings: {},
        showSemesterDatePicker: .constant(false),
        showCalendarPermissionError: .constant(false)
    )
    .environment(AppSettings())
}
#else
#Preview {
    ScheduleAndSemesterSettingsSection(
        onNavigateToManageSchedules: {},
        showSemesterDatePicker: .constant(false),
        showCalendarPermissionError: .constant(false)
    )
    .environment(AppSettings())
}
#endif
