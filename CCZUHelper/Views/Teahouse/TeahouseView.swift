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
    @Environment(\.colorScheme) private var colorScheme
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
    @Binding var resetPasswordToken: String?
    @State private var showUserProfile = false
    @State private var pushSelectedPostID: String?
    @State private var pendingPushPostID: String?
    @State private var isResolvingPushRoute = false
    @State private var likedPostIDs: Set<String> = []
    @State private var likedPostIDsSyncedUserID: String?
    @AppStorage("teahouse.hasShownInitialLogin") private var hasShownInitialLogin = false

    private static let categories: [CategoryItem] = [
        CategoryItem(id: 0, title: NSLocalizedString("common.all", comment: ""), backendValue: nil),
        CategoryItem(id: 1, title: NSLocalizedString("teahouse.category.study", comment: ""), backendValue: "学习"),
        CategoryItem(id: 2, title: NSLocalizedString("teahouse.category.life", comment: ""), backendValue: "生活"),
        CategoryItem(id: 3, title: NSLocalizedString("teahouse.category.secondhand", comment: ""), backendValue: "二手"),
        CategoryItem(id: 4, title: NSLocalizedString("teahouse.category.confession", comment: ""), backendValue: "表白墙"),
        CategoryItem(id: 5, title: NSLocalizedString("teahouse.category.lost_found", comment: ""), backendValue: "失物招领")
    ]

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

                            ForEach(filteredPosts, id: \.id) { post in
                                Button {
                                    openPostDetailFromPush(postID: post.id)
                                } label: {
                                    PostRow(post: post, isLiked: likedPostIDs.contains(post.id), onLike: {
                                        toggleLike(post)
                                    })
                                    .padding(.horizontal, 16)
                                    .modifier(TeahousePostScrollTransition())
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
                        .padding(.top, ((validBanners.isEmpty || settings.hideTeahouseBanners) ? 0 : 132) + 10)
                    }

                    // Floating banner overlay (below category)
                    if !validBanners.isEmpty && !settings.hideTeahouseBanners {
                        BannerCarousel(banners: validBanners)
                            .padding(.horizontal)
                            .padding(.top, 10)
                            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                    }

                    if isRefreshing {
                        ProgressView()
                            .tint(.primary)
                            .padding(.top, (validBanners.isEmpty || settings.hideTeahouseBanners) ? 60 : 120)
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
                
                #if os(macOS)
                ToolbarItem(placement: .automatic) {
                    UserMenuButton(
                        showUserSettings: authViewModel.isAuthenticated ? $showUserProfile : $showLoginSheet,
                        isAuthenticated: authViewModel.isAuthenticated
                    )
                }
                #else
                ToolbarItem(placement: .topBarTrailing) {
                    UserMenuButton(
                        showUserSettings: authViewModel.isAuthenticated ? $showUserProfile : $showLoginSheet,
                        isAuthenticated: authViewModel.isAuthenticated
                    )
                }
                #endif

                #if os(macOS)
                ToolbarItem(placement: .automatic) {
                    Menu {
                        ForEach(TeahouseView.categories) { category in
                            Button(action: {
                                withAnimation {
                                    selectedCategory = category.id
                                }
                            }) {
                                HStack {
                                    Text(category.title)
                                    if selectedCategory == category.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.title3)
                    }
                }
                #else
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(TeahouseView.categories) { category in
                            Button(action: {
                                withAnimation {
                                    selectedCategory = category.id
                                }
                            }) {
                                HStack {
                                    Text(category.title)
                                    if selectedCategory == category.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.title3)
                    }
                }
                #endif
            }
            #if os(macOS)
            .background(Color(nsColor: .windowBackgroundColor))
            #else
            .background(
                (colorScheme == .dark ? Color(.systemGroupedBackground) : Color.white)
                    .ignoresSafeArea()
            )
            #endif
            .sheet(isPresented: $showCreatePost) {
                CreatePostView()
                    .environment(settings)
            }
            .sheet(isPresented: $showLoginSheet) {
                TeahouseLoginView(resetPasswordToken: $resetPasswordToken)
                    .environmentObject(authViewModel)
            }
            .sheet(isPresented: $showUserProfile) {
                TeahouseUserProfileView()
                    .environmentObject(authViewModel)
            }
            .onChange(of: authViewModel.session) { _, newSession in
                if newSession == nil {
                    // 用户注销或注销账户时，关闭用户资料页
                    showUserProfile = false
                }
                reloadLikedPostIDs(for: newSession?.user.id.uuidString)
            }
            .task {
                await loadTeahouseContent()
            }
            .onReceive(NotificationCenter.default.publisher(for: .teahouseUserBlocked)) { _ in
                Task {
                    await loadTeahouseContent(force: true)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .teahousePostBlocked)) { _ in
                Task {
                    await loadTeahouseContent(force: true)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .teahouseOpenPostFromPush)) { notification in
                guard let postID = notification.object as? String, !postID.isEmpty else { return }
                pendingPushPostID = postID
                Task {
                    await resolvePendingPushRouteIfNeeded()
                }
            }
            .onAppear {
                // 初次进入页面且未登录时弹出登录
                if !authViewModel.isAuthenticated && !hasShownInitialLogin {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showLoginSheet = true
                        hasShownInitialLogin = true
                    }
                }
                // 如果外部通过 deep link 提供了 reset token，直接弹出登录/重置密码界面
                if let token = resetPasswordToken, !token.isEmpty {
                    showLoginSheet = true
                }
                consumePendingPushPostIfNeeded()
                Task {
                    await resolvePendingPushRouteIfNeeded()
                }
                reloadLikedPostIDs(for: authViewModel.session?.user.id.uuidString)
            }
            .onChange(of: allPosts.count) { _, _ in
                Task {
                    await resolvePendingPushRouteIfNeeded()
                }
            }
            .refreshable { await loadTeahouseContent(force: true, showRefreshIndicator: true) }
            #if os(macOS)
            .sheet(
                isPresented: Binding(
                    get: { pushSelectedPostID != nil },
                    set: { if !$0 { pushSelectedPostID = nil } }
                )
            ) { postDetailCoverContent }
            #else
            .fullScreenCover(
                isPresented: Binding(
                    get: { pushSelectedPostID != nil },
                    set: { if !$0 { pushSelectedPostID = nil } }
                )
            ) { postDetailCoverContent }
            #endif
        }
    }

    @ViewBuilder private var postDetailCoverContent: some View {
        NavigationStack {
            Group {
                if let postID = pushSelectedPostID,
                   let post = allPosts.first(where: { $0.id == postID }) {
                    PostDetailView(post: post)
                        .environmentObject(authViewModel)
                } else {
                    ContentUnavailableView {
                        Label("teahouse.load_failed".localized, systemImage: "exclamationmark.triangle")
                    } description: {
                        Text("teahouse.no_posts_hint".localized)
                    } actions: {
                        Button("teahouse.retry".localized) {
                            Task {
                                if let postID = pushSelectedPostID {
                                    pendingPushPostID = postID
                                    await resolvePendingPushRouteIfNeeded()
                                }
                            }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        pushSelectedPostID = nil
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }

    private var toolbarContent: some ToolbarContent {
        Group {
            #if os(macOS)
            ToolbarItem(placement: .automatic) {
                UserMenuButton(
                    showUserSettings: authViewModel.isAuthenticated ? $showUserProfile : $showLoginSheet,
                    isAuthenticated: authViewModel.isAuthenticated
                )
            }
            #else
            ToolbarItem(placement: .navigationBarTrailing) {
                UserMenuButton(
                    showUserSettings: authViewModel.isAuthenticated ? $showUserProfile : $showLoginSheet,
                    isAuthenticated: authViewModel.isAuthenticated
                )
            }
            #endif

            ToolbarItem(placement: .primaryAction) {
                Button(action: handleCreatePost) {
                    Image(systemName: "square.and.pencil")
                }
            }

            #if os(macOS)
            ToolbarItem(placement: .automatic) {
                Menu {
                    ForEach(TeahouseView.categories) { category in
                        Button(action: {
                            withAnimation {
                                selectedCategory = category.id
                            }
                        }) {
                            HStack {
                                Text(category.title)
                                if selectedCategory == category.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.title3)
                }
            }
            #else
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    ForEach(TeahouseView.categories) { category in
                        Button(action: {
                            withAnimation {
                                selectedCategory = category.id
                            }
                        }) {
                            HStack {
                                Text(category.title)
                                if selectedCategory == category.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.title3)
                }
            }
            #endif
        }
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

    private func consumePendingPushPostIfNeeded() {
        guard let postID = TeahousePushRouteManager.consumePendingPostID() else { return }
        pendingPushPostID = postID
    }

    private func openPostDetailFromPush(postID: String) {
        if pushSelectedPostID == postID {
            pushSelectedPostID = nil
            DispatchQueue.main.async {
                pushSelectedPostID = postID
            }
        } else {
            pushSelectedPostID = postID
        }
    }

    @MainActor
    private func resolvePendingPushRouteIfNeeded() async {
        guard let postID = pendingPushPostID, !postID.isEmpty else { return }
        guard !isResolvingPushRoute else { return }
        isResolvingPushRoute = true
        defer { isResolvingPushRoute = false }

        if allPosts.contains(where: { $0.id == postID }) {
            openPostDetailFromPush(postID: postID)
            pendingPushPostID = nil
            return
        }

        await loadTeahouseContent(force: true)
        if allPosts.contains(where: { $0.id == postID }) {
            openPostDetailFromPush(postID: postID)
            pendingPushPostID = nil
        }
    }

    private var filteredPosts: [TeahousePost] {
        var posts = allPosts
        
        guard selectedCategory < TeahouseView.categories.count else { return posts }
        if let backendValue = TeahouseView.categories[selectedCategory].backendValue {
            posts = posts.filter { $0.category == backendValue }
        }
        
        return posts
    }

    private var validBanners: [ActiveBanner] {
        banners.filter { $0.isActive == true }
    }

    private func reloadLikedPostIDs(for userId: String?) {
        guard let userId, !userId.isEmpty else {
            if !likedPostIDs.isEmpty {
                likedPostIDs = []
            }
            likedPostIDsSyncedUserID = nil
            return
        }

        // Avoid duplicate fetches when both onAppear and session-change fire for the same user.
        guard likedPostIDsSyncedUserID != userId else { return }

        let descriptor = FetchDescriptor<UserLike>(
            predicate: #Predicate<UserLike> { like in
                like.userId == userId
            }
        )

        do {
            let likes = try modelContext.fetch(descriptor)
            let nextIDs = Set(likes.map(\.postId))
            if nextIDs != likedPostIDs {
                likedPostIDs = nextIDs
            }
            likedPostIDsSyncedUserID = userId
        } catch {
            if !likedPostIDs.isEmpty {
                likedPostIDs = []
            }
            likedPostIDsSyncedUserID = nil
        }
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
        let existingRemotePosts = allPosts.filter { !$0.isLocal }
        var existingByID: [String: TeahousePost] = Dictionary(
            uniqueKeysWithValues: existingRemotePosts.map { ($0.id, $0) }
        )
        var remoteIDs = Set<String>()
        var didMutate = false

        for wp in remotePosts {
            let p = wp.post
            guard let remoteID = p.id, !remoteID.isEmpty else { continue }
            remoteIDs.insert(remoteID)

            let isAnonymous = p.isAnonymous ?? false
            let authorName = isAnonymous
                ? NSLocalizedString("create_post.anonymous_user", comment: "")
                : (wp.profile?.username ?? NSLocalizedString("common.user", comment: ""))
            let images = p.imageUrlsArray
            let categoryName = mapCategoryIdToBackend(p.categoryId)

            if let existing = existingByID[remoteID] {
                existing.type = "post"
                existing.author = authorName
                existing.authorId = isAnonymous ? nil : p.userId
                existing.authorAvatarUrl = isAnonymous ? nil : wp.profile?.avatarUrl
                existing.category = categoryName
                existing.price = p.price
                existing.title = p.title ?? ""
                existing.content = p.content ?? ""
                existing.images = images
                existing.likes = p.likeCount ?? 0
                existing.comments = p.commentCount ?? 0
                if let createdAt = p.createdAt {
                    existing.createdAt = createdAt
                }
                existing.isLocal = false
                existing.isAuthorPrivileged = isAnonymous ? nil : wp.profile?.isPrivilege
                existing.syncStatus = .synced
            } else {
                let model = TeahousePost(
                    id: remoteID,
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
                    isAuthorPrivileged: isAnonymous ? nil : wp.profile?.isPrivilege,
                    syncStatus: .synced
                )
                modelContext.insert(model)
            }
            didMutate = true
            existingByID.removeValue(forKey: remoteID)
        }

        for stalePost in existingByID.values where !remoteIDs.contains(stalePost.id) {
            modelContext.delete(stalePost)
            didMutate = true
        }

        if didMutate {
            try modelContext.save()
        }
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
        let isCurrentlyLiked = likedPostIDs.contains(postId)
        
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
                    await MainActor.run {
                        _ = likedPostIDs.remove(postId)
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
                    await MainActor.run {
                        _ = likedPostIDs.insert(postId)
                    }
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

private struct TeahousePostScrollTransition: ViewModifier {
    @Environment(AppSettings.self) private var settings
    @State private var wasInIdentityZone = false

    func body(content: Content) -> some View {
        if #available(iOS 17.0, visionOS 1.0, *) {
            content.scrollTransition(.interactive, axis: .vertical) { view, phase in
                view
                    .scaleEffect(phase.isIdentity ? 1 : 0.6)
                    .opacity(phase.isIdentity ? 1 : 0.4)
            }
            .background(identityZoneDetector)
        } else {
            content
        }
    }

    @ViewBuilder
    private var identityZoneDetector: some View {
        #if os(iOS)
        GeometryReader { proxy in
            Color.clear
                .onAppear {
                    updateIdentityZoneState(with: proxy.frame(in: .global).midY)
                }
                .onChange(of: proxy.frame(in: .global).midY) { _, newMidY in
                    updateIdentityZoneState(with: newMidY)
                }
        }
        #else
        EmptyView()
        #endif
    }

    private func updateIdentityZoneState(with midY: CGFloat) {
        #if os(iOS)
        let screenCenterY = UIScreen.main.bounds.midY
        let identityZoneHalfHeight: CGFloat = 28
        let isInIdentityZone = abs(midY - screenCenterY) <= identityZoneHalfHeight

        if isInIdentityZone && !wasInIdentityZone && settings.enableTeahousePostCardHaptic {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }

        wasInIdentityZone = isInIdentityZone
        #endif
    }
}


#if DEBUG
struct TeahouseView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State var token: String? = nil
        var body: some View {
            TeahouseView(resetPasswordToken: $token)
        }
    }
    static var previews: some View {
        PreviewWrapper()
    }
}
#endif
