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
import AppIntents
#if canImport(Intents) && !os(macOS)
import Intents
#endif
#if canImport(StoreKit)
import StoreKit
#endif

#if os(macOS)
import AppKit

final class MacAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
#endif

@main
struct CCZUHelperApp: App {
    @State private var appSettings = AppSettings()
    @Environment(\.scenePhase) private var scenePhase
    @State private var resetPasswordToken: String? = nil
    #if os(macOS)
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var macAppDelegate
    #endif
    
    var sharedModelContainer: ModelContainer = {
        let cloudSchema = Schema([
            Item.self,
            Course.self,
            Schedule.self,
        ])
        let teahouseLocalSchema = Schema([
            TeahousePost.self,
            TeahouseComment.self,
            UserLike.self,
        ])
        let schema = Schema([
            Item.self,
            Course.self,
            Schedule.self,
            TeahousePost.self,
            TeahouseComment.self,
            UserLike.self,
        ])
        // 1) 优先使用 CloudKit
        if #available(iOS 17.0, macOS 14.0, visionOS 1.0, *) {
            let cloudConfig = ModelConfiguration(
                "CloudSynced",
                schema: cloudSchema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )
            let teahouseLocalConfig = ModelConfiguration(
                "TeahouseLocal",
                schema: teahouseLocalSchema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            if let container = try? ModelContainer(for: schema, configurations: [cloudConfig, teahouseLocalConfig]) {
                return container
            } else {
                print("⚠️ SwiftData mixed CloudKit/local container init failed, fallback to all-local store.")
            }
        }

        // 2) 回退到本地存储（所有模型禁用 CloudKit）
        let localConfig: ModelConfiguration
        if #available(iOS 17.0, macOS 14.0, visionOS 1.0, *) {
            localConfig = ModelConfiguration(
                "AllLocal",
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
        } else {
            localConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        }
        if let container = try? ModelContainer(for: schema, configurations: [localConfig]) {
            return container
        } else {
            print("⚠️ SwiftData local persistent container init failed, fallback to in-memory store.")
        }

        // 3) 最终兜底：内存容器（避免 fatalError 导致应用无法启动）
        let memoryConfig: ModelConfiguration
        if #available(iOS 17.0, macOS 14.0, visionOS 1.0, *) {
            memoryConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        } else {
            memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        }
        if let container = try? ModelContainer(for: schema, configurations: [memoryConfig]) {
            return container
        }

        fatalError("Could not create any ModelContainer (CloudKit/local/in-memory all failed).")
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView(resetPasswordToken: $resetPasswordToken)
                .onAppear {
                    // 启动后执行一次模型迁移（去重以兼容移除 unique 约束）
                    SwiftDataMigrationManager.runPostMigrationIfNeeded(container: sharedModelContainer)

                    // 刷新 App Shortcuts 参数，确保 Siri 能及时识别最新意图与短语
                    CCZUHelperShortcuts.updateAppShortcutParameters()

                    // 应用启动时初始化通知系统
                    Task {
                        await NotificationHelper.requestAuthorizationIfNeeded()
                    }

                    #if canImport(Intents) && !os(macOS)
                    SiriAuthorizationManager.requestIfNeeded()
                    #endif
                    
                    // 应用启动时尝试自动恢复账号信息
                    AccountSyncManager.autoRestoreAccountIfAvailable(settings: appSettings)

                    // 应用启动时初始化 iCloud 数据同步
                    ICloudSettingsSyncManager.shared.bootstrap(settings: appSettings)

                    Task {
                        _ = await MembershipManager.shared.refreshEntitlement(settings: appSettings)
                    }
                    
                    // 应用启动时设置电费定时更新任务
                    ElectricityManager.shared.setupScheduledUpdate(with: appSettings)

                    // 应用启动时同步今日课程到共享容器，供小组件和手表读取
                    WidgetDataManager.shared.syncTodayCoursesFromStore(container: sharedModelContainer)
                    
                    // 启动 StoreKit 交易监听（处理 IAP 交易更新）
                    #if canImport(StoreKit)
                    if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, visionOS 1.0, *) {
                        Task {
                            for await result in Transaction.updates {
                                await MembershipManager.shared.handleTransactionUpdate(result, settings: appSettings)
                            }
                        }
                    }
                    #endif
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        WidgetDataManager.shared.syncTodayCoursesFromStore(container: sharedModelContainer)
                        ICloudSettingsSyncManager.shared.bootstrap(settings: appSettings)
                        Task {
                            _ = await MembershipManager.shared.refreshEntitlement(settings: appSettings)
                        }
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
                Button("settings.title".localized + "...") {
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
        window.title = "settings.title".localized
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
        // 处理 App Intent Deep Link
        if let host = url.host?.lowercased(), host == "open" {
            let route = url.path.lowercased()
            if route.contains("schedule") {
                NotificationCenter.default.post(name: Notification.Name("IntentOpenSchedule"), object: nil)
                return
            }
            if route.contains("grades") {
                NotificationCenter.default.post(name: Notification.Name("IntentOpenGrades"), object: nil)
                return
            }
        }

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
