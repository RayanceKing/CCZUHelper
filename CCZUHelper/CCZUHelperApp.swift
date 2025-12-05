//
//  CCZUHelperApp.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/11/30.
//

import SwiftUI
import SwiftData

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
                }
        }
        .modelContainer(sharedModelContainer)
        .environment(appSettings)
    }
}
