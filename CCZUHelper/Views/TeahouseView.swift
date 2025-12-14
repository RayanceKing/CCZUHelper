//
//  TeahouseView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/11/30.
//

import SwiftUI
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
                        .ignoresSafeArea(edges: .horizontal)

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
                    if authViewModel.isAuthenticated {
                        Button(action: {
                            showUserProfile = true
                        }) {
                            Image(systemName: "person.crop.circle.fill")
                        }
                    } else {
                        Button(action: {
                            showLoginSheet = true
                        }) {
                            Image(systemName: "person.crop.circle")
                        }
                    }
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
            let authorName = wp.profile?.username ?? NSLocalizedString("create_post.anonymous_user", comment: "")
            let images = p.imageUrlsArray
            let categoryName = mapCategoryIdToBackend(p.categoryId)

            let model = TeahousePost(
                id: p.id ?? UUID().uuidString,
                type: "post",
                author: authorName,
                authorId: p.userId,
                category: categoryName,
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
                            RoundedRectangle(cornerRadius: 100)
                                .fill(isSelected ? Color.white.opacity(0.8) : Color.clear)
                                .glassEffect(.clear.interactive(isInteractive), in: .rect(cornerRadius: 100))
//                                .shadow(
//                                    color: .black.opacity(isSelected ? 0.25 : 0.08),
//                                    radius: isSelected ? 4 : 2,
//                                    x: 0, y: isSelected ? 2 : 1
//                                )
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
                if #available(iOS 26.0, macOS 15.0, *) {
                    // 无颜色液态玻璃
                    RoundedRectangle(cornerRadius: 60)
                        .fill(Color.clear)
                        .glassEffect(.clear.interactive(true), in: .rect(cornerRadius: 14))
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                } else {
                    // 旧系统回退到原有有色背景
                    color(from: banner.color ?? "#007AFF")
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        )
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

    private func dateLabel(for date: Date?) -> String { // Modified to accept optional Date
        guard let date = date else { return "" } // Handle nil date
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        return formatter.string(from: date)
    }
}

/// 帖子行
struct PostRow: View {
    @Environment(\.modelContext) private var modelContext
    let post: TeahousePost
    let onLike: () -> Void

    @Environment(AppSettings.self) private var settings

    @Query var userLikes: [UserLike]

    init(post: TeahousePost, onLike: @escaping () -> Void) {
        self.post = post
        self.onLike = onLike
        let postId = post.id
        let userId = AppSettings().username ?? "guest"
        self._userLikes = Query(filter: #Predicate { like in
            like.postId == postId && like.userId == userId
        })
    }

    private var isLiked: Bool {
        !userLikes.isEmpty && userLikes.contains { $0.postId == post.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(post.author)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        if post.isLocal {
                            Text(NSLocalizedString("teahouse.local", comment: ""))
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .foregroundStyle(.orange)
                                .clipShape(Capsule())
                        }
                    }

                    Text(timeAgoString(from: post.createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let category = post.category {
                    Text(category)
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(post.title)
                    .font(.headline)

                Text(post.content)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            if !post.images.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(post.images.prefix(3), id: \.self) { imagePath in
                            if let url = URL(string: imagePath), url.scheme?.hasPrefix("http") == true {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                            .frame(width: 100, height: 100)
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    case .failure:
                                        placeholderImage
                                    @unknown default:
                                        placeholderImage
                                    }
                                }
                            } else if let image = PlatformImage(contentsOfFile: imagePath) {
                                PlatformImageView(platformImage: image)
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }

            HStack(spacing: 24) {
                Button(action: onLike) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundStyle(isLiked ? .red : .secondary)
                        Text("\(post.likes)")
                    }
                    .font(.subheadline)
                    .foregroundStyle(isLiked ? .red : .secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                    Text("\(post.comments)")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Spacer()

                Button(action: {}) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    {
                        #if os(macOS)
                        Color(nsColor: .underPageBackgroundColor)
                        #else
                        Color(.secondarySystemBackground)
                        #endif
                    }()
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 6)
    }

    private var placeholderImage: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.2))
            .frame(width: 100, height: 100)
    }

    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)

        if interval < 60 {
            return NSLocalizedString("teahouse.just_now", comment: "")
        } else if interval < 3600 {
            return String(format: NSLocalizedString("teahouse.minutes_ago", comment: ""), Int(interval / 60))
        } else if interval < 86400 {
            return String(format: NSLocalizedString("teahouse.hours_ago", comment: ""), Int(interval / 3600))
        } else if interval < 604800 {
            return String(format: NSLocalizedString("teahouse.days_ago", comment: ""), Int(interval / 86400))
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd"
            return formatter.string(from: date)
        }
    }
}

struct PostDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    let post: TeahousePost
    
    @State private var commentText = ""
    @State private var isSubmitting = false
    @State private var showLoginPrompt = false
    @State private var comments: [CommentWithProfile] = []
    @State private var isLoadingComments = false
    
    @StateObject private var teahouseService = TeahouseService()
    
    @Query var userLikes: [UserLike]
    
    init(post: TeahousePost) {
        self.post = post
        let postId = post.id
        let userId = AppSettings().username ?? "guest"
        self._userLikes = Query(filter: #Predicate { like in
            like.postId == postId && like.userId == userId
        })
    }
    
    private var isLiked: Bool {
        !userLikes.isEmpty && userLikes.contains { $0.postId == post.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // 帖子标题和内容
                VStack(alignment: .leading, spacing: 8) {
                    Text(post.title)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(post.content)
                        .font(.body)
                        .foregroundStyle(.primary)
                }
                
                // 图片显示
                if !post.images.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(post.images, id: \.self) { imagePath in
                            if let url = URL(string: imagePath) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 180)
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 180)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    case .failure:
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.gray.opacity(0.15))
                                            .frame(height: 180)
                                    @unknown default:
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.gray.opacity(0.15))
                                            .frame(height: 180)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // 互动按钮
                HStack(spacing: 24) {
                    Button(action: {
                        if authViewModel.isAuthenticated {
                            toggleLike()
                        } else {
                            showLoginPrompt = true
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .foregroundStyle(isLiked ? .red : .secondary)
                            Text("\(post.likes)")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                        Text("\(post.comments)")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    
                    Spacer()
                }
                .padding(.top, 8)
                
                Divider()
                    .padding(.vertical, 8)
                
                // 评论区域
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("评论 \(comments.count)")
                            .font(.headline)
                        Spacer()
                        if isLoadingComments {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.8)
                        }
                    }
                    
                    if comments.isEmpty && !isLoadingComments {
                        Text("还没有评论，来抢沙发吧~")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 32)
                    } else {
                        ForEach(rootComments) { commentWithProfile in
                            commentThread(for: commentWithProfile)
                        }
                    }
                }
                
                Spacer(minLength: 40)
            }
            .padding()
        }
        .onAppear {
            loadComments()
        }
        .navigationTitle(post.category ?? "帖子")
        #if os(macOS)
        .background(Color(nsColor: .windowBackgroundColor))
        #else
        .background(Color(.systemGroupedBackground))
        .toolbar(.hidden, for: .tabBar)
        #endif
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                if authViewModel.isAuthenticated {
                    SeparateMessageInputField(text: $commentText, onSendTapped: {
                        submitComment()
                    }, onImageSelected: { image in
                        handleImageSelected(image)
                    })
                } else {
                    SeparateMessageInputField(text: .constant(""))
                }
                
                Spacer()
                    .frame(height: 8)
            }
            .background(Color.clear)
        }
        .alert("请登录", isPresented: $showLoginPrompt) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("需要登录才能进行此操作")
        }
    }
    
    private var rootComments: [CommentWithProfile] {
        comments.filter { $0.comment.parentCommentId == nil }
    }
    
    private var commentChildren: [String: [CommentWithProfile]] {
        Dictionary(grouping: comments.filter { $0.comment.parentCommentId != nil }) { item in
            item.comment.parentCommentId!
        }
    }
    
    private func commentThread(for comment: CommentWithProfile, depth: Int = 0) -> some View {
        let replies = commentChildren[comment.id] ?? []
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                CommentCardView(
                    commentWithProfile: comment,
                    postId: post.id,
                    onCommentChanged: loadComments
                )
                .environmentObject(authViewModel)
                .padding(.leading, depth == 0 ? 0 : 24)
                
                ForEach(replies) { reply in
                    commentThread(for: reply, depth: depth + 1)
                }
            }
        )
    }
    
    private func toggleLike() {
        guard authViewModel.isAuthenticated else {
            showLoginPrompt = true
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
    
    private func loadComments() {
        isLoadingComments = true
        Task {
            do {
                let fetchedComments = try await teahouseService.fetchComments(postId: post.id)
                await MainActor.run {
                    comments = fetchedComments
                    isLoadingComments = false
                }
            } catch {
                await MainActor.run {
                    print("❌ 加载评论失败: \(error.localizedDescription)")
                    isLoadingComments = false
                }
            }
        }
    }
    
    private func handleImageSelected(_ image: UIImage) {
        // 将图片转换为 Base64 或上传到 Supabase Storage，然后插入到评论中
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("❌ 无法获取图片数据")
            return
        }
        
        // 这里可以上传到 Supabase Storage 或直接转换为 Base64 嵌入评论
        let base64String = imageData.base64EncodedString()
        commentText = "[\(base64String)]" // 将图片数据嵌入评论文本
        
        print("✅ 图片已选中，大小: \(imageData.count / 1024)KB")
    }
    
    private func submitComment() {
        print("🔵 submitComment 被调用")
        print("🔵 commentText: '\(commentText)'")
        print("🔵 isAuthenticated: \(authViewModel.isAuthenticated)")
        
        guard !commentText.trimmingCharacters(in: .whitespaces).isEmpty else {
            print("🔴 评论内容为空")
            return
        }
        guard authViewModel.isAuthenticated else {
            print("🔴 用户未登录")
            showLoginPrompt = true
            return
        }
        
        guard let userId = authViewModel.session?.user.id.uuidString else {
            print("🔴 无法获取用户ID")
            return
        }
        
        print("✅ 准备发送评论")
        isSubmitting = true
        let commentContent = commentText
        commentText = ""
        
        Task {
            do {
                let newComment = Comment(
                    id: UUID().uuidString,
                    postId: post.id,
                    userId: userId,
                    parentCommentId: nil,
                    content: commentContent,
                    isAnonymous: false,
                    createdAt: Date()
                )
                
                print("📤 发送评论到 Supabase: \(newComment)")
                
                // 插入评论到 Supabase
                let response = try await supabase
                    .from("comments")
                    .insert(newComment)
                    .execute()
                
                print("✅ 评论发送成功: \(response)")
                
                // 更新本地评论计数并重新加载评论列表
                await MainActor.run {
                    post.comments += 1
                    isSubmitting = false
                    // 重新加载评论列表以显示新评论
                    loadComments()
                }
            } catch {
                await MainActor.run {
                    print("❌ 评论发送失败: \(error.localizedDescription)")
                    isSubmitting = false
                    // 如果失败，恢复评论文本
                    commentText = commentContent
                }
            }
        }
    }
}

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

#Preview {
    TeahouseView()
        .environment(AppSettings())
        .modelContainer(for: [TeahousePost.self, UserLike.self], inMemory: true)
}

// MARK: - VisualEffectBlur
struct VisualEffectBlur: UIViewRepresentable {
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}
