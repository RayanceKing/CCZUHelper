//
//  UserSettingsView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/03.
//

import SwiftUI
import UserNotifications
import SwiftData

/// 用户设置视图
struct UserSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    
    @Query private var schedules: [Schedule]
    
    @Binding var showManageSchedules: Bool
    @Binding var showLoginSheet: Bool
    @Binding var showImagePicker: Bool
    
    @State private var showSemesterDatePicker = false
    @State private var showLogoutConfirmation = false
    @State private var showNotificationSettings = false
    @State private var showCalendarPermissionError = false
    @State private var calendarPermissionError: String?
    
    var body: some View {
        NavigationStack {
            List {
                // 用户信息区域
                Section {
                    if settings.isLoggedIn {
                        // 已登录：导航到用户信息页面
                        NavigationLink(destination: UserInfoView().environment(settings)) {
                            HStack {
                                // 显示用户头像或默认图标
                                if let avatarPath = settings.userAvatarPath,
                                   let uiImage = UIImage(contentsOfFile: avatarPath) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 50, height: 50)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(Color.blue, lineWidth: 2)
                                        )
                                } else {
                                    Image(systemName: "person.crop.circle.badge.checkmark")
                                        .font(.system(size: 50))
                                        .foregroundStyle(.blue)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    if let displayName = settings.userDisplayName ?? settings.username {
                                        Text(displayName)
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                        Text("settings.logged_in".localized)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.leading, 8)
                            }
                            .padding(.vertical, 8)
                        }
                    } else {
                        // 未登录：点击跳转到登录页面
                        Button(action: {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showLoginSheet = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.xmark")
                                    .font(.system(size: 50))
                                    .foregroundStyle(.gray)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("settings.not_logged_in".localized)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    Text("settings.login_hint".localized)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.leading, 8)
                                .foregroundStyle(.primary)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
                
                // 课表管理
                Section("settings.schedule_management".localized) {
                    NavigationLink(destination: ManageSchedulesView().environment(settings)) {
                        Label("settings.manage_schedules".localized, systemImage: "list.bullet")
                    }
                    Toggle(
                        isOn: Binding(
                            get: { settings.enableCalendarSync },
                            set: { settings.enableCalendarSync = $0 }
                        )
                    ) {
                        Label("同步课表到系统日历", systemImage: "calendar")
                    }
                }
                
                // 学期设置
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
                
                // 显示设置
                Section("settings.display_settings".localized) {
                    // 日历时间范围
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
                    
                    // 显示选项
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
                    
//                    Toggle(isOn: Binding(
//                        get: { settings.showAllDayEvents },
//                        set: { settings.showAllDayEvents = $0 }
//                    )) {
//                        Label("显示全天日程", systemImage: "calendar.day.timeline.left")
//                    }
                }
                
                // 外观设置
                Section("settings.appearance_settings".localized) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("settings.course_block_opacity".localized, systemImage: "square.fill")
                        
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
                                            
                                            #if os(iOS)
                                            // 当跨越步进点时触发震动
                                            let oldStep = round(oldValue * 10)
                                            let newStep = round(rounded * 10)
                                            if oldStep != newStep {
                                                let impact = UIImpactFeedbackGenerator(style: .light)
                                                impact.impactOccurred()
                                            }
                                            #endif
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
                        Label("settings.background_image".localized, systemImage: "photo")
                    }
                }
                
                // 其他功能
                Section("settings.other".localized) {
                    NavigationLink(destination: NotificationSettingsView().environment(settings)) {
                        Label("settings.notifications".localized, systemImage: "bell")
                    }
                }
                
                // 账号操作
                Section {
                    if settings.isLoggedIn {
                        Button(role: .destructive, action: {
                            showLogoutConfirmation = true
                        }) {
                            HStack {
                                Spacer()
                                Text("settings.logout".localized)
                                Spacer()
                            }
                        }
                        .alert("settings.logout_confirm_title".localized, isPresented: $showLogoutConfirmation) {
                            Button("cancel".localized, role: .cancel) { }
                            Button("settings.logout".localized, role: .destructive) {
                                settings.logout()
                                dismiss()
                            }
                        } message: {
                            Text("settings.logout_confirm_message".localized)
                        }
                    }
                }
            }
            .navigationTitle("settings.title".localized)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("done".localized) {
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
                            Text("settings.select_semester_start".localized)
                        }
                        .datePickerStyle(.graphical)
                        .padding()
                        .frame(maxHeight: .infinity)
                        
                        Spacer(minLength: 0)
                    }
                    .navigationTitle("settings.semester_start".localized)
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("confirm".localized) {
                                showSemesterDatePicker = false
                            }
                        }
                    }
                }
                .presentationDetents([.large])
            }
            .alert("日历权限异常", isPresented: $showCalendarPermissionError) {
                Button("ok".localized, role: .cancel) { }
            } message: {
                Text(calendarPermissionError ?? "请在系统设置中允许访问日历")
            }
        }
        .onChange(of: settings.enableCalendarSync) { _, newValue in
            guard newValue else { return }
            Task {
                do {
                    try await CalendarSyncManager.requestAccess()
                    // 权限获取成功，同步当前课表
                    if let activeSchedule = schedules.first(where: { $0.isActive }) {
                        let scheduleId = activeSchedule.id
                        let descriptor = FetchDescriptor<Course>(predicate: #Predicate { $0.scheduleId == scheduleId })
                        if let courses = try? modelContext.fetch(descriptor) {
                            try await CalendarSyncManager.sync(schedule: activeSchedule, courses: courses, settings: settings)
                        }
                    }
                } catch {
                    await MainActor.run {
                        settings.enableCalendarSync = false
                        calendarPermissionError = error.localizedDescription
                        showCalendarPermissionError = true
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
