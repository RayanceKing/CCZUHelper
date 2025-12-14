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
    @State private var teahouseSearchText = ""
    
    var body: some View {
        if #available(iOS 26.0, *) {
            TabView {
                Tab("tab.schedule".localized, systemImage: "calendar") {
                    ScheduleView()
                }

                Tab("tab.services".localized, systemImage: "square.grid.2x2") {
                    ServicesView()
                }

                Tab("tab.teahouse".localized, systemImage: "cup.and.saucer") {
                    TeahouseView()
                }

                Tab(role: .search) {
                    SearchTabView(searchText: $teahouseSearchText)
                        .searchable(text: $teahouseSearchText)
                }
            }
        } else if #available(iOS 18.0, *) {
            TabView {
                Tab("tab.schedule".localized, systemImage: "calendar") {
                    ScheduleView()
                }

                Tab("tab.services".localized, systemImage: "square.grid.2x2") {
                    ServicesView()
                }

                Tab("tab.teahouse".localized, systemImage: "cup.and.saucer") {
                    TeahouseView()
                }

                Tab("tab.search".localized, systemImage: "magnifyingglass", role: .search) {
                    SearchTabView(searchText: $teahouseSearchText)
                        .searchable(text: $teahouseSearchText)
                }
            }
        } else {
            // 旧系统兼容：将搜索作为普通 tab 保留完整功能
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

                // 搜索
                SearchTabView(searchText: $teahouseSearchText)
                    .searchable(text: $teahouseSearchText)
                    .tabItem {
                        Label("tab.search".localized, systemImage: "magnifyingglass")
                    }
                    .tag(3)
            }
        }
    }
}

/// 搜索标签页：使用与茶楼相同的数据源过滤帖子
struct SearchTabView: View {
    @Binding var searchText: String
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TeahousePost.createdAt, order: .reverse) private var allPosts: [TeahousePost]
    @StateObject private var authViewModel = AuthViewModel()

    private var backgroundColor: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(.systemGroupedBackground)
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
                HStack {
                    Text(NSLocalizedString("teahouse.search_title", comment: "Search"))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)

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
                                    PostRow(post: post, onLike: { })
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
        }
    }
}

#Preview {
    ContentView()
        .environment(AppSettings())
        .modelContainer(for: [Item.self, Course.self, Schedule.self], inMemory: true)
}
