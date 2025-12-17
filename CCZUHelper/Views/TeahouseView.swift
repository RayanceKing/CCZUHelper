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

    private var categories: [CategoryItem] {
        [
            CategoryItem(id: 0, title: NSLocalizedString("teahouse.category.all", comment: ""), backendValue: nil),
            CategoryItem(id: 1, title: NSLocalizedString("teahouse.category.study", comment: ""), backendValue: "学习"),
            CategoryItem(id: 2, title: NSLocalizedString("teahouse.category.life", comment: ""), backendValue: "生活"),
            CategoryItem(id: 3, title: NSLocalizedString("teahouse.category.secondhand", comment: ""), backendValue: "二手"),
            CategoryItem(id: 4, title: NSLocalizedString("teahouse.category.confession", comment: ""), backendValue: "表白墙"),
            CategoryItem(id: 5, title: NSLocalizedString("teahouse.category.lost_found", comment: ""), backendValue: "失物招领")
        ]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    // Posts list
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if isLoading && filteredPosts.isEmpty {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 24)
                            }

                            ForEach(filteredPosts) { post in
                                NavigationLink {
                                    PostDetailView(post: post)
                                        .environmentObject(authViewModel)
                                } label: {
                                    PostRow(post: post, onLike: {
                                        toggleLike(post)
                                    })
                                    .padding(.horizontal, 16)
                                }
                                .buttonStyle(.plain)
                                .padding(.vertical, 8)

                            }

                            if let loadError {
                                ContentUnavailableView {
                                    Label(NSLocalizedString("teahouse.load_failed", comment: ""), systemImage: "exclamationmark.triangle")
                                } description: {
                                    VStack(spacing: 8) {
                                        Text(loadError)
                                        Button(action: {
                                            Task { await loadTeahouseContent(force: true) }
                                        // 分类栏浮层组件提前声明，避免作用域问题
                                        struct CategoryBarOverlay: View {
                                            let categories: [CategoryItem]
                                            @Binding var selectedCategory: Int

                                            var body: some View {
                                                ScrollView(.horizontal, showsIndicators: false) {
                                                    HStack(spacing: 12) {
                                                        ForEach(categories) { category in
                                                            CategoryTag(
                                                                title: category.title,
                                                                isSelected: selectedCategory == category.id
                                                            ) {
                                                                withAnimation {
                                                                    selectedCategory = category.id
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                                .padding(.vertical, 8)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                        }

                                        // 这里是 TeahouseView 的定义
                                        }) {
                                            Text(NSLocalizedString("teahouse.retry", comment: ""))
                                        }
                                    }
                                }
                                .padding(.vertical, 24)
                            } else if filteredPosts.isEmpty && !isLoading {
                                ContentUnavailableView {
                                    Label(NSLocalizedString("teahouse.no_posts", comment: ""), systemImage: "bubble.left.and.bubble.right")
                                } description: {
                                    Text(NSLocalizedString("teahouse.no_posts_hint", comment: ""))
                                }
                                .frame(height: 320)
                            }
                        }
                        .padding(.top, (validBanners.isEmpty ? 0 : 156) + 56)
                    }

                    // Floating category overlay (transparent)
                    CategoryBarOverlay(categories: categories, selectedCategory: $selectedCategory)
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                        .ignoresSafeArea(edges: [.horizontal])

                    // Floating banner overlay (below category)
                    if !validBanners.isEmpty {
                        BannerCarousel(banners: validBanners)
                            .padding(.horizontal)
                            .padding(.top, 64)
                            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                    }

                    if isRefreshing {
                        ProgressView()
                            .tint(.primary)
                            .padding(.top, validBanners.isEmpty ? 88 : 156)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("teahouse.title", comment: ""))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        if authViewModel.isAuthenticated {
                            showCreatePost = true
                        } else {
                            showLoginSheet = true
                        }
                    }) {
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
            #if os(macOS)
            .background(Color(nsColor: .windowBackgroundColor))
            #else
            .background(Color(.systemGroupedBackground))
            #endif
            .sheet(isPresented: $showCreatePost) {
                CreatePostView()
                    .environment(settings)
            }
            .sheet(isPresented: $showLoginSheet) {
                TeahouseLoginView()
                    .environmentObject(authViewModel)
            }
            .sheet(isPresented: $showUserProfile) {
                TeahouseUserProfileView()
                    .environmentObject(authViewModel)
            }
            .task {
                await loadTeahouseContent()
            }
            .onAppear {
                // 初次进入页面且未登录时弹出登录
                if !authViewModel.isAuthenticated && !hasShownInitialLogin {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showLoginSheet = true
                        hasShownInitialLogin = true
                    }
                }
            }
            .refreshable { await loadTeahouseContent(force: true, showRefreshIndicator: true) }
        }
    }

    private var filteredPosts: [TeahousePost] {
        var posts = allPosts
        
        guard selectedCategory < categories.count else { return posts }
        if let backendValue = categories[selectedCategory].backendValue {
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

/// 浮动分类按钮（支持液态玻璃，向下兼容）
private struct FloatingTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    // 可选：交互与风格开关
    private var isInteractive: Bool { true }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(
                    {
                        if #available(iOS 26.0, macOS 15.0, *) {
                            return isSelected ? AnyShapeStyle(.black.opacity(0.9)) : AnyShapeStyle(.primary)
                        } else {
                            // 旧系统：保持原有样式
                            return isSelected ? AnyShapeStyle(.black) : AnyShapeStyle(.primary.opacity(0.7))
                        }
                    }()
                )
                .padding(.horizontal, isSelected ? 18 : 16)
                .padding(.vertical, isSelected ? 11 : 10)
                .background(
                    Group {
                        if #available(iOS 26.0, macOS 15.0, *) {
                            #if os(visionOS)
                            RoundedRectangle(cornerRadius: 100)
                                .fill(isSelected ? Color.white.opacity(0.8) : Color.clear)
                            #else
                            RoundedRectangle(cornerRadius: 100)
                                .fill(isSelected ? Color.white.opacity(0.8) : Color.clear)
                                .glassEffect(.clear.interactive(isInteractive), in: .rect(cornerRadius: 100))
                            #endif
                        }
                        else {
                            #if os(macOS)
                            RoundedRectangle(cornerRadius: 100)
                                .fill(isSelected ? Color.blue : Color(nsColor: .controlBackgroundColor))
                            #else
                            RoundedRectangle(cornerRadius: 100)
                                .fill(isSelected ? Color.blue : Color(.systemGray5))
                            #endif
                        }
                    }
                )
                .overlay(
                    Capsule()
                    //RoundedRectangle(cornerRadius: 100)
                        .strokeBorder(
                            Color.white.opacity(isSelected ? 0.3 : 0.1),
                            lineWidth: 0.5
                        )
                )
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.95))
    }
}

private struct PressScaleButtonStyle: ButtonStyle {
    let scale: CGFloat
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.8), value: configuration.isPressed)
    }
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

struct BannerCarousel: View {
    let banners: [ActiveBanner]
    @State private var currentIndex = 0
    @State private var autoScrollTimer: Timer?

    var body: some View {
        TabView(selection: $currentIndex) {
            ForEach(banners.indices, id: \.self) { index in
                BannerCard(banner: banners[index])
                    .tag(index)
            }
        }
        .frame(height: 140)
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .onAppear {
            startAutoScroll()
        }
        .onDisappear {
            stopAutoScroll()
        }
    }

    private func startAutoScroll() {
        stopAutoScroll()
        guard banners.count > 1 else { return }
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            withAnimation {
                currentIndex = (currentIndex + 1) % banners.count
            }
        }
    }

    private func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
    }

    private func color(from hex: String) -> Color {
        var hexString = hex.replacingOccurrences(of: "#", with: "")
        if hexString.count == 6 {
            hexString.append("FF")
        }
        guard let value = UInt64(hexString, radix: 16) else { return .blue }
        let r = Double((value & 0xFF000000) >> 24) / 255
        let g = Double((value & 0x00FF0000) >> 16) / 255
        let b = Double((value & 0x0000FF00) >> 8) / 255
        let a = Double(value & 0x000000FF) / 255
        return Color(red: r, green: g, blue: b, opacity: a)
    }

    private func dateLabel(for date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        return formatter.string(from: date)
    }
}

struct BannerCard: View {
    let banner: ActiveBanner
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if #available(iOS 26.0, macOS 15.0, *) {
                    Text(banner.title ?? "")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(banner.content ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text(banner.title ?? "")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(banner.content ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            
            Text("\(dateLabel(for: banner.startDate)) - \(dateLabel(for: banner.endDate))")
                .font(.caption)
                .foregroundStyle(
                    {
                        if #available(iOS 26.0, macOS 15.0, *) {
                            return AnyShapeStyle(.secondary)
                        } else {
                            return AnyShapeStyle(.white.opacity(0.8))
                        }
                    }()
                )
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Group {
                #if os(visionOS)
                // visionOS: 使用原有有色背景，避免 glassEffect 不可用
                color(from: banner.color ?? "#007AFF")
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                #else
                if #available(iOS 26.0, macOS 15.0, *) {
                    // 无颜色液态玻璃（iOS/macOS）
                    RoundedRectangle(cornerRadius: 60)
                        .fill(Color.clear)
                        .glassEffect(.clear.interactive(true), in: .rect(cornerRadius: 14))
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                } else {
                    // 旧系统回退到原有有色背景
                    color(from: banner.color ?? "#007AFF")
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                #endif
            }
        )
    }

    private func dateLabel(for date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        return formatter.string(from: date)
    }

    private func color(from hex: String) -> Color {
        var hexString = hex.replacingOccurrences(of: "#", with: "")
        if hexString.count == 6 {
            hexString.append("FF")
        }
        guard let value = UInt64(hexString, radix: 16) else { return .blue }
        let r = Double((value & 0xFF000000) >> 24) / 255
        let g = Double((value & 0x00FF0000) >> 16) / 255
        let b = Double((value & 0x0000FF00) >> 8) / 255
        let a = Double(value & 0x000000FF) / 255
        return Color(red: r, green: g, blue: b, opacity: a)
    }
}

