//
//  UserSettingsView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/03.
//

import SwiftUI
import UserNotifications

/// 用户设置视图
struct UserSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    
    @Binding var showManageSchedules: Bool
    @Binding var showLoginSheet: Bool
    @Binding var showImagePicker: Bool
    
    @State private var showSemesterDatePicker = false
    @State private var showLogoutConfirmation = false
    @State private var showNotificationSettings = false
    
    var body: some View {
        NavigationStack {
            List {
                // 用户信息区域
                Section {
                    Button(action: {
                        if !settings.isLoggedIn {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showLoginSheet = true
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: settings.isLoggedIn ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.xmark")
                                .font(.system(size: 50))
                                .foregroundStyle(.blue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                if settings.isLoggedIn, let displayName = settings.userDisplayName ?? settings.username {
                                    Text(displayName)
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
                            .foregroundStyle(.primary)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // 课表管理
                Section("课表管理") {
                    NavigationLink(destination: ManageSchedulesView().environment(settings)) {
                        Label("管理课表", systemImage: "list.bullet")
                    }
                }
                
                // 学期设置
                Section {
                    Button(action: { showSemesterDatePicker = true }) {
                        HStack {
                            Label("开学第一周", systemImage: "calendar.badge.clock")
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
                        Label("每周开始日", systemImage: "calendar")
                    }
                } header: {
                    Text("学期设置")
                } footer: {
                    Text("选择学期第一周的任意一天，系统会自动计算当前为第几周")
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
                    
//                    Toggle(isOn: Binding(
//                        get: { settings.showAllDayEvents },
//                        set: { settings.showAllDayEvents = $0 }
//                    )) {
//                        Label("显示全天日程", systemImage: "calendar.day.timeline.left")
//                    }
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
                        
                        HStack(spacing: 0) {
                            Text("50%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .leading)
                            
                            GeometryReader { geometry in
                                VStack(spacing: 6) {
                                    // 滑块
                                    Slider(value: Binding(
                                        get: { settings.courseBlockOpacity },
                                        set: { newValue in
                                            let oldValue = settings.courseBlockOpacity
                                            // 四舍五入到最近的步进值
                                            let rounded = round(newValue * 10) / 10
                                            settings.courseBlockOpacity = rounded
                                            
                                            // 当跨越步进点时触发震动
                                            let oldStep = round(oldValue * 10)
                                            let newStep = round(rounded * 10)
                                            if oldStep != newStep {
                                                let impact = UIImpactFeedbackGenerator(style: .light)
                                                impact.impactOccurred()
                                            }
                                        }
                                    ), in: 0.5...1.0, step: 0.1)
                                    .padding(10)
                                    // 步进提示点 - 与滑块完全对齐
                                    HStack(spacing: 0) {
                                        ForEach(0..<6, id: \.self) { index in
                                            let value = 0.5 + Double(index) * 0.1
                                            let isActive = abs(settings.courseBlockOpacity - value) < 0.05
                                            
                                            ZStack {
                                                Circle()
                                                    .fill(isActive ? Color.blue : Color.gray.opacity(0.3))
                                                    .frame(width: isActive ? 8 : 6, height: isActive ? 8 : 6)
                                                    .animation(.spring(response: 0.3), value: isActive)
                                            }
                                            .frame(maxWidth: .infinity)
                                        }
                                    }
                                    .padding(.horizontal, 2)
                                }
                                .frame(width: geometry.size.width)
                            }
                            .frame(height: 44)
                            
                            Text("100%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }
                        
                        Text("\(Int(settings.courseBlockOpacity * 100))%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    Toggle(isOn: Binding(
                        get: { settings.backgroundImageEnabled && settings.backgroundImagePath != nil },
                        set: { isOn in
                            if isOn {
                                // 用户想开启，则显示图片选择器
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    showImagePicker = true
                                }
                            } else {
                                // 用户想关闭，则清除路径并禁用
                                settings.backgroundImagePath = nil
                                settings.backgroundImageEnabled = false
                            }
                        }
                    )) {
                        Label("开启背景图片", systemImage: "photo")
                    }
                }
                
                // 其他功能
                Section("其他") {
                    Button(action: {
                        showNotificationSettings = true
                    }) {
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
                            showLogoutConfirmation = true
                        }) {
                            HStack {
                                Spacer()
                                Text("退出登录")
                                Spacer()
                            }
                        }
                        .alert("确认退出登录", isPresented: $showLogoutConfirmation) {
                            Button("取消", role: .cancel) { }
                            Button("退出", role: .destructive) {
                                settings.logout()
                                dismiss()
                            }
                        } message: {
                            Text("退出登录后，您将无法访问个人信息和已登录的功能。")
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
            .sheet(isPresented: $showSemesterDatePicker) {
                NavigationStack {
                    VStack(spacing: 0) {
                        DatePicker(
                            selection: Binding(
                                get: { settings.semesterStartDate },
                                set: { settings.semesterStartDate = $0 }
                            ),
                            displayedComponents: [.date]
                        ) {
                            Text("选择开学第一周")
                        }
                        .datePickerStyle(.graphical)
                        .padding()
                        .frame(maxHeight: .infinity)
                        
                        Spacer(minLength: 0)
                    }
                    .navigationTitle("开学第一周")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("确定") {
                                showSemesterDatePicker = false
                            }
                        }
                    }
                }
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showNotificationSettings) {
                NavigationStack {
                    List {
                        Section("课程通知") {
                            Toggle(isOn: Binding(
                                get: { settings.enableCourseNotification },
                                set: { newValue in
                                    if newValue {
                                        // 用户要开启通知，先请求权限
                                        Task {
                                            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                                            await MainActor.run {
                                                if granted {
                                                    settings.enableCourseNotification = true
                                                }
                                            }
                                        }
                                    } else {
                                        settings.enableCourseNotification = false
                                    }
                                }
                            )) {
                                Label("开启课程通知", systemImage: "bell.fill")
                            }
                            
                            if settings.enableCourseNotification {
                                Picker("提醒时间", selection: Binding(
                                    get: { settings.courseNotificationTime },
                                    set: { settings.courseNotificationTime = $0 }
                                )) {
                                    ForEach(AppSettings.NotificationTime.allCases, id: \.rawValue) { time in
                                        Text(time.displayName).tag(time)
                                    }
                                }
                            }
                        }
                        
                        Section("考试通知") {
                            Toggle(isOn: Binding(
                                get: { settings.enableExamNotification },
                                set: { newValue in
                                    if newValue {
                                        // 用户要开启通知，先请求权限
                                        Task {
                                            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                                            await MainActor.run {
                                                if granted {
                                                    settings.enableExamNotification = true
                                                }
                                            }
                                        }
                                    } else {
                                        settings.enableExamNotification = false
                                    }
                                }
                            )) {
                                Label("开启考试通知", systemImage: "bell.badge.fill")
                            }
                            
                            if settings.enableExamNotification {
                                Picker("提醒时间", selection: Binding(
                                    get: { settings.examNotificationTime },
                                    set: { settings.examNotificationTime = $0 }
                                )) {
                                    ForEach(AppSettings.NotificationTime.allCases, id: \.rawValue) { time in
                                        Text(time.displayName).tag(time)
                                    }
                                }
                            }
                        }
                    }
                    .navigationTitle("通知设置")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") {
                                showNotificationSettings = false
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
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
