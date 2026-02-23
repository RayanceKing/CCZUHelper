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

private extension Notification.Name {
    static let scheduleExternalDateSelected = Notification.Name("ScheduleExternalDateSelected")
    static let scheduleCurrentDateDidChange = Notification.Name("ScheduleCurrentDateDidChange")
}

/// macOS 专用内容视图 - 使用 NavigationSplitView 布局
struct MacOSContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    
    @State private var selectedTab: Int = 0
    @State private var showImportSheet = false
    @State private var showSettings = false
    @State private var selectedDate = Date()
    @State private var settingsWindow: NSWindow?
    @State private var resetPasswordToken: String? = nil
    
    // 用于与 ScheduleView 通信的 @State（必须从子视图读取）
    @State private var scheduleRefresh: UUID = UUID()

    @ViewBuilder
    private var detailBackground: some View {
        GeometryReader { geo in
            if settings.backgroundImageEnabled,
               let path = settings.backgroundImagePath,
               let image = NSImage(contentsOfFile: path) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .opacity(settings.backgroundOpacity)
            } else {
                Color(nsColor: .windowBackgroundColor)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
    
    var body: some View {
        NavigationSplitView {
                // MARK: - 左侧导航栏
                VStack(spacing: 0) {
                    // 导航选项
                    List(selection: $selectedTab) {
                        NavigationLink(value: 0) {
                            Label("tab.schedule".localized, systemImage: "calendar")
                        }
                        .tag(0)
                        
                        NavigationLink(value: 1) {
                            Label("tab.services".localized, systemImage: "square.grid.2x2")
                        }
                        .tag(1)
                        
                        NavigationLink(value: 2) {
                            Label("tab.teahouse".localized, systemImage: "cup.and.saucer")
                        }
                        .tag(2)
                    }
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)
                    .background(.regularMaterial)
                    
                    Divider()
                    
                    // 日历选择器
                    VStack(spacing: 0) {
                        Text("common.date".localized)
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
                    .background(.regularMaterial)
                    .frame(maxHeight: .infinity)
                }
                .frame(minWidth: 170, idealWidth: 220, maxWidth: 250)
                .navigationSplitViewColumnWidth(min: 170, ideal: 220, max: 250)
                .safeAreaPadding(.top)
            } detail: {
                // MARK: - 右侧内容区
                ZStack {
                    detailBackground
                    Group {
                        switch selectedTab {
                        case 0:
                            ScheduleView()
                        case 1:
                            ServicesView()
                        case 2:
                            TeahouseView(resetPasswordToken: $resetPasswordToken)
                        default:
                            ScheduleView()
                        }
                    }
                }
            }
        .navigationSplitViewStyle(.balanced)
        .toolbarBackground(.hidden, for: .windowToolbar)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .sheet(isPresented: $showImportSheet) {
            ImportScheduleView()
                .frame(minWidth: 500, minHeight: 400)
        }
        .onChange(of: selectedDate) { _, newValue in
            guard selectedTab == 0 else { return }
            NotificationCenter.default.post(
                name: .scheduleExternalDateSelected,
                object: nil,
                userInfo: ["date": newValue]
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .scheduleCurrentDateDidChange)) { notification in
            guard let date = notification.userInfo?["date"] as? Date else { return }
            if !Calendar.current.isDate(selectedDate, inSameDayAs: date) {
                selectedDate = date
            }
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
        window.title = "settings.title".localized
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
