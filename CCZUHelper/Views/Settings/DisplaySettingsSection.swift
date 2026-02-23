//
//  DisplaySettingsSection.swift
//  CCZUHelper
//
//  Created by rayanceking on 2026/2/23.
//

import SwiftUI

/// 显示设置部分组件
struct DisplaySettingsSection: View {
    @Environment(AppSettings.self) private var settings
    
    var body: some View {
        Section("settings.display_settings".localized) {
            Picker("settings.calendar_start_time".localized, selection: Binding(
                get: { settings.calendarStartHour },
                set: { settings.calendarStartHour = $0 }
            )) {
                ForEach(6...12, id: \.self) { hour in
                    Text("\(hour):00").tag(hour)
                }
            }
            
            Picker("settings.calendar_end_time".localized, selection: Binding(
                get: { settings.calendarEndHour },
                set: { settings.calendarEndHour = $0 }
            )) {
                ForEach(18...23, id: \.self) { hour in
                    Text("\(hour):00").tag(hour)
                }
            }
            
            Toggle(isOn: Binding(
                get: { settings.showGridLines },
                set: { settings.showGridLines = $0 }
            )) {
                Label("settings.show_grid_lines".localized, systemImage: "squareshape.split.3x3")
            }
            
            Toggle(isOn: Binding(
                get: { settings.showTimeRuler },
                set: { settings.showTimeRuler = $0 }
            )) {
                Label("settings.show_time_ruler".localized, systemImage: "ruler")
            }

            Toggle(isOn: Binding(
                get: { settings.showCurrentTimeline },
                set: { settings.showCurrentTimeline = $0 }
            )) {
                Label("settings.show_current_timeline".localized, systemImage: "calendar.day.timeline.left")
            }
            .disabled(settings.timelineDisplayMode == .classTime)
            
            if settings.timelineDisplayMode == .classTime {
                VStack(alignment: .leading) {
                    Text("settings.show_current_timeline_desc_disabled".localized)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Picker(selection: Binding(
                get: { settings.timelineDisplayMode },
                set: { settings.timelineDisplayMode = $0 }
            )) {
                ForEach(AppSettings.TimelineDisplayMode.allCases, id: \.rawValue) { mode in
                    Text(mode.displayName).tag(mode)
                }
            } label: {
                Label("settings.timeline_display_mode".localized, systemImage: "timeline.selection")
            }
        }
    }
}

#Preview {
    DisplaySettingsSection()
        .environment(AppSettings())
}
