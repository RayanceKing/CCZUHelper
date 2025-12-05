//
//  MacOSContentView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/06.
//

import SwiftUI
import SwiftData

#if os(macOS)
import AppKit

/// macOS 专用内容视图 - 使用 NavigationSplitView 布局
struct MacOSContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    
    @State private var selectedTab: Int = 0
    @State private var showImportSheet = false
    @State private var showSettings = false
    @State private var selectedDate = Date()
    @State private var settingsWindow: NSWindow?
    
    // 用于与 ScheduleView 通信的 @State（必须从子视图读取）
    @State private var scheduleRefresh: UUID = UUID()
    
    var body: some View {
        NavigationSplitView {
            // MARK: - 左侧导航栏
            VStack(spacing: 0) {
                // 顶部工具栏
                HStack(spacing: 12) {
                    Button(action: { openSettings() }) {
                        Image(systemName: "gear")
                            .font(.system(size: 14))
                            .frame(width: 28, height: 28)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("打开设置")
                    
                    Button(action: { showImportSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                            .frame(width: 28, height: 28)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("导入课程表")
                    
                    Spacer()
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor))
                .border(Color(nsColor: .separatorColor), width: 1)
                
                // 导航选项
                List(selection: $selectedTab) {
                    NavigationLink(value: 0) {
                        Label("课表", systemImage: "calendar")
                    }
                    .tag(0)
                    
                    NavigationLink(value: 1) {
                        Label("服务", systemImage: "square.grid.2x2")
                    }
                    .tag(1)
                    
                    NavigationLink(value: 2) {
                        Label("茶楼", systemImage: "cup.and.saucer")
                    }
                    .tag(2)
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .background(Color(nsColor: .controlBackgroundColor))
                
                Divider()
                
                // 日历选择器
                VStack(spacing: 0) {
                    Text("日期")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    
                    Divider()
                    
                    ScrollView {
                        DatePicker(
                            selection: $selectedDate,
                            displayedComponents: [.date]
                        ) {
                            EmptyView()
                        }
                        .datePickerStyle(.graphical)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor))
                .frame(maxHeight: .infinity)
            }
            .frame(minWidth: 200)
        } detail: {
            // MARK: - 右侧内容区
            Group {
                switch selectedTab {
                case 0:
                    ScheduleView()
                case 1:
                    ServicesView()
                case 2:
                    TeahouseView()
                default:
                    ScheduleView()
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showImportSheet) {
            ImportScheduleView()
                .frame(minWidth: 500, minHeight: 400)
        }
    }
    
    private func openSettings() {
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let settingsView = MacOSSettingsWindow()
            .environment(settings)
        
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
}

#Preview {
    MacOSContentView()
        .environment(AppSettings())
}
#endif
