//
//  UserSettingsView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/03.
//

import SwiftUI
import UserNotifications
import SwiftData

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// 用户设置视图 - 经过优化的精简版本
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
    @State private var showMembershipPurchaseSheet = false
    @State private var showLogoutConfirmation = false
    @State private var showCalendarPermissionError = false
    @State private var calendarPermissionError: String?
    
    #if os(macOS)
    @State private var selectedView: MacOSViewType?
    @State private var selectedMacSettingsTab: MacSettingsTab = .schedule
    
    enum MacOSViewType: Hashable, Identifiable {
        case manageSchedules
        case notifications
        case userInfo
        
        var id: Self { self }
    }

    enum MacSettingsTab: String, CaseIterable, Identifiable {
        case schedule
        case display
        case appearance
        case advanced

        var id: Self { self }

        var title: String {
            switch self {
            case .schedule: return "settings.schedule_management".localized
            case .display: return "settings.display_settings".localized
            case .appearance: return "settings.appearance_settings".localized
            case .advanced: return "settings.other".localized
            }
        }

        var icon: String {
            switch self {
            case .schedule: return "calendar"
            case .display: return "rectangle.3.group"
            case .appearance: return "paintbrush"
            case .advanced: return "switch.2"
            }
        }
    }
    #endif
    
    var body: some View {
        Group {
            #if os(macOS)
            macOSView
            #else
            iOSView
            #endif
        }
        .sheet(isPresented: $showSemesterDatePicker) {
            semesterDatePickerSheet
        }
        .sheet(isPresented: $showMembershipPurchaseSheet) {
            MembershipPurchaseView()
                .environment(settings)
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
            handleCalendarSyncToggle(newValue)
        }
        .onChange(of: settings.enableICloudDataSync) { _, newValue in
            ICloudSettingsSyncManager.shared.handleToggleChange(enabled: newValue, settings: settings)
        }
    }
    
    // MARK: - iOS View
    
    #if !os(macOS)
    private var iOSView: some View {
        NavigationStack {
            List {
                UserInfoHeaderCard(
                    showLoginSheet: $showLoginSheet,
                    onNavigateToUserInfo: {}
                )
                
                ScheduleAndSemesterSettingsSection(
                    onNavigateToManageSchedules: {},
                    showSemesterDatePicker: $showSemesterDatePicker,
                    showCalendarPermissionError: $showCalendarPermissionError,
                    calendarPermissionError: calendarPermissionError
                )
                
                DisplaySettingsSection()
                AppearanceSettingsSection(showImagePicker: $showImagePicker)
                
                OtherSettingsSections(
                    onNavigateToNotifications: {},
                    onShowMembershipPurchase: { showMembershipPurchaseSheet = true },
                    showLogoutConfirmation: $showLogoutConfirmation
                )
            }
            .navigationTitle("settings.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    if #available(iOS 26.0, macOS 26.0, visionOS 2, *) {
                        Button(role: .confirm) {
                            if let onDone { onDone() } else { dismiss() }
                        }
                    } else {
                        Button("common.done".localized) {
                            if let onDone { onDone() } else { dismiss() }
                        }
                    }
                }
            }
        }
    }
    #endif
    
    // MARK: - macOS View
    
    #if os(macOS)
    private var macOSView: some View {
        TabView(selection: $selectedMacSettingsTab) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScheduleAndSemesterSettingsSection(
                        onSelectManageSchedules: { selectedView = .manageSchedules },
                        onSelectSemesterSettings: {},
                        showSemesterDatePicker: $showSemesterDatePicker,
                        showCalendarPermissionError: $showCalendarPermissionError,
                        calendarPermissionError: calendarPermissionError
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .tag(MacSettingsTab.schedule)
            .tabItem {
                Label(MacSettingsTab.schedule.title, systemImage: MacSettingsTab.schedule.icon)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    DisplaySettingsSection()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .tag(MacSettingsTab.display)
            .tabItem {
                Label(MacSettingsTab.display.title, systemImage: MacSettingsTab.display.icon)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    AppearanceSettingsSection(showImagePicker: $showImagePicker)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .tag(MacSettingsTab.appearance)
            .tabItem {
                Label(MacSettingsTab.appearance.title, systemImage: MacSettingsTab.appearance.icon)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    OtherSettingsSections(
                        onSelectNotifications: { selectedView = .notifications },
                        onShowMembershipPurchase: { showMembershipPurchaseSheet = true },
                        showLogoutConfirmation: $showLogoutConfirmation
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .tag(MacSettingsTab.advanced)
            .tabItem {
                Label(MacSettingsTab.advanced.title, systemImage: MacSettingsTab.advanced.icon)
            }
        }
        .padding(12)
        .frame(minWidth: 500, minHeight: 600)
    }

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
    
    // MARK: - Sheets & Modals
    
    private var semesterDatePickerSheet: some View {
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
                    if #available(iOS 26.0, macOS 26.0, visionOS 2, *) {
                        Button(role: .confirm) {
                            showSemesterDatePicker = false
                        }
                    } else {
                        Button("confirm".localized) {
                            showSemesterDatePicker = false
                        }
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
    
    // MARK: - Private Methods
    
    private func handleCalendarSyncToggle(_ newValue: Bool) {
        Task {
            if newValue {
                do {
                    try await CalendarSyncManager.requestAccess()
                    if let activeSchedule = schedules.first(where: { $0.isActive }) {
                        let scheduleId = activeSchedule.id
                        let descriptor = FetchDescriptor<Course>(
                            predicate: #Predicate { $0.scheduleId == scheduleId }
                        )
                        let courses = try modelContext.fetch(descriptor)
                        try await CalendarSyncManager.sync(schedule: activeSchedule, courses: courses, settings: settings)
                    }
                } catch {
                    await MainActor.run {
                        calendarPermissionError = error.localizedDescription
                        showCalendarPermissionError = true
                    }
                }
            } else {
                await CalendarSyncManager.disableSyncAndClear()
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

