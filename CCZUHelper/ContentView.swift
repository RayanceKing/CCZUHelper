//
//  ContentView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/11/30.
//

import SwiftUI
import SwiftData

/// 主内容视图 - 包含三个TabView: 课程表、服务、茶楼
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    
    var body: some View {
        #if os(macOS)
        MacOSContentView()
        #else
        iOSContentView()
        #endif
    }
}

struct iOSContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 课程表
            ScheduleView()
                .tabItem {
                    Label("tab.schedule".localized, systemImage: "calendar")
                }
                .tag(0)
            
            // 服务
            ServicesView()
                .tabItem {
                    Label("tab.services".localized, systemImage: "square.grid.2x2")
                }
                .tag(1)
            
            // 茶楼
            TeahouseView()
                .tabItem {
                    Label("tab.teahouse".localized, systemImage: "cup.and.saucer")
                }
                .tag(2)
        }
    }
}

#Preview {
    ContentView()
        .environment(AppSettings())
        .modelContainer(for: [Item.self, Course.self, Schedule.self], inMemory: true)
}
