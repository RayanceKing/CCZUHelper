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
                    Button("common.done".localized) {
                        if let onDone { onDone() } else { dismiss() }
                    }
                }
            }
        }
    }
    #endif
    
    // MARK: - macOS View
    
    #if os(macOS)
    private var macOSView: some View {
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
                Divider()
                HStack(spacing: 10) {
                    Spacer()
                    Button("common.cancel".localized) {
                        closeSettings()
                    }
                    .buttonStyle(.bordered)

                    Button("common.ok".localized) {
                        closeSettings()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .navigationTitle(selectedMacSettingsTab.title)
            .frame(minWidth: 500, minHeight: 600)
        }
    }

    private var macOSTopTabs: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                ForEach(MacSettingsTab.allCases) { tab in
                    Button {
                        selectedMacSettingsTab = tab
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 18, weight: .semibold))
                            Text(tab.title)
                                .font(.caption2)
                        }
                        .frame(width: 94, height: 62)
                        .foregroundStyle(selectedMacSettingsTab == tab ? Color.accentColor : Color.primary.opacity(0.85))
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedMacSettingsTab == tab ? Color.primary.opacity(0.22) : Color.clear, lineWidth: 1)
                                )
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .frame(width: 94, height: 62)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            //.padding(.bottom, 8)
            Divider()
        }
        .background(
            Color(nsColor: .controlBackgroundColor)
                .opacity(0.65)
        )
    }

    private func closeSettings() {
        if let onDone {
            onDone()
        } else {
            dismiss()
        }
    }

    @ViewBuilder
    private var macOSTabContent: some View {
        switch selectedMacSettingsTab {
        case .schedule:
            ScheduleAndSemesterSettingsSection(
                onSelectManageSchedules: { selectedView = .manageSchedules },
                onSelectSemesterSettings: {},
                showSemesterDatePicker: $showSemesterDatePicker,
                showCalendarPermissionError: $showCalendarPermissionError,
                calendarPermissionError: calendarPermissionError
            )
        case .display:
            DisplaySettingsSection()
        case .appearance:
            AppearanceSettingsSection(showImagePicker: $showImagePicker)
        case .advanced:
            OtherSettingsSections(
                onSelectNotifications: { selectedView = .notifications },
                onShowMembershipPurchase: { showMembershipPurchaseSheet = true },
                showLogoutConfirmation: $showLogoutConfirmation
            )
        }
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
                    Button("confirm".localized) {
                        showSemesterDatePicker = false
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
                try await CalendarSyncManager.clearAllEvents()
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

