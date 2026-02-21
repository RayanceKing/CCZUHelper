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
    
    @Binding var resetPasswordToken: String?
    var body: some View {
        #if os(macOS)
        MacOSContentView()
        #else
        iOSContentView(resetPasswordToken: $resetPasswordToken)
        #endif
    }
}

struct iOSContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @State private var selectedTab = 0
    @State private var teahouseSearchText = ""
    private let pendingIntentRouteKey = "intent.pending.route"
    
    @Binding var resetPasswordToken: String?
    //@State private var showResetLoginSheet: Bool = false
    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                TabView(selection: $selectedTab) {
                    Tab("tab.schedule".localized, systemImage: "calendar", value: 0) {
                        ScheduleView()
                    }

                    Tab("tab.services".localized, systemImage: "square.grid.2x2", value: 1) {
                        ServicesView()
                    }

                    Tab("tab.teahouse".localized, systemImage: "cup.and.saucer", value: 2) {
                        TeahouseView(resetPasswordToken: $resetPasswordToken)
                    }

                    Tab("tab.search".localized, systemImage: "magnifyingglass", value: 3, role: .search) {
                        SearchTabView(searchText: $teahouseSearchText)
                    }
                }
            } else if #available(iOS 18.0, *) {
                TabView(selection: $selectedTab) {
                    Tab("tab.schedule".localized, systemImage: "calendar", value: 0) {
                        ScheduleView()
                    }

                    Tab("tab.services".localized, systemImage: "square.grid.2x2", value: 1) {
                        ServicesView()
                    }

                    Tab("tab.teahouse".localized, systemImage: "cup.and.saucer", value: 2) {
                        TeahouseView(resetPasswordToken: $resetPasswordToken)
                    }

                    Tab("tab.search".localized, systemImage: "magnifyingglass", value: 3, role: .search) {
                        SearchTabView(searchText: $teahouseSearchText)
                    }
                }
            } else {
                TabView(selection: $selectedTab) {
                    ScheduleView()
                        .tabItem { Label("tab.schedule".localized, systemImage: "calendar") }
                        .tag(0)

                    ServicesView()
                        .tabItem { Label("tab.services".localized, systemImage: "square.grid.2x2") }
                        .tag(1)

                    TeahouseView(resetPasswordToken: $resetPasswordToken)
                        .tabItem { Label("tab.teahouse".localized, systemImage: "cup.and.saucer") }
                        .tag(2)

                    SearchTabView(searchText: $teahouseSearchText)
                        .tabItem { Label("tab.search".localized, systemImage: "magnifyingglass") }
                        .tag(3)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("IntentOpenSchedule"))) { _ in
            selectedTab = 0
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("IntentOpenGrades"))) { _ in
            openGradesPage()
        }
        .onAppear {
            consumePendingIntentRouteIfNeeded()
        }
        #if canImport(UIKit)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            consumePendingIntentRouteIfNeeded()
        }
        #endif
    }

    private func consumePendingIntentRouteIfNeeded() {
        let defaults = UserDefaults(suiteName: AppGroupIdentifiers.main) ?? .standard
        guard let route = defaults.string(forKey: pendingIntentRouteKey) else { return }
        defaults.removeObject(forKey: pendingIntentRouteKey)

        switch route {
        case "schedule":
            selectedTab = 0
        case "grades":
            openGradesPage()
        default:
            break
        }
    }

    private func openGradesPage() {
        selectedTab = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            NotificationCenter.default.post(name: Notification.Name("IntentPresentGradeQuery"), object: nil)
        }
    }
}

/// 搜索标签页：使用与茶楼相同的数据源过滤帖子
struct SearchTabView: View {
    @Binding var searchText: String
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TeahousePost.createdAt, order: .reverse) private var allPosts: [TeahousePost]
    @StateObject private var authViewModel = AuthViewModel()
    @State private var isSearchPresented = false

    private var backgroundColor: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(.systemBackground)
        #endif
    }

    private var searchResults: [TeahousePost] {
        guard !searchText.isEmpty else { return [] }
        return allPosts.filter { post in
            post.title.localizedCaseInsensitiveContains(searchText) ||
            post.content.localizedCaseInsensitiveContains(searchText) ||
            post.author.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if searchText.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)
                        Text(NSLocalizedString("teahouse.search_hint", comment: "Enter keywords to search"))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(backgroundColor)
                } else if searchResults.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.magnifyingglass")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)
                        Text(NSLocalizedString("teahouse.no_results", comment: "No posts found"))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(backgroundColor)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(searchResults) { post in
                                NavigationLink {
                                    PostDetailView(post: post)
                                        .environmentObject(authViewModel)
                                } label: {
                                    PostRow(post: post, onLike: { }, authViewModel: authViewModel)
                                        .padding(.horizontal, 16)
                                }
                                .buttonStyle(.plain)
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    .background(backgroundColor)
                }
            }
            .navigationTitle(NSLocalizedString("teahouse.search_title", comment: "Search"))
            .searchable(text: $searchText, isPresented: $isSearchPresented)
            .onAppear {
                // 返回时收起搜索栏与键盘
                isSearchPresented = false
            }
        }
    }
}


#if DEBUG
struct ContentView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State var token: String? = nil
        var body: some View {
            ContentView(resetPasswordToken: $token)
                .environment(AppSettings())
                .modelContainer(for: [Item.self, Course.self, Schedule.self], inMemory: true)
        }
    }
    static var previews: some View {
        PreviewWrapper()
    }
}
#endif
