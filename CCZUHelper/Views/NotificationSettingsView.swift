//
//  NotificationSettingsView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/5.
//

import SwiftUI
import UserNotifications

/// 通知设置视图
struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    
    var body: some View {
        List {
            Section("settings.course_notification".localized) {
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
                    Label("settings.enable_course_notification".localized, systemImage: "bell.fill")
                }
                
                if settings.enableCourseNotification {
                    Picker("settings.notification_time".localized, selection: Binding(
                        get: { settings.courseNotificationTime },
                        set: { settings.courseNotificationTime = $0 }
                    )) {
                        ForEach(AppSettings.NotificationTime.allCases, id: \.rawValue) { time in
                            Text(time.displayName).tag(time)
                        }
                    }
                }
            }
            
            Section("settings.exam_notification".localized) {
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
                    Label("settings.enable_exam_notification".localized, systemImage: "bell.badge.fill")
                }
                
                if settings.enableExamNotification {
                    Picker("settings.notification_time".localized, selection: Binding(
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
        .navigationTitle("settings.notification_settings".localized)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
            .environment(AppSettings())
    }
}
