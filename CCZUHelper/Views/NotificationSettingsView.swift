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
        .onChange(of: settings.enableCourseNotification) { oldValue, newValue in
            handleCourseNotificationToggle(newValue)
        }
        .onChange(of: settings.courseNotificationTime) { oldValue, newValue in
            handleCourseNotificationTimeChange()
        }
        .onChange(of: settings.enableExamNotification) { oldValue, newValue in
            handleExamNotificationToggle(newValue)
        }
        .onChange(of: settings.examNotificationTime) { oldValue, newValue in
            handleExamNotificationTimeChange()
        }
    }
    
    // MARK: - 通知处理方法
    
    private func handleCourseNotificationToggle(_ enabled: Bool) {
        Task {
            if !enabled {
                await NotificationHelper.removeAllCourseNotifications()
            }
        }
    }
    
    private func handleCourseNotificationTimeChange() {
        // 课程通知会在 ScheduleView 中自动重新安排
    }
    
    private func handleExamNotificationToggle(_ enabled: Bool) {
        Task {
            if !enabled {
                await NotificationHelper.removeAllExamNotifications()
            }
        }
    }
    
    private func handleExamNotificationTimeChange() {
        // 考试通知时间改变时，需要重新从缓存加载考试数据并重新安排通知
        Task {
            if settings.enableExamNotification,
               let username = settings.username,
               let cachedData = UserDefaults.standard.data(forKey: "cachedExams_\(username)") {
                // 解码为通用数组以避免类型依赖
                if let exams = try? JSONDecoder().decode([ExamItemForNotification].self, from: cachedData) {
                    await NotificationHelper.scheduleAllExamNotifications(
                        exams: exams,
                        settings: settings
                    )
                }
            }
        }
    }
}

// MARK: - 用于通知的临时考试模型
private struct ExamItemForNotification: Codable {
    let courseName: String
    let examTime: String?
    let examLocation: String?
    let id: UUID
    
    enum CodingKeys: String, CodingKey {
        case courseName, examTime, examLocation
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.courseName = try container.decode(String.self, forKey: .courseName)
        self.examTime = try container.decodeIfPresent(String.self, forKey: .examTime)
        self.examLocation = try container.decodeIfPresent(String.self, forKey: .examLocation)
        self.id = UUID()
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
            .environment(AppSettings())
    }
}
