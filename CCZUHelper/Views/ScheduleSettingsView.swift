//
//  ScheduleSettingsView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/11/30.
//

import SwiftUI
import SwiftData

/// 课程表设置视图
struct ScheduleSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    
    @State private var showManageSchedules = false
    @State private var showImagePicker = false
    
    var body: some View {
        NavigationStack {
            List {
                // 管理课表
                Section {
                    Button(action: { showManageSchedules = true }) {
                        HStack {
                            Label("管理课表", systemImage: "list.bullet")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                } header: {
                    Text("课表管理")
                }
                
                // 时间设置
                Section {
                    Picker("日历开始时间", selection: Binding(
                        get: { settings.calendarStartHour },
                        set: { settings.calendarStartHour = $0 }
                    )) {
                        ForEach(6...12, id: \.self) { hour in
                            Text("\(hour):00").tag(hour)
                        }
                    }
                    
                    Picker("日历结束时间", selection: Binding(
                        get: { settings.calendarEndHour },
                        set: { settings.calendarEndHour = $0 }
                    )) {
                        ForEach(18...23, id: \.self) { hour in
                            Text("\(hour):00").tag(hour)
                        }
                    }
                    
                    Picker("时间间隔", selection: Binding(
                        get: { settings.timeInterval },
                        set: { settings.timeInterval = $0 }
                    )) {
                        ForEach(AppSettings.TimeInterval.allCases, id: \.rawValue) { interval in
                            Text(interval.displayName).tag(interval)
                        }
                    }
                    
                    Picker("每周开始日", selection: Binding(
                        get: { settings.weekStartDay },
                        set: { settings.weekStartDay = $0 }
                    )) {
                        ForEach(AppSettings.WeekStartDay.allCases, id: \.rawValue) { day in
                            Text(day.displayName).tag(day)
                        }
                    }
                } header: {
                    Text("时间设置")
                }
                
                // 显示设置
                Section {
                    Toggle("显示分割线", isOn: Binding(
                        get: { settings.showGridLines },
                        set: { settings.showGridLines = $0 }
                    ))
                    
                    Toggle("显示时间标尺", isOn: Binding(
                        get: { settings.showTimeRuler },
                        set: { settings.showTimeRuler = $0 }
                    ))
                    
                    Toggle("显示全天日程", isOn: Binding(
                        get: { settings.showAllDayEvents },
                        set: { settings.showAllDayEvents = $0 }
                    ))
                } header: {
                    Text("显示设置")
                }
                
                // 外观设置
                Section {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("课程块透明度")
                            Spacer()
                            Text("\(Int(settings.courseBlockOpacity * 100))%")
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: Binding(
                                get: { settings.courseBlockOpacity },
                                set: { settings.courseBlockOpacity = $0 }
                            ),
                            in: 0.3...1.0,
                            step: 0.1
                        )
                    }
                    
                    Toggle("开启背景图片", isOn: Binding(
                        get: { settings.backgroundImageEnabled },
                        set: { newValue in
                            settings.backgroundImageEnabled = newValue
                            if newValue {
                                showImagePicker = true
                            }
                        }
                    ))
                    
                    if settings.backgroundImageEnabled {
                        Button(action: { showImagePicker = true }) {
                            HStack {
                                Text("选择背景图片")
                                Spacer()
                                if settings.backgroundImagePath != nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                } header: {
                    Text("外观设置")
                }
            }
            .navigationTitle("课程表设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showManageSchedules) {
                ManageSchedulesView()
                    .environment(settings)
            }
            #if os(iOS)
            .sheet(isPresented: $showImagePicker) {
                ImagePickerView { url in
                    settings.backgroundImagePath = url?.path
                }
            }
            #endif
        }
    }
}

#Preview {
    ScheduleSettingsView()
        .environment(AppSettings())
}
