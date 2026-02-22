//
//  UserSettingsView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/03.
//

import SwiftUI
import UserNotifications
import SwiftData
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// 用户设置视图
struct UserSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    
    @Query private var schedules: [Schedule]
    
    @Binding var showManageSchedules: Bool
    @Binding var showLoginSheet: Bool
    @Binding var showImagePicker: Bool
    var onDone: (() -> Void)? = nil
    
    @State private var showSemesterDatePicker = false
    @State private var showLogoutConfirmation = false
    @State private var showNotificationSettings = false
    @State private var showCalendarPermissionError = false
    @State private var calendarPermissionError: String?
    
    #if os(macOS)
    @State private var selectedView: MacOSViewType?
    @State private var selectedMacSettingsTab: MacSettingsTab = .account
    
    enum MacOSViewType: Hashable, Identifiable {
        case manageSchedules
        case notifications
        case userInfo
        
        var id: Self { self }
    }

    enum MacSettingsTab: String, CaseIterable, Identifiable {
        case account
        case schedule
        case semester
        case display
        case appearance
        case advanced

        var id: Self { self }

        var title: String {
            switch self {
            case .account: return "services.teaching_system".localized
            case .schedule: return "settings.schedule_management".localized
            case .semester: return "settings.semester_settings".localized
            case .display: return "settings.display_settings".localized
            case .appearance: return "settings.appearance_settings".localized
            case .advanced: return "settings.other".localized
            }
        }

        var icon: String {
            switch self {
            case .account: return "person.crop.circle"
            case .schedule: return "calendar"
            case .semester: return "clock.badge.checkmark"
            case .display: return "rectangle.3.group"
            case .appearance: return "paintbrush"
            case .advanced: return "switch.2"
            }
        }
    }
    #endif
    
    private var defaultUserImage: some View {
        #if os(macOS)
        Image(systemName: "person.crop.circle.badge.checkmark")
            .font(.system(size: 60))
            .foregroundStyle(.blue)
        #else
        Image(systemName: "person.crop.circle.badge.checkmark")
            .font(.system(size: 50))
            .foregroundStyle(.blue)
        #endif
    }
    
    var body: some View {
        Group {
            #if os(macOS)
            NavigationStack {
                VStack(spacing: 0) {
                    macOSTopTabs
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            macOSTabContent
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .background(
                    VisualEffectView(material: .windowBackground, blendingMode: .behindWindow)
                        .ignoresSafeArea()
                )
                .navigationTitle("settings.title".localized)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("common.done".localized) {
                            if let onDone {
                                onDone()
                            } else {
                                dismiss()
                            }
                        }
                    }
                }
                .frame(minWidth: 500, minHeight: 600)
            }
            #else
            NavigationStack {
                List {
                    userInfoSection
                    scheduleManagementSection
                    semesterSettingsSection
                    displaySettingsSection
                    appearanceSettingsSection
                    otherFunctionsSection
                    accountActionsSection
                }
                .navigationTitle("settings.title".localized)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("common.done".localized) {
                            if let onDone {
                                onDone()
                            } else {
                                dismiss()
                            }
                        }
                    }
                }
            }
            #endif
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
        .alert("calendar.permission_error".localized, isPresented: $showCalendarPermissionError) {
            Button("common.ok".localized, role: .cancel) { }
        } message: {
            Text(calendarPermissionError ?? "calendar.permission_denied".localized)
        }
        #if os(macOS)
        .sheet(item: $selectedView) { viewType in
            macOSSheetView(for: viewType)
        }
        #endif
        .onChange(of: settings.enableCalendarSync) { _, newValue in
            Task {
                if newValue {
                    // 启用日历同步
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
                } else {
                    // 关闭日历同步，删除日历中添加的所有日程
                    try await CalendarSyncManager.clearAllEvents()
                }
            }
        }
        .onChange(of: settings.enableICloudDataSync) { _, newValue in
            ICloudSettingsSyncManager.shared.handleToggleChange(enabled: newValue, settings: settings)
        }
    }

    #if os(macOS)
    private var macOSTopTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MacSettingsTab.allCases) { tab in
                    Button {
                        selectedMacSettingsTab = tab
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 18, weight: .semibold))
                            Text(tab.title)
                                .font(.footnote)
                                .lineLimit(1)
                        }
                        .frame(width: 84, height: 64)
                        .foregroundStyle(selectedMacSettingsTab == tab ? Color.accentColor : Color.primary)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selectedMacSettingsTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder
    private var macOSTabContent: some View {
        switch selectedMacSettingsTab {
        case .account:
            macOSAccountTabContent
        case .schedule:
            scheduleManagementSection
        case .semester:
            semesterSettingsSection
        case .display:
            displaySettingsSection
        case .appearance:
            appearanceSettingsSection
        case .advanced:
            otherFunctionsSection
        }
    }

    private var macOSAccountTabContent: some View {
        VStack(spacing: 18) {
            if settings.isLoggedIn {
                macOSLoggedInAccountCard
                    .frame(maxWidth: 560)

                Button(role: .destructive, action: {
                    showLogoutConfirmation = true
                }) {
                    HStack {
                        Spacer()
                        Text("settings.logout".localized)
                        Spacer()
                    }
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: 360)
                .alert("settings.logout_confirm_title".localized, isPresented: $showLogoutConfirmation) {
                    Button("common.cancel".localized, role: .cancel) { }
                    Button("settings.logout".localized, role: .destructive) {
                        settings.logout()
                        #if os(macOS)
                        NSApp.terminate(nil)
                        #else
                        dismiss()
                        #endif
                    }
                } message: {
                    Text("settings.logout_confirm_message".localized)
                }
            } else {
                Button(action: {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showLoginSheet = true
                    }
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.badge.xmark")
                            .font(.system(size: 52))
                            .foregroundStyle(.secondary)
                        Text("settings.not_logged_in".localized)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        Text("settings.login_hint".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 18)
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: 560)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 420, alignment: .center)
        .padding(.vertical, 8)
    }

    private var macOSLoggedInAccountCard: some View {
        VStack(spacing: 16) {
            macOSTeachingAccountHeader

            if let info = cachedTeachingUserInfo {
                InfoCard(title: "user_info.basic".localized) {
                    VStack(spacing: 12) {
                        UserInfoRow(label: "user_info.gender".localized, value: info.gender)
                        Divider()
                        UserInfoRow(label: "user_info.birthday".localized, value: info.birthday)
                        Divider()
                        UserInfoRow(label: "user_info.phone".localized, value: info.phone)
                    }
                }

                InfoCard(title: "user_info.academic".localized) {
                    VStack(spacing: 12) {
                        UserInfoRow(label: "user_info.college".localized, value: info.collegeName)
                        Divider()
                        UserInfoRow(label: "user_info.major".localized, value: info.major)
                        Divider()
                        UserInfoRow(label: "user_info.class".localized, value: info.className)
                        Divider()
                        UserInfoRow(label: "user_info.grade".localized, value: "\(info.grade)")
                        Divider()
                        UserInfoRow(label: "user_info.study_length".localized, value: "\(info.studyLength)年")
                        Divider()
                        UserInfoRow(label: "user_info.status".localized, value: info.studentStatus)
                    }
                }

                InfoCard(title: "user_info.campus_info".localized) {
                    VStack(spacing: 12) {
                        UserInfoRow(label: "user_info.campus".localized, value: info.campus)
                        Divider()
                        UserInfoRow(label: "user_info.dormitory".localized, value: info.dormitoryNumber)
                    }
                }
            } else {
                InfoCard(title: "user_info.title".localized) {
                    VStack(spacing: 10) {
                        UserInfoRow(label: "login.username.placeholder".localized, value: settings.username ?? "-")
                        Divider()
                        UserInfoRow(label: "settings.logged_in".localized, value: "settings.logged_in".localized)
                    }
                }
            }
        }
    }

    private var macOSTeachingAccountHeader: some View {
        HStack(spacing: 14) {
            defaultUserImage

            VStack(alignment: .leading, spacing: 6) {
                Text(cachedTeachingUserInfo?.name ?? settings.userDisplayName ?? settings.username ?? "common.user".localized)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(cachedTeachingUserInfo?.studentNumber ?? settings.username ?? "-")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("services.teaching_system".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private var cachedTeachingUserInfo: UserBasicInfo? {
        let cacheKey = "cachedUserInfo_\(settings.username ?? "anonymous")"
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let info = try? JSONDecoder().decode(UserBasicInfo.self, from: data) else {
            return nil
        }
        return info
    }
    #endif
    
    // MARK: - Section 视图
    
    private var userInfoSection: some View {
        Section {
            if settings.isLoggedIn {
                #if os(macOS)
                Button(action: { selectedView = .userInfo }) {
                    userInfoContent
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor.opacity(0.1))
                )
                #else
                NavigationLink(destination: UserInfoView().environment(settings)) {
                    userInfoContent
                }
                #endif
            } else {
                Button(action: {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showLoginSheet = true
                    }
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.badge.xmark")
                            .font(.system(size: 52))
                            .foregroundStyle(.secondary)
                        Text("settings.not_logged_in".localized)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        Text("settings.login_hint".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.plain)
            }
        }
        #if os(macOS)
        .listRowBackground(Color.clear)
        #endif
    }
    
    private var userInfoContent: some View {
        HStack(spacing: 16) {
            // 显示用户头像或默认图标
            #if os(macOS)
            let avatarSize: CGFloat = 60
            #else
            let avatarSize: CGFloat = 50
            #endif
            
            if let avatarPath = settings.userAvatarPath {
                #if canImport(UIKit)
                if let uiImage = UIImage(contentsOfFile: avatarPath) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: avatarSize, height: avatarSize)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.accentColor, lineWidth: 2.5)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                } else {
                    defaultUserImage
                }
                #else
                if let nsImage = NSImage(contentsOfFile: avatarPath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: avatarSize, height: avatarSize)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.accentColor, lineWidth: 2.5)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                } else {
                    defaultUserImage
                }
                #endif
            } else {
                defaultUserImage
            }
            
            VStack(alignment: .leading, spacing: 6) {
                if let displayName = settings.userDisplayName ?? settings.username {
                    Text(displayName)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("settings.logged_in".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 12)
    }
    
    private var scheduleManagementSection: some View {
        Section {
            #if os(macOS)
            Button(action: { selectedView = .manageSchedules }) {
                Label("settings.manage_schedules".localized, systemImage: "list.bullet")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            #else
            NavigationLink(destination: ManageSchedulesView().environment(settings)) {
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
    
    private var displaySettingsSection: some View {
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

            // 新增：显示当前时间线开关
            Toggle(isOn: Binding(
                get: { settings.showCurrentTimeline },
                set: { settings.showCurrentTimeline = $0 }
            )) {
                Label("settings.show_current_timeline".localized, systemImage: "calendar.day.timeline.left")
                VStack(alignment: .leading) {
                    if settings.timelineDisplayMode == .classTime {
                        Text("settings.show_current_timeline_desc_disabled".localized)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .disabled(settings.timelineDisplayMode == .classTime) // 当时间轴显示方式为课程时间显示时禁用
            
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
    
    private var appearanceSettingsSection: some View {
        Section("settings.appearance_settings".localized) {
            #if canImport(SwiftUI)
            if #available(iOS 26, macOS 26, *) {
                Toggle(isOn: Binding(
                    get: { settings.useLiquidGlass },
                    set: { settings.useLiquidGlass = $0 }
                )) {
                    Text("settings.use_liquid_glass".localized)
                }
            }
            #endif
            
            VStack(alignment: .leading, spacing: 8) {
                Label("settings.course_block_opacity".localized, systemImage: "square.fill")
                if settings.useLiquidGlass {
                    Text("settings.course_block_opacity_disabled_with_glass".localized)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 0) {
                    Text("50%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .leading)
                    
                    GeometryReader { geometry in
                        VStack(spacing: 6) {
                            Slider(value: Binding(
                                get: { settings.courseBlockOpacity },
                                set: { newValue in
                                    let oldValue = settings.courseBlockOpacity
                                    let rounded = round(newValue * 10) / 10
                                    settings.courseBlockOpacity = rounded
                                    
                                    #if os(iOS)
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
                            .disabled(settings.useLiquidGlass)
                            
                            #if !os(visionOS)
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
                            .disabled(settings.useLiquidGlass)
                            #endif
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
                        #if os(macOS)
                        pickBackgroundImageOnMac()
                        #else
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showImagePicker = true
                        }
                        #endif
                    } else {
                        settings.backgroundImagePath = nil
                        settings.backgroundImageEnabled = false
                    }
                }
            )) {
                Label("settings.background_image".localized, systemImage: "photo")
            }
            
            // 新增：背景透明度滑块，仅在背景图片启用时显示
            if settings.backgroundImageEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Label("settings.background_opacity".localized, systemImage: "slider.horizontal.below.circle.righthalf.filled.inverse")
                    
                    HStack(spacing: 0) {
                        Text("0%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .leading)
                        
                        GeometryReader { geometry in
                            VStack(spacing: 6) {
                                Slider(value: Binding(
                                    get: { settings.backgroundOpacity },
                                    set: { newValue in
                                        let oldValue = settings.backgroundOpacity
                                        let rounded = round(newValue * 100) / 100 // 精确到百分位
                                        settings.backgroundOpacity = rounded
                                        
                                        #if os(iOS)
                                        let oldStep = round(oldValue * 10)
                                        let newStep = round(rounded * 10)
                                        if oldStep != newStep {
                                            let impact = UIImpactFeedbackGenerator(style: .light)
                                            impact.impactOccurred()
                                        }
                                        #endif
                                    }
                                ), in: 0.0...1.0, step: 0.01) // 步长改为0.01
                                .padding(10)
                                
                                #if !os(visionOS)
                                // 可选的视觉反馈，类似课程块透明度
                                HStack(spacing: 0) {
                                    ForEach(0..<11, id: \.self) { index in // 0%到100%
                                        let value = Double(index) * 0.1
                                        let isActive = abs(settings.backgroundOpacity - value) < 0.05
                                        
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
                                #endif
                            }
                            .frame(width: geometry.size.width)
                        }
                        .frame(height: 44)
                        
                        Text("100%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                    
                    Text("\(Int(settings.backgroundOpacity * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }

    #if os(macOS)
    private func pickBackgroundImageOnMac() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]

        guard panel.runModal() == .OK, let sourceURL = panel.url else {
            settings.backgroundImageEnabled = false
            return
        }

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileExtension = sourceURL.pathExtension.isEmpty ? "jpg" : sourceURL.pathExtension
        let destinationURL = documentsPath.appendingPathComponent("background_\(timestamp).\(fileExtension)")

        let fileManager = FileManager.default
        if let existingFiles = try? fileManager.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil) {
            for file in existingFiles where file.lastPathComponent.hasPrefix("background_") {
                try? fileManager.removeItem(at: file)
            }
        }

        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            settings.backgroundImagePath = destinationURL.path
            settings.backgroundImageEnabled = true
        } catch {
            settings.backgroundImagePath = nil
            settings.backgroundImageEnabled = false
        }
    }
    #endif
    
    private var otherFunctionsSection: some View {
        Section {
            #if os(macOS)
            Button(action: { selectedView = .notifications }) {
                Label("settings.notifications".localized, systemImage: "bell")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            #else
            NavigationLink(destination: NotificationSettingsView().environment(settings)) {
                Label("settings.notifications".localized, systemImage: "bell")
            }
            #endif

            Toggle(
                isOn: Binding(
                    get: { settings.enableICloudDataSync },
                    set: { settings.enableICloudDataSync = $0 }
                )
            ) {
                Label("settings.icloud_data_sync".localized, systemImage: "icloud")
            }

            Text("settings.icloud_data_sync_hint".localized)
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("settings.other".localized)
        }
    }
    
    private var accountActionsSection: some View {
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
                    Button("common.cancel".localized, role: .cancel) { }
                    Button("settings.logout".localized, role: .destructive) {
                        settings.logout()
                        #if os(macOS)
                        NSApp.terminate(nil)
                        #else
                        dismiss()
                        #endif
                    }
                } message: {
                    Text("settings.logout_confirm_message".localized)
                }
            }
        }
    }
    
    // MARK: - macOS Support
    
    #if os(macOS)
    @ViewBuilder
    private func macOSSheetView(for viewType: MacOSViewType) -> some View {
        switch viewType {
        case .userInfo:
            UserInfoView()
                .environment(settings)
                .frame(minWidth: 500, minHeight: 600)
        case .manageSchedules:
            ManageSchedulesView()
                .environment(settings)
                .frame(minWidth: 600, minHeight: 700)
        case .notifications:
            NotificationSettingsView()
                .environment(settings)
                .frame(minWidth: 500, minHeight: 500)
        }
    }
    #endif
    
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
