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
#if canImport(GroupActivities)
@preconcurrency import GroupActivities
#endif
#if os(iOS)
import UIKit
import UserNotifications
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

#if os(iOS)
final class IOSAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private var launchShortcutItem: UIApplicationShortcutItem?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // 注册后台任务（必须在应用启动早期完成）
        LiveActivityBackgroundTaskManager.shared.registerBackgroundTasks()
        AppQuickActionManager.configureShortcutItems()
        
        UNUserNotificationCenter.current().delegate = self
        launchShortcutItem = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem
        if let userInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            TeahousePushRouteManager.handleIncomingPushUserInfo(userInfo)
        }
        return launchShortcutItem == nil
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = QuickActionSceneDelegate.self
        return config
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        DeviceTokenSyncManager.storeToken(deviceToken)
        Task {
            await DeviceTokenSyncManager.syncDeviceTokenIfPossible()
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("⚠️ APNs 注册失败: \(error.localizedDescription)")
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        TeahousePushRouteManager.handleIncomingPushUserInfo(response.notification.request.content.userInfo)
        completionHandler()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        AppQuickActionManager.configureShortcutItems()

        // 清除应用图标角标和已送达的通知
        Task {
            await NotificationHelper.resetBadgeAndDeliveredNotifications()
        }

        if let shortcutItem = launchShortcutItem {
            _ = handleQuickAction(shortcutItem)
            launchShortcutItem = nil
        }
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(handleQuickAction(shortcutItem))
    }

    private func handleQuickAction(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        AppQuickActionManager.handle(shortcutItem: shortcutItem)
    }
}

final class QuickActionSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        if let shortcutItem = connectionOptions.shortcutItem {
            _ = AppQuickActionManager.handle(shortcutItem: shortcutItem)
        }
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(AppQuickActionManager.handle(shortcutItem: shortcutItem))
    }
}
#endif

@main
struct CCZUHelperApp: App {
    @State private var appSettings = AppSettings()
    @Environment(\.scenePhase) private var scenePhase
    @State private var resetPasswordToken: String? = nil
    @State private var sharedModelContainer = CCZUHelperApp.makeBootstrapModelContainer()
    @State private var isLoadingModelContainer = false
    @State private var didBootstrapApp = false
    @State private var hasLoadedPersistentContainer = false
    #if os(macOS)
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var macAppDelegate
    @State private var settingsWindow: NSWindow?
    #endif
    #if os(iOS)
    @UIApplicationDelegateAdaptor(IOSAppDelegate.self) private var iosAppDelegate
    #endif
    
    private static func makeBootstrapModelContainer() -> ModelContainer {
        let schema = Schema([
            Item.self,
            Course.self,
            Schedule.self,
            TeahousePost.self,
            TeahouseComment.self,
            UserLike.self,
        ])

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

        fatalError("Could not create bootstrap in-memory ModelContainer.")
    }

    private static func buildPersistentModelContainer() -> ModelContainer {
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

        return makeBootstrapModelContainer()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(resetPasswordToken: $resetPasswordToken)
                .task {
                    await initializeModelContainerIfNeeded()
                }
                .onAppear {
                    if hasLoadedPersistentContainer {
                        performStartupWorkIfNeeded(container: sharedModelContainer)
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        // Delay non-UI critical sync work slightly so first frame is not blocked.
                        Task.detached(priority: .utility) { [sharedModelContainer] in
                            try? await Task.sleep(nanoseconds: 250_000_000)
                            await WidgetDataManager.shared.syncTodayCoursesFromStore(container: sharedModelContainer)
                            await MainActor.run {
                                WatchConnectivitySyncManager.shared.pushLatestCoursesToWatch()
                            }
                            await DeviceTokenSyncManager.syncDeviceTokenIfPossible()
                            DeviceInfoSyncManager.syncDevice()
                            await NotificationHelper.resetBadgeAndDeliveredNotifications()
                        }

                        Task { @MainActor in
                            ICloudSettingsSyncManager.shared.bootstrap(settings: appSettings)
                            _ = await MembershipManager.shared.refreshEntitlement(settings: appSettings)
                        }

                        #if os(iOS) && canImport(ActivityKit)
                        Task {
                            let context = ModelContext(sharedModelContainer)
                            let descriptor = FetchDescriptor<Course>()
                            if let allCourses = try? context.fetch(descriptor) {
                                await NextCourseLiveActivityManager.shared.refresh(courses: allCourses, settings: appSettings)
                            }
                        }
                        #endif
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .watchSyncRequestReceived)) { _ in
                    Task {
                        await WidgetDataManager.shared.syncTodayCoursesFromStore(container: sharedModelContainer)
                        await MainActor.run {
                            WatchConnectivitySyncManager.shared.pushLatestCoursesToWatch()
                        }
                    }
                }
                .onOpenURL { url in
                    handleOpenURL(url)
                }
                .modelContainer(sharedModelContainer)
        }
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

    @MainActor
    private func initializeModelContainerIfNeeded() async {
        guard !hasLoadedPersistentContainer, !isLoadingModelContainer else { return }
        isLoadingModelContainer = true
        let container = await Task.detached(priority: .utility) {
            await Self.buildPersistentModelContainer()
        }.value
        sharedModelContainer = container
        hasLoadedPersistentContainer = true
        performStartupWorkIfNeeded(container: container)
        isLoadingModelContainer = false
    }

    @MainActor
    private func performStartupWorkIfNeeded(container: ModelContainer) {
        guard !didBootstrapApp else { return }
        didBootstrapApp = true

        // Keep launch responsive: run migration and device sync tasks after first frame.
        Task.detached(priority: .utility) { [container] in
            try? await Task.sleep(nanoseconds: 200_000_000)
            SwiftDataMigrationManager.runPostMigrationIfNeeded(container: container)
        }
        CCZUHelperShortcuts.updateAppShortcutParameters()

        Task {
            await NotificationHelper.requestAuthorizationIfNeeded()
            await DeviceTokenSyncManager.syncDeviceTokenIfPossible()
            DeviceInfoSyncManager.syncDevice()
        }

        #if canImport(Intents) && !os(macOS)
        SiriAuthorizationManager.requestIfNeeded()
        #endif

        Task(priority: .utility) {
            let restoreOutcome = await Task.detached(priority: .utility) {
                await AccountSyncManager.autoRestoreAccountIfAvailable(preferredUsername: appSettings.username)
            }.value

            switch restoreOutcome {
            case .restored(let result):
                appSettings.userAvatarPath = result.avatarPath
                appSettings.isLoggedIn = true
                appSettings.username = result.username
                appSettings.userDisplayName = result.displayName
                print("✅ Auto-restored account: \(result.displayName)")
            case .invalidCredentials:
                // 凭证无效时仅删除 iCloud Keychain，保留本地登陆状态显示
                // 用户可在设置中手动登出，或尝试重新登陆
                print("⚠️ Stored credentials are invalid, clearing them. User may need to login again.")
                // 不设置 isLoggedIn = false，保留现有状态让用户看到
            case .unavailable:
                // iCloud Keychain 无数据时，保留本地的登陆状态
                // 可能是首次登陆、iCloud 不可用或未启用同步
                break
            }

            ICloudSettingsSyncManager.shared.bootstrap(settings: appSettings)
            _ = await MembershipManager.shared.refreshEntitlement(settings: appSettings)
        }

        Task { @MainActor in
            ElectricityManager.shared.setupScheduledUpdate(with: appSettings)
        }

        Task.detached(priority: .utility) { [container] in
            await WidgetDataManager.shared.syncTodayCoursesFromStore(container: container)
            await MainActor.run {
                WatchConnectivitySyncManager.shared.activate()
                WatchConnectivitySyncManager.shared.pushLatestCoursesToWatch()
            }
        }

        #if canImport(GroupActivities)
        Task(priority: .utility) {
            for await session in ScheduleShareActivity.sessions() {
                let payload = session.activity.payload
                session.join()
                let context = ModelContext(container)
                try? await ScheduleShareImportManager.importPayload(
                    payload,
                    modelContext: context,
                    settings: appSettings
                )
            }
        }
        #endif

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

#if os(macOS)
    private func openSettings() {
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "settings.title".localized
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 640, height: 700)

        let settingsView = MacOSSettingsWindow(onDone: { window.close() })
            .environment(appSettings)
            .modelContainer(sharedModelContainer)
        window.contentViewController = NSHostingController(rootView: settingsView)

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }
#endif
    
    private func handleOpenURL(_ url: URL) {
        if url.pathExtension.lowercased() == "cczuschedule" {
            Task { @MainActor in
                let context = ModelContext(sharedModelContainer)
                try? await ScheduleShareImportManager.importPayload(from: url, modelContext: context, settings: appSettings)
            }
            return
        }

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
