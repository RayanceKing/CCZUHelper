//
//  CCZUHelperApp.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/11/30.
//

import SwiftUI
import SwiftData
import CCZUKit
import WidgetKit

#if os(macOS)
import AppKit
#endif

@main
struct CCZUHelperApp: App {
    @State private var appSettings = AppSettings()
    @Environment(\.scenePhase) private var scenePhase
    @State private var resetPasswordToken: String? = nil
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            Course.self,
            Schedule.self,
            TeahousePost.self,
            TeahouseComment.self,
            UserLike.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView(resetPasswordToken: $resetPasswordToken)
                .onAppear {
                    // 应用启动时初始化通知系统
                    Task {
                        await NotificationHelper.requestAuthorizationIfNeeded()
                    }
                    
                    // 应用启动时尝试自动恢复账号信息
                    AccountSyncManager.autoRestoreAccountIfAvailable(settings: appSettings)
                    
                    // 应用启动时设置电费定时更新任务
                    ElectricityManager.shared.setupScheduledUpdate(with: appSettings)

                    // 应用启动时同步今日课程到共享容器，供小组件和手表读取
                    WidgetDataManager.shared.syncTodayCoursesFromStore(container: sharedModelContainer)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        WidgetDataManager.shared.syncTodayCoursesFromStore(container: sharedModelContainer)
                    }
                }
                .onOpenURL { url in
                    handleOpenURL(url)
                }
        }
        .modelContainer(sharedModelContainer)
        .environment(appSettings)
#if os(macOS)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("设置...") {
                    openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
#endif
    }
    
#if os(macOS)
    @State private var settingsWindow: NSWindow?
    
    private func openSettings() {
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let settingsView = MacOSSettingsWindow()
            .environment(appSettings)
            .modelContainer(sharedModelContainer)
        
        let hostingController = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "设置"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 600, height: 700))
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        settingsWindow = window
    }
#endif
    
    private func handleOpenURL(_ url: URL) {
        // 处理重置密码回调，支持本地协议和 Supabase 使用的 `edupal://reset-password` 回调
        if let host = url.host?.lowercased(), host == "reset-password" {
            // Supabase 会将 token 以 query 参数的形式附加到回调 URL 中，例如 edupal://reset-password?token=...&type=recovery
            // 先尝试从 fragment 中解析 access_token（Supabase 有时会把 token 放在 fragment）
            var extractedToken: String? = nil
            if let fragment = url.fragment, !fragment.isEmpty {
                // fragment 形式类似 access_token=...&token_type=...，将其解析为 query items
                var comps = URLComponents()
                comps.query = fragment
                if let access = comps.queryItems?.first(where: { $0.name == "access_token" })?.value {
                    extractedToken = access
                } else if let token = comps.queryItems?.first(where: { $0.name == "token" })?.value {
                    extractedToken = token
                }
            }

            // 若 fragment 未命中，再尝试 query 参数
            if extractedToken == nil {
                if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                    if let access = comps.queryItems?.first(where: { $0.name == "access_token" })?.value {
                        extractedToken = access
                    } else if let token = comps.queryItems?.first(where: { $0.name == "token" })?.value {
                        extractedToken = token
                    }
                }
            }

            if let token = extractedToken, !token.isEmpty {
                resetPasswordToken = token
                NotificationCenter.default.post(name: Notification.Name("ResetPasswordTokenReceived"), object: token)
            } else {
                // 兜底：把完整 URL 交给视图处理并广播，视图可以从字符串中尝试解析
                resetPasswordToken = url.absoluteString
                NotificationCenter.default.post(name: Notification.Name("ResetPasswordTokenReceived"), object: url.absoluteString)
            }
        }
    }
}
