//
//  TeahouseService.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/14.
//  茶楼数据服务层 - 主协调器

import Foundation
import Supabase
import Combine

extension Notification.Name {
    static let teahouseUserBlocked = Notification.Name("TeahouseUserBlocked")
    static let teahousePostBlocked = Notification.Name("TeahousePostBlocked")
    static let teahousePostDeleted = Notification.Name("TeahousePostDeleted")
}

enum AppError: Error {
    case imageConversionFailed
    case urlGenerationFailed
    case notAuthenticated
}

/// 茶楼数据服务 - 主协调器，组合各个功能模块
@MainActor
class TeahouseService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var posts: [WaterfallPost] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    // MARK: - Sub-Services
    
    private let postService = TeahousePostService()
    private let commentService = TeahouseCommentService()
    private let likeService = TeahouseLikeService()
    private let userService = TeahouseUserService()
    private let moderationService = TeahouseModerationService()
    private let realtimeService = TeahouseRealtimeService()
    
    private var cancellables = Set<AnyCancellable>()

    private static let commentCacheTTL: TimeInterval = 60
    private static var commentCache: [String: (items: [CommentWithProfile], timestamp: Date)] = [:]
    private static var commentLikeCache: [String: Bool] = [:]
    
    // MARK: - Initialization
    
    init() {
        // 同步实时服务的帖子列表到主服务
        realtimeService.$posts
            .assign(to: &$posts)
    }
    
    deinit {
        Task { @MainActor [weak self] in
            await self?.stopRealtimeSubscription()
        }
    }
    
    // MARK: - Authentication
    
    /// 清除茶楼登陆状态
    func clearTeahouseLoginState() async {
        posts = []
        isLoading = false
        error = nil
        Self.commentCache.removeAll()
        Self.commentLikeCache.removeAll()
        await stopRealtimeSubscription()
    }
    
    // MARK: - Post Operations
    
    /// 获取瀑布流帖子数据
    func fetchWaterfallPosts(status: [PostStatus] = [.available, .sold]) async throws -> [WaterfallPost] {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let blockedUserIds = await moderationService.loadBlockedUserIds()
            let blockedPostIds = await moderationService.loadBlockedPostIds()
            
            let visiblePosts = try await postService.fetchWaterfallPosts(
                status: status,
                blockedUserIds: blockedUserIds,
                blockedPostIds: blockedPostIds
            )
            
            posts = visiblePosts
            realtimeService.posts = visiblePosts
            return visiblePosts
            
        } catch {
            self.error = error
            throw error
        }
    }
    
    /// 获取单个帖子详情
    func fetchPost(id: String) async throws -> WaterfallPost? {
        return try await postService.fetchPost(id: id)
    }
    
    /// 创建新帖子
    func createPost(
        title: String,
        content: String,
        categoryId: Int,
        imageUrls: [String]? = nil,
        price: Double? = nil,
        isAnonymous: Bool = false,
        id: String? = nil
    ) async throws -> TeahousePostDTO {
        return try await postService.createPost(
            title: title,
            content: content,
            categoryId: categoryId,
            imageUrls: imageUrls,
            price: price,
            isAnonymous: isAnonymous,
            id: id
        )
    }
    
    /// 更新帖子状态
    func updatePostStatus(id: String, status: PostStatus) async throws {
        try await postService.updatePostStatus(id: id, status: status)
        
        // 更新本地缓存
        if let index = posts.firstIndex(where: { $0.id == id }) {
            var updatedPost = posts[index].post
            updatedPost = PostWithMetadata(
                id: updatedPost.id,
                userId: updatedPost.userId,
                categoryId: updatedPost.categoryId,
                title: updatedPost.title,
                content: updatedPost.content,
                imageUrls: updatedPost.imageUrls,
                price: updatedPost.price,
                isAnonymous: updatedPost.isAnonymous,
                status: status,
                createdAt: updatedPost.createdAt,
                likeCount: updatedPost.likeCount,
                commentCount: updatedPost.commentCount,
                rootCommentCount: updatedPost.rootCommentCount,
                reportCount: updatedPost.reportCount
            )
            posts[index] = WaterfallPost(post: updatedPost, profile: posts[index].profile)
        }
    }
    
    /// 删除帖子
    func deletePost(postId: String) async throws {
        try await postService.deletePost(postId: postId)
    }
    
    /// 获取用户发布的帖子
    func fetchUserPosts(userId: String) async throws -> [WaterfallPost] {
        return try await postService.fetchUserPosts(userId: userId)
    }
    
    // MARK: - Comment Operations
    
    /// 获取帖子评论
    func fetchComments(postId: String, forceRefresh: Bool = false) async throws -> [CommentWithProfile] {
        if !forceRefresh,
           let cached = Self.commentCache[postId],
           Date().timeIntervalSince(cached.timestamp) < Self.commentCacheTTL {
            return cached.items
        }

        let blockedUserIds = await moderationService.loadBlockedUserIds()
        let comments = try await commentService.fetchComments(postId: postId, blockedUserIds: blockedUserIds)
        Self.commentCache[postId] = (comments, Date())
        return comments
    }
    
    /// 添加评论
    func addComment(
        postId: String,
        content: String,
        userId: String,
        parentCommentId: String? = nil,
        isAnonymous: Bool = false,
        photoUrl: String? = nil
    ) async throws -> Comment {
        let comment = try await commentService.addComment(
            postId: postId,
            content: content,
            userId: userId,
            parentCommentId: parentCommentId,
            isAnonymous: isAnonymous,
            photoUrl: photoUrl
        )
        Self.commentCache.removeValue(forKey: postId)
        return comment
    }
    
    /// 删除评论
    func deleteComment(commentId: String) async throws {
        try await commentService.deleteComment(commentId: commentId)
        // deleteComment 仅有 commentId，无法精确命中 postId，保守清空评论缓存。
        Self.commentCache.removeAll()
    }
    
    /// 删除用户在某个帖子下的所有评论
    func deleteCommentsForPost(userId: String, postId: String) async throws {
        try await commentService.deleteCommentsForPost(userId: userId, postId: postId)
        Self.commentCache.removeValue(forKey: postId)
    }
    
    // MARK: - Like Operations
    
    /// 点赞/取消点赞帖子
    func toggleLike(postId: String, userId: String) async throws {
        try await likeService.toggleLike(postId: postId, userId: userId)
    }
    
    /// 获取用户点赞的帖子
    func fetchUserLikedPosts(userId: String) async throws -> [WaterfallPost] {
        return try await likeService.fetchUserLikedPosts(userId: userId)
    }
    
    /// 检查当前用户是否已点赞指定评论
    func isCommentLiked(commentId: String, userId: String) async throws -> Bool {
        let cacheKey = "\(userId):\(commentId)"
        if let cached = Self.commentLikeCache[cacheKey] {
            return cached
        }

        let liked = try await likeService.isCommentLiked(commentId: commentId, userId: userId)
        Self.commentLikeCache[cacheKey] = liked
        return liked
    }
    
    /// 点赞/取消点赞评论，返回最新点赞状态
    func toggleCommentLike(commentId: String, userId: String) async throws -> Bool {
        let liked = try await likeService.toggleCommentLike(commentId: commentId, userId: userId)
        let cacheKey = "\(userId):\(commentId)"
        Self.commentLikeCache[cacheKey] = liked
        return liked
    }
    
    /// 获取用户评论过的帖子
    func fetchUserCommentedPosts(userId: String) async throws -> [WaterfallPost] {
        return try await likeService.fetchUserCommentedPosts(userId: userId)
    }
    
    // MARK: - User Operations
    
    /// 从服务器获取用户资料
    func fetchProfile(userId: String) async throws -> Profile {
        return try await userService.fetchProfile(userId: userId)
    }
    
    /// 更新用户资料，只允许修改昵称和头像
    func upsertProfile(
        userId: String,
        nickname: String,
        avatarImageData: Data?
    ) async throws -> Profile {
        return try await userService.upsertProfile(
            userId: userId,
            nickname: nickname,
            avatarImageData: avatarImageData
        )
    }
    
    /// 上传帖子图片到图床，并返回外链 URL 列表
    func uploadPostImages(imageFileURLs: [URL]) async throws -> [String] {
        return try await userService.uploadPostImages(imageFileURLs: imageFileURLs)
    }
    
    /// 上传头像并更新 profiles.avatar_url 字段
    func uploadAvatarImage(userId: String, imageData: Data) async throws -> String {
        return try await userService.uploadAvatarImage(userId: userId, imageData: imageData)
    }
    
    // MARK: - Moderation Operations
    
    /// 举报用户
    func reportUser(reportedId: String, reason: String, details: String? = nil) async throws {
        try await moderationService.reportUser(reportedId: reportedId, reason: reason, details: details)
    }
    
    /// 屏蔽用户
    func blockUser(blockedId: String) async throws {
        try await moderationService.blockUser(blockedId: blockedId)
    }
    
    /// 取消屏蔽用户
    func unblockUser(blockedId: String) async throws {
        try await moderationService.unblockUser(blockedId: blockedId)
    }
    
    /// 获取屏蔽用户列表
    func fetchBlockedUsers() async throws -> [BlockedUserInfo] {
        return try await moderationService.fetchBlockedUsers()
    }
    
    /// 屏蔽帖子
    func blockPost(postId: String) async throws {
        try await moderationService.blockPost(postId: postId)
    }
    
    /// 取消屏蔽帖子
    func unblockPost(postId: String) async throws {
        try await moderationService.unblockPost(postId: postId)
    }
    
    /// 获取屏蔽帖子列表
    func fetchBlockedPosts() async throws -> [BlockedPostInfo] {
        return try await moderationService.fetchBlockedPosts()
    }
    
    /// 获取被举报的帖子（管理员功能）
    func fetchReportedPosts() async throws -> [ReportedPost] {
        return try await moderationService.fetchReportedPosts()
    }
    
    /// 忽略举报（管理员功能）
    func ignoreReport(reportId: String, postId: String) async throws {
        try await moderationService.ignoreReport(reportId: reportId, postId: postId)
    }
    
    // MARK: - Realtime Operations
    
    /// 开始实时订阅帖子状态变化
    func startRealtimeSubscription() {
        realtimeService.startRealtimeSubscription()
    }
    
    /// 停止实时订阅
    func stopRealtimeSubscription() async {
        await realtimeService.stopRealtimeSubscription()
    }
}
