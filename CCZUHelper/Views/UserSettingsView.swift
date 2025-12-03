//
//  UserSettingsView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/03.
//

import SwiftUI

/// 用户设置视图
struct UserSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    
    @Binding var showManageSchedules: Bool
    @Binding var showLoginSheet: Bool
    @Binding var showImagePicker: Bool
    
    var body: some View {
        NavigationStack {
            List {
                // 用户信息区域
                Section {
                    HStack {
                        Image(systemName: settings.isLoggedIn ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.xmark")
                            .font(.system(size: 50))
                            .foregroundStyle(settings.isLoggedIn ? .blue : .gray)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            if settings.isLoggedIn, let username = settings.username {
                                Text(username)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                Text("已登录")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("未登录")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                Text("点击登录按钮进行登录")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.leading, 8)
                    }
                    .padding(.vertical, 8)
                }
                
                // 课表管理
                Section("课表管理") {
                    NavigationLink(destination: ManageSchedulesView().environment(settings)) {
                        Label("管理课表", systemImage: "list.bullet")
                    }
                }
                
                // 显示设置
                Section("显示设置") {
                    // 日历时间范围
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
                    
                    // 显示选项
                    Toggle(isOn: Binding(
                        get: { settings.showGridLines },
                        set: { settings.showGridLines = $0 }
                    )) {
                        Label("显示分割线", systemImage: "squareshape.split.3x3")
                    }
                    
                    Toggle(isOn: Binding(
                        get: { settings.showTimeRuler },
                        set: { settings.showTimeRuler = $0 }
                    )) {
                        Label("显示时间标尺", systemImage: "ruler")
                    }
                    
                    Toggle(isOn: Binding(
                        get: { settings.showAllDayEvents },
                        set: { settings.showAllDayEvents = $0 }
                    )) {
                        Label("显示全天日程", systemImage: "calendar.day.timeline.left")
                    }
                }
                
                // 外观设置
                Section("外观设置") {
                    Picker("时间间隔", selection: Binding(
                        get: { settings.timeInterval },
                        set: { settings.timeInterval = $0 }
                    )) {
                        ForEach(AppSettings.TimeInterval.allCases, id: \.rawValue) { interval in
                            Text(interval.displayName).tag(interval)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Label("课程块透明度", systemImage: "square.fill")
                        HStack {
                            Text("50%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Slider(value: Binding(
                                get: { settings.courseBlockOpacity },
                                set: { settings.courseBlockOpacity = $0 }
                            ), in: 0.5...1.0, step: 0.1)
                            Text("100%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(Int(settings.courseBlockOpacity * 100))%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    Toggle(isOn: Binding(
                        get: { settings.backgroundImageEnabled },
                        set: { newValue in
                            settings.backgroundImageEnabled = newValue
                            if newValue {
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    showImagePicker = true
                                }
                            }
                        }
                    )) {
                        Label("开启背景图片", systemImage: "photo")
                    }
                }
                
                // 主题设置
                Section("主题") {
                    Picker("主题模式", selection: Binding(
                        get: { settings.themeMode },
                        set: { settings.themeMode = $0 }
                    )) {
                        ForEach(AppSettings.ThemeMode.allCases, id: \.rawValue) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // 其他功能
                Section("其他") {
                    Button(action: {}) {
                        HStack {
                            Label("通知", systemImage: "bell")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                }
                
                // 账号操作
                Section {
                    if settings.isLoggedIn {
                        Button(role: .destructive, action: {
                            settings.logout()
                            dismiss()
                        }) {
                            HStack {
                                Spacer()
                                Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                                Spacer()
                            }
                        }
                    } else {
                        Button(action: {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showLoginSheet = true
                            }
                        }) {
                            HStack {
                                Spacer()
                                Label("登录", systemImage: "person.circle")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("设置")
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

#Preview {
    UserSettingsView(
        showManageSchedules: .constant(false),
        showLoginSheet: .constant(false),
        showImagePicker: .constant(false)
    )
    .environment(AppSettings())
}
