//
//  CCZUHelperApp.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/11/30.
//

import SwiftUI
import SwiftData
import CCZUKit

#if os(macOS)
import AppKit
#endif

@main
struct CCZUHelperApp: App {
    @State private var appSettings = AppSettings()
    
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
            ContentView()
                .onAppear {
                    // 应用启动时初始化通知系统
                    Task {
                        await NotificationHelper.requestAuthorizationIfNeeded()
                    }
                    
                    // 应用启动时尝试自动恢复账号信息
                    AccountSyncManager.autoRestoreAccountIfAvailable(settings: appSettings)
                    
                    // 应用启动时设置电费定时更新任务
                    ElectricityManager.shared.setupScheduledUpdate(with: appSettings)
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
}
