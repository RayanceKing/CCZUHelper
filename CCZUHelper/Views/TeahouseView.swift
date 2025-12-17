//
//  TeahouseView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/11/30.
//

import SwiftUI
import MarkdownUI
import Kingfisher
import SwiftData
import Supabase

#if canImport(UIKit)
import UIKit
#endif

/// 茶楼视图 - 社交/论坛功能
struct TeahouseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings

    @Query(sort: \TeahousePost.createdAt, order: .reverse) private var allPosts: [TeahousePost]
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var teahouseService = TeahouseService()

    @State private var selectedCategory = 0
    @State private var showCreatePost = false
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var loadError: String?
    @State private var banners: [ActiveBanner] = []
    @State private var showLoginSheet = false
    @State private var showUserProfile = false
    @AppStorage("teahouse.hasShownInitialLogin") private var hasShownInitialLogin = false

    private static let categories: [CategoryItem] = [
        CategoryItem(id: 0, title: NSLocalizedString("teahouse.category.all", comment: ""), backendValue: nil),
        CategoryItem(id: 1, title: NSLocalizedString("teahouse.category.study", comment: ""), backendValue: "学习"),
        CategoryItem(id: 2, title: NSLocalizedString("teahouse.category.life", comment: ""), backendValue: "生活"),
        CategoryItem(id: 3, title: NSLocalizedString("teahouse.category.secondhand", comment: ""), backendValue: "二手"),
        CategoryItem(id: 4, title: NSLocalizedString("teahouse.category.confession", comment: ""), backendValue: "表白墙"),
        CategoryItem(id: 5, title: NSLocalizedString("teahouse.category.lost_found", comment: ""), backendValue: "失物招领")
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                PostsListView(
                    filteredPosts: filteredPosts,
                    isLoading: isLoading,
                    loadError: loadError,
                    validBanners: validBanners,
                    isRefreshing: isRefreshing,
                    onRetry: { Task { await loadTeahouseContent(force: true) } },
                    onLike: { toggleLike($0) },
                    authViewModel: authViewModel
                )

                CategoryBarOverlay(categories: Self.categories, selectedCategory: $selectedCategory)
                    //.padding(.horizontal, 8)
                    .padding(.top, 8)
                    .ignoresSafeArea(edges: [.horizontal])

                if !validBanners.isEmpty {
                    BannerCarousel(banners: validBanners)
                        .padding(.horizontal)
                        .padding(.top, 64)
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                }

                if isRefreshing {
                    ProgressView()
                        .tint(.primary)
                        .padding(.top, validBanners.isEmpty ? 90 : 145)
                }
            }
            .navigationTitle(NSLocalizedString("teahouse.title", comment: ""))
            .toolbar { toolbarContent }
            .background(backgroundView)
            .sheet(isPresented: $showCreatePost) {
                CreatePostView().environment(settings)
            }
            .sheet(isPresented: $showLoginSheet) {
                TeahouseLoginView().environmentObject(authViewModel)
            }
            .sheet(isPresented: $showUserProfile) {
                TeahouseUserProfileView().environmentObject(authViewModel)
            }
            .task { await loadTeahouseContent() }
            .onAppear { handleInitialLogin() }
            .refreshable { await loadTeahouseContent(force: true, showRefreshIndicator: true) }
        }
    }

    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .primaryAction) {
                Button(action: handleCreatePost) {
                    Image(systemName: "square.and.pencil")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                UserMenuButton(
                    showUserSettings: authViewModel.isAuthenticated ? $showUserProfile : $showLoginSheet,
                    isAuthenticated: authViewModel.isAuthenticated
                )
            }
        }
    }

    private var backgroundView: some View {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(.systemGroupedBackground)
        #endif
    }

    private func handleCreatePost() {
        if authViewModel.isAuthenticated {
            showCreatePost = true
        } else {
            showLoginSheet = true
        }
    }

    private func handleInitialLogin() {
        if !authViewModel.isAuthenticated && !hasShownInitialLogin {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showLoginSheet = true
                hasShownInitialLogin = true
            }
        }
    }

    private var filteredPosts: [TeahousePost] {
        var posts = allPosts
        
        guard selectedCategory < Self.categories.count else { return posts }
        if let backendValue = Self.categories[selectedCategory].backendValue {
            posts = posts.filter { $0.category == backendValue }
        }
        
        return posts
    }

    private var validBanners: [ActiveBanner] {
        banners.filter { $0.isActive == true }
    }

    @MainActor
    private func loadTeahouseContent(force: Bool = false, showRefreshIndicator: Bool = false) async {
        if isLoading && !force { return }
        isLoading = true
        if showRefreshIndicator { isRefreshing = true }
        loadError = nil

        do {
            // From Supabase get posts and banners
            // Now fetchWaterfallPosts returns [WaterfallPost]
            async let postsResponse = teahouseService.fetchWaterfallPosts(status: [.available, .sold])
            async let bannersResponse: PostgrestResponse<[ActiveBanner]> = supabase
                .from("active_banners")
                .select("*")
                .eq("is_active", value: true)
                .order("start_date")
                .execute()
            
            let (remotePosts, bannersData) = try await (postsResponse, bannersResponse)
            banners = bannersData.value
            
            try syncRemotePostsFromWaterfall(remotePosts)
        } catch {
            loadError = error.localizedDescription
        }

        isLoading = false
        isRefreshing = false
    }

    @MainActor
    private func syncRemotePostsFromWaterfall(_ remotePosts: [WaterfallPost]) throws {
        let remoteInStore = allPosts.filter { !$0.isLocal }
        remoteInStore.forEach { modelContext.delete($0) }

        for wp in remotePosts {
            let p = wp.post
            let isAnonymous = p.isAnonymous ?? false
            let authorName = isAnonymous
                ? NSLocalizedString("create_post.anonymous_user", comment: "")
                : (wp.profile?.username ?? NSLocalizedString("create_post.user", comment: ""))
            let images = p.imageUrlsArray
            let categoryName = mapCategoryIdToBackend(p.categoryId)

            let model = TeahousePost(
                id: p.id ?? UUID().uuidString,
                type: "post",
                author: authorName,
                authorId: isAnonymous ? nil : p.userId,
                authorAvatarUrl: isAnonymous ? nil : wp.profile?.avatarUrl,
                category: categoryName,
                price: p.price,
                title: p.title ?? "",
                content: p.content ?? "",
                images: images,
                likes: p.likeCount ?? 0,
                comments: p.commentCount ?? 0,
                createdAt: p.createdAt ?? Date(),
                isLocal: false,
                syncStatus: .synced
            )
            modelContext.insert(model)
        }

        try modelContext.save()
    }

    private func mapCategoryIdToBackend(_ categoryId: Int?) -> String {
        guard let id = categoryId else { return "" }
        switch id {
        case 1: return "学习"
        case 2: return "生活"
        case 3: return "二手"
        case 4: return "表白墙"
        case 5: return "失物招领"
        default: return "其他"
        }
    }

    private func toggleLike(_ post: TeahousePost) {
        // 检查是否登录
        guard authViewModel.isAuthenticated else {
            showLoginSheet = true
            return
        }
        
        guard let userId = authViewModel.session?.user.id.uuidString else { return }
        let postId = post.id
        
        let descriptor = FetchDescriptor<UserLike>(
            predicate: #Predicate { like in
                like.userId == userId && like.postId == postId
            }
        )

        // 检查本地是否已点赞
        let isCurrentlyLiked = (try? modelContext.fetch(descriptor).first) != nil
        
        Task {
            do {
                if isCurrentlyLiked {
                    // 取消点赞 - 删除 Supabase 中的点赞记录
                    _ = try await supabase
                        .from("likes")
                        .delete()
                        .eq("post_id", value: postId)
                        .eq("user_id", value: userId)
                        .execute()
                    
                    // 更新本地
                    if let likes = try? modelContext.fetch(descriptor), !likes.isEmpty {
                        for like in likes {
                            modelContext.delete(like)
                        }
                        post.likes = max(0, post.likes - 1)
                    }
                } else {
                    // 添加点赞 - 插入 Supabase 点赞记录
                    let newLike = Like(
                        id: UUID().uuidString,
                        userId: userId,
                        postId: postId,
                        commentId: nil
                    )
                    
                    _ = try await supabase
                        .from("likes")
                        .insert(newLike)
                        .execute()
                    
                    // 更新本地
                    let like = UserLike(userId: userId, postId: postId)
                    modelContext.insert(like)
                    post.likes += 1
                }
                
                try modelContext.save()
            } catch {
                print("点赞操作失败: \(error.localizedDescription)")
            }
        }
    }
}


struct CategoryItem: Identifiable {
    let id: Int
    let title: String
    let backendValue: String?
}

/// 分类标签
struct CategoryTag: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        FloatingTabButton(title: title, isSelected: isSelected, action: action)
    }
}

#Preview {
    TeahouseView()
}
