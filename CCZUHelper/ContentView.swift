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
    @State private var settings = AppSettings()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 课程表
            ScheduleView()
                .tabItem {
                    Label("课程表", systemImage: "calendar")
                }
                .tag(0)
            
            // 服务
            ServicesView()
                .tabItem {
                    Label("服务", systemImage: "square.grid.2x2")
                }
                .tag(1)
            
            // 茶楼
            TeahouseView()
                .tabItem {
                    Label("茶楼", systemImage: "cup.and.saucer")
                }
                .tag(2)
        }
        .environment(settings)
//        .preferredColorScheme(settings.themeMode.colorScheme)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Item.self, Course.self, Schedule.self], inMemory: true)
}
