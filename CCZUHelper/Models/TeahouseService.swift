//
//  TeahouseService.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/14.
//  茶楼数据服务层

import Foundation
import Supabase
import Combine

enum AppError: Error {
    case imageConversionFailed
    case urlGenerationFailed
    case notAuthenticated
}

/// 茶楼数据服务
@MainActor
class TeahouseService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var posts: [WaterfallPost] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    // MARK: - Private Properties
    
    private var realtimeChannel: RealtimeChannelV2?
    private var postgresUpdateSubscription: RealtimeSubscription? // New property to store the subscription
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {}
    
    deinit {
        Task { @MainActor [weak self] in
            await self?.stopRealtimeSubscription()
        }
    }
    
    // MARK: - Data Fetching
    
    /// 获取瀑布流帖子数据
    func fetchWaterfallPosts(status: [PostStatus] = [.available, .sold]) async throws -> [WaterfallPost] { // Changed return type
        isLoading = true
        defer { isLoading = false }
        
        do {
            // 查询 posts_with_metadata 视图并关联 profiles
            let data = try await supabase
                .from("posts_with_metadata")
                .select("""
                    *,
                    profile:profiles!user_id (
                        username,
                        avatar_url
                    )
                """)
                .in("status", values: status.map { $0.rawValue })
                .order("created_at", ascending: false)
                .execute()
                .data
            
            // 解析响应
            let fetchedPosts = try parseWaterfallPostsFromData(data)
            posts = fetchedPosts // Update the published property
            return fetchedPosts // Return the fetched posts
            
        } catch {
            self.error = error
            throw error
        }
    }
    
    /// 获取单个帖子详情
    func fetchPost(id: String) async throws -> WaterfallPost? {
        let data = try await supabase
            .from("posts_with_metadata")
            .select("""
                *,
                profile:profiles!user_id (
                    username,
                    avatar_url
                )
            """)
            .eq("id", value: id)
            .limit(1)
            .execute()
            .data
        
        let posts = try parseWaterfallPostsFromData(data)
        return posts.first
    }
    
    /// 获取帖子评论
    func fetchComments(postId: String) async throws -> [CommentWithProfile] {
        struct CommentResponse: Codable {
            let id: String
            let postId: String?
            let userId: String?
            let parentCommentId: String?
            let content: String
            let isAnonymous: Bool?
            let createdAt: Date?
            let profiles: Profile?
            
            enum CodingKeys: String, CodingKey {
                case id
                case postId = "post_id"
                case userId = "user_id"
                case parentCommentId = "parent_comment_id"
                case content
                case isAnonymous = "is_anonymous"
                case createdAt = "created_at"
                case profiles
            }
        }
        
        let response: [CommentResponse] = try await supabase
            .from("comments")
            .select("""
                *,
                profiles!user_id (*)
            """)
            .eq("post_id", value: postId)
            .order("created_at", ascending: true)
            .execute()
            .value
        
        return response.map { resp in
            let comment = Comment(
                id: resp.id,
                postId: resp.postId,
                userId: resp.userId,
                parentCommentId: resp.parentCommentId,
                content: resp.content,
                isAnonymous: resp.isAnonymous,
                createdAt: resp.createdAt
            )
            return CommentWithProfile(comment: comment, profile: resp.profiles)
        }
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
        struct InsertPost: Codable {
            let id: String?
            let title: String
            let content: String
            let categoryId: Int
            let imageUrls: String?
            let price: Double?
            let isAnonymous: Bool
            let userId: String
            let status: PostStatus
            
            enum CodingKeys: String, CodingKey {
                case id
                case title
                case content
                case categoryId = "category_id"
                case imageUrls = "image_urls"
                case price
                case isAnonymous = "is_anonymous"
                case userId = "user_id"
                case status
            }
        }
        
        // 将图片 URL 数组转换为 JSON 字符串
        var imageUrlsString: String?
        if let urls = imageUrls, !urls.isEmpty {
            let data = try JSONEncoder().encode(urls)
            imageUrlsString = String(data: data, encoding: .utf8)
        }
        
        guard let userId = supabase.auth.currentSession?.user.id.uuidString else {
            throw NSError(domain: "TeahouseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "未登录"])
        }
        
        let newPost = InsertPost(
            id: id,
            title: title,
            content: content,
            categoryId: categoryId,
            imageUrls: imageUrlsString,
            price: price,
            isAnonymous: isAnonymous,
            userId: userId,
            status: .available
        )
        
        let response: TeahousePostDTO = try await supabase
            .from("posts")
            .insert(newPost)
            .select()
            .single()
            .execute()
            .value
        
        return response
    }

    /// 上传帖子图片到 Storage，并返回公共 URL 列表
    func uploadPostImages(imageData: [Data], postId: String, userId: String) async throws -> [String] {
        var urls: [String] = []

        for data in imageData {
            let fileName = "\(UUID().uuidString).jpeg"
            let path = "user_uploads/\(userId)/\(postId)/\(fileName)"

            try await supabase.storage
                .from("post_images")
                .upload(path, data: data, options: FileOptions(contentType: "image/jpeg"))

            let publicURL = try supabase.storage.from("post_images").getPublicURL(path: path).absoluteString
            if publicURL.isEmpty {
                throw AppError.urlGenerationFailed
            }
            urls.append(publicURL)
        }

        return urls
    }

    /// 上传头像并更新 profiles.avatar_url 字段
    func uploadAvatarImage(userId: String, imageData: Data) async throws -> String {
        let path = "\(userId)/avatar.jpeg"

        try await supabase.storage
            .from("avatars")
            .upload(path, data: imageData, options: FileOptions(contentType: "image/jpeg", upsert: true))

        let publicURL = try supabase.storage.from("avatars").getPublicURL(path: path).absoluteString
        if publicURL.isEmpty {
            throw AppError.urlGenerationFailed
        }

        try await supabase
            .from("profiles")
            .update(["avatar_url": publicURL])
            .eq("id", value: userId)
            .execute()

        return publicURL
    }
    
    /// 更新帖子状态
    func updatePostStatus(id: String, status: PostStatus) async throws {
        struct UpdateStatus: Codable {
            let status: PostStatus
        }
        
        try await supabase
            .from("posts")
            .update(UpdateStatus(status: status))
            .eq("id", value: id)
            .execute()
        
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
                rootCommentCount: updatedPost.rootCommentCount
            )
            posts[index] = WaterfallPost(post: updatedPost, profile: posts[index].profile)
        }
    }
    
    /// 获取用户发布的帖子
    func fetchUserPosts(userId: String) async throws -> [WaterfallPost] {
        let data = try await supabase
            .from("posts_with_metadata")
            .select("""
                *,
                profile:profiles!user_id (
                    username,
                    avatar_url
                )
            """)
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .data
        
        return try parseWaterfallPostsFromData(data)
    }
    
    /// 获取用户点赞的帖子
    func fetchUserLikedPosts(userId: String) async throws -> [WaterfallPost] {
        struct LikeWithPost: Codable {
            let postId: String?
            let posts: PostResponse?
            
            struct PostResponse: Codable {
                let id: String?
                let userId: String?
                let categoryId: Int?
                let title: String?
                let content: String?
                let imageUrls: String?
                let price: Double?
                let isAnonymous: Bool?
                let status: PostStatus?
                let createdAt: Date?
                let likeCount: Int?
                let commentCount: Int?
                let rootCommentCount: Int?
                let profiles: WaterfallProfilePreview?
                
                enum CodingKeys: String, CodingKey {
                    case id
                    case userId = "user_id"
                    case categoryId = "category_id"
                    case title
                    case content
                    case imageUrls = "image_urls"
                    case price
                    case isAnonymous = "is_anonymous"
                    case status
                    case createdAt = "created_at"
                    case likeCount = "like_count"
                    case commentCount = "comment_count"
                    case rootCommentCount = "root_comment_count"
                    case profiles
                }
            }
            
            enum CodingKeys: String, CodingKey {
                case postId = "post_id"
                case posts
            }
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let data = try await supabase
            .from("likes")
            .select("""
                post_id,
                posts:posts_with_metadata!post_id (
                    *,
                    profiles!user_id (
                        username,
                        avatar_url
                    )
                )
            """)
            .eq("user_id", value: userId)
            .not("post_id", operator: .is, value: "null")
            .order("created_at", ascending: false)
            .execute()
            .data
        
        let response = try decoder.decode([LikeWithPost].self, from: data)
        
        // 去重（用户可能多次点赞同一个帖子）
        var uniquePosts: [String: WaterfallPost] = [:]
        for item in response {
            if let postResp = item.posts, let postId = postResp.id {
                if uniquePosts[postId] == nil {
                    let post = PostWithMetadata(
                        id: postResp.id,
                        userId: postResp.userId,
                        categoryId: postResp.categoryId,
                        title: postResp.title,
                        content: postResp.content,
                        imageUrls: postResp.imageUrls,
                        price: postResp.price,
                        isAnonymous: postResp.isAnonymous,
                        status: postResp.status,
                        createdAt: postResp.createdAt,
                        likeCount: postResp.likeCount,
                        commentCount: postResp.commentCount,
                        rootCommentCount: postResp.rootCommentCount
                    )
                    uniquePosts[postId] = WaterfallPost(post: post, profile: postResp.profiles)
                }
            }
        }
        
        return Array(uniquePosts.values)
    }
    
    /// 获取用户评论过的帖子
    func fetchUserCommentedPosts(userId: String) async throws -> [WaterfallPost] {
        struct CommentWithPost: Codable {
            let postId: String?
            let posts: PostResponse?
            
            struct PostResponse: Codable {
                let id: String?
                let userId: String?
                let categoryId: Int?
                let title: String?
                let content: String?
                let imageUrls: String?
                let price: Double?
                let isAnonymous: Bool?
                let status: PostStatus?
                let createdAt: Date?
                let likeCount: Int?
                let commentCount: Int?
                let rootCommentCount: Int?
                let profiles: WaterfallProfilePreview?
                
                enum CodingKeys: String, CodingKey {
                    case id
                    case userId = "user_id"
                    case categoryId = "category_id"
                    case title
                    case content
                    case imageUrls = "image_urls"
                    case price
                    case isAnonymous = "is_anonymous"
                    case status
                    case createdAt = "created_at"
                    case likeCount = "like_count"
                    case commentCount = "comment_count"
                    case rootCommentCount = "root_comment_count"
                    case profiles
                }
            }
            
            enum CodingKeys: String, CodingKey {
                case postId = "post_id"
                case posts
            }
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let data = try await supabase
            .from("comments")
            .select("""
                post_id,
                posts:posts_with_metadata!post_id (
                    *,
                    profiles!user_id (
                        username,
                        avatar_url
                    )
                )
            """)
            .eq("user_id", value: userId)
            .not("post_id", operator: .is, value: "null")
            .order("created_at", ascending: false)
            .execute()
            .data
        
        let response = try decoder.decode([CommentWithPost].self, from: data)
        
        // 去重（用户可能多次评论同一个帖子）
        var uniquePosts: [String: WaterfallPost] = [:]
        for item in response {
            if let postResp = item.posts, let postId = postResp.id {
                if uniquePosts[postId] == nil {
                    let post = PostWithMetadata(
                        id: postResp.id,
                        userId: postResp.userId,
                        categoryId: postResp.categoryId,
                        title: postResp.title,
                        content: postResp.content,
                        imageUrls: postResp.imageUrls,
                        price: postResp.price,
                        isAnonymous: postResp.isAnonymous,
                        status: postResp.status,
                        createdAt: postResp.createdAt,
                        likeCount: postResp.likeCount,
                        commentCount: postResp.commentCount,
                        rootCommentCount: postResp.rootCommentCount
                    )
                    uniquePosts[postId] = WaterfallPost(post: post, profile: postResp.profiles)
                }
            }
        }
        
        return Array(uniquePosts.values)
    }

    /// 更新或创建用户资料，支持头像上传与昵称更新
    func upsertProfile(
        userId: String,
        nickname: String,
        realName: String,
        studentId: String,
        className: String,
        grade: Int,
        collegeName: String,
        avatarImageData: Data?
    ) async throws -> Profile {
        var avatarUrl: String?
        if let data = avatarImageData {
            avatarUrl = try await uploadAvatarImage(userId: userId, imageData: data)
        }
        
        struct ProfileInput: Encodable {
            let id: String
            let realName: String
            let studentId: String
            let className: String
            let collegeName: String
            let grade: Int
            let username: String
            let avatarUrl: String?
            
            enum CodingKeys: String, CodingKey {
                case id
                case realName = "real_name"
                case studentId = "student_id"
                case className = "class_name"
                case collegeName = "college_name"
                case grade
                case username
                case avatarUrl = "avatar_url"
            }
        }
        
        let input = ProfileInput(
            id: userId,
            realName: realName,
            studentId: studentId,
            className: className,
            collegeName: collegeName,
            grade: grade,
            username: nickname,
            avatarUrl: avatarUrl
        )
        
        let profile: Profile = try await supabase
            .from("profiles")
            .upsert(input)
            .select()
            .single()
            .execute()
            .value
        
        return profile
    }
    
    /// 点赞/取消点赞帖子
    func toggleLike(postId: String, userId: String) async throws {
        // 检查是否已点赞
        let existing: [Like] = try await supabase
            .from("likes")
            .select()
            .eq("post_id", value: postId)
            .eq("user_id", value: userId)
            .execute()
            .value
        
        if let existingLike = existing.first {
            // 取消点赞
            try await supabase
                .from("likes")
                .delete()
                .eq("id", value: existingLike.id)
                .execute()
        } else {
            // 添加点赞
            struct InsertLike: Codable {
                let postId: String
                let userId: String
                
                enum CodingKeys: String, CodingKey {
                    case postId = "post_id"
                    case userId = "user_id"
                }
            }
            
            try await supabase
                .from("likes")
                .insert(InsertLike(postId: postId, userId: userId))
                .execute()
        }
    }

    /// 检查当前用户是否已点赞指定评论
    func isCommentLiked(commentId: String, userId: String) async throws -> Bool {
        let existing: [Like] = try await supabase
            .from("likes")
            .select()
            .eq("comment_id", value: commentId)
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
        return !existing.isEmpty
    }
    
    /// 点赞/取消点赞评论，返回最新点赞状态
    func toggleCommentLike(commentId: String, userId: String) async throws -> Bool {
        let existing: [Like] = try await supabase
            .from("likes")
            .select()
            .eq("comment_id", value: commentId)
            .eq("user_id", value: userId)
            .execute()
            .value
        
        if let existingLike = existing.first {
            try await supabase
                .from("likes")
                .delete()
                .eq("id", value: existingLike.id)
                .execute()
            return false
        } else {
            struct InsertLike: Codable {
                let commentId: String
                let userId: String
                
                enum CodingKeys: String, CodingKey {
                    case commentId = "comment_id"
                    case userId = "user_id"
                }
            }
            
            try await supabase
                .from("likes")
                .insert(InsertLike(commentId: commentId, userId: userId))
                .execute()
            return true
        }
    }
    
    /// 添加评论
    func addComment(
        postId: String,
        content: String,
        userId: String,
        parentCommentId: String? = nil,
        isAnonymous: Bool = false
    ) async throws -> Comment {
        struct InsertComment: Codable {
            let postId: String
            let content: String
            let userId: String
            let parentCommentId: String?
            let isAnonymous: Bool
            
            enum CodingKeys: String, CodingKey {
                case postId = "post_id"
                case content
                case userId = "user_id"
                case parentCommentId = "parent_comment_id"
                case isAnonymous = "is_anonymous"
            }
        }
        
        let newComment = InsertComment(
            postId: postId,
            content: content,
            userId: userId,
            parentCommentId: parentCommentId,
            isAnonymous: isAnonymous
        )
        
        let response: Comment = try await supabase
            .from("comments")
            .insert(newComment)
            .select()
            .single()
            .execute()
            .value
        
        return response
    }
    
    /// 删除评论
    func deleteComment(commentId: String) async throws {
        try await supabase
            .from("comments")
            .delete()
            .eq("id", value: commentId)
            .execute()
    }

    /// 删除用户在某个帖子下的所有评论
    func deleteCommentsForPost(userId: String, postId: String) async throws {
        try await supabase
            .from("comments")
            .delete()
            .eq("post_id", value: postId)
            .eq("user_id", value: userId)
            .execute()
    }
    
    /// 删除帖子（先清理关联的点赞与评论，避免约束冲突）
    func deletePost(postId: String) async throws {
        // 1. 找出该帖的评论ID
        struct CommentIdOnly: Codable { let id: String }
        let commentIds: [CommentIdOnly] = try await supabase
            .from("comments")
            .select("id")
            .eq("post_id", value: postId)
            .execute()
            .value

        let commentIdList = commentIds.map { $0.id }

        // 2. 先删点赞（针对帖子本身）
        try await supabase
            .from("likes")
            .delete()
            .eq("post_id", value: postId)
            .execute()

        // 3. 再删与评论相关的点赞
        if !commentIdList.isEmpty {
            try await supabase
                .from("likes")
                .delete()
                .in("comment_id", values: commentIdList)
                .execute()
        }

        // 4. 删除评论
        try await supabase
            .from("comments")
            .delete()
            .eq("post_id", value: postId)
            .execute()

        // 5. 最后删除帖子
        try await supabase
            .from("posts")
            .delete()
            .eq("id", value: postId)
            .execute()
    }
    
    // MARK: - Realtime Subscription
    
    /// 开始实时订阅帖子状态变化
    func startRealtimeSubscription() {
        realtimeChannel = supabase.channel("public:posts")
        
        // Capture the RealtimeSubscription to prevent the "Result of call is unused" warning.
        // The TeahouseService is @MainActor, so scheduling on MainActor is appropriate.
        postgresUpdateSubscription = realtimeChannel?.onPostgresChange(
            UpdateAction.self,
            schema: "public",
            table: "posts"
        ) { [weak self] action in
            Task { @MainActor [weak self] in
                await self?.handlePostUpdate(action)
            }
        }
        
        Task {
            // Use subscribeWithError() and handle potential errors.
            do {
                try await realtimeChannel?.subscribeWithError()
            } catch {
                // Handle the error, e.g., log it or set an error property.
                print("Error subscribing to realtime channel: \(error.localizedDescription)")
                self.error = error // Optionally publish the error
            }
        }
    }
    
    /// 停止实时订阅
    func stopRealtimeSubscription() async {
        // Cancel the specific Postgres change subscription
        postgresUpdateSubscription?.cancel()
        postgresUpdateSubscription = nil
        
        // Unsubscribe the entire channel
        await realtimeChannel?.unsubscribe()
        realtimeChannel = nil
    }
    
    /// 处理帖子更新事件
    private func handlePostUpdate(_ action: UpdateAction) async {
        let record = action.record
        
        guard let postId = record["id"]?.value as? String,
              let statusString = record["status"]?.value as? String,
              let newStatus = PostStatus(rawValue: statusString) else {
            return
        }
        
        // 更新本地缓存中的帖子状态
        if let index = posts.firstIndex(where: { $0.id == postId }) {
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
                status: newStatus,
                createdAt: updatedPost.createdAt,
                likeCount: updatedPost.likeCount,
                commentCount: updatedPost.commentCount,
                rootCommentCount: updatedPost.rootCommentCount
            )
            posts[index] = WaterfallPost(post: updatedPost, profile: posts[index].profile)
        }
    }
    
    // MARK: - Helper Methods
    
    /// 解析瀑布流帖子响应
    private func parseWaterfallPostsFromData(_ data: Data) throws -> [WaterfallPost] {
        struct WaterfallResponse: Codable {
            let id: String?
            let userId: String?
            let categoryId: Int?
            let title: String?
            let content: String?
            let imageUrls: String?
            let price: Double?
            let isAnonymous: Bool?
            let status: PostStatus?
            let createdAt: Date?
            let likeCount: Int?
            let commentCount: Int?
            let rootCommentCount: Int?
            let profile: WaterfallProfilePreview? // Now references the top-level struct
            
            enum CodingKeys: String, CodingKey {
                case id
                case userId = "user_id"
                case categoryId = "category_id"
                case title
                case content
                case imageUrls = "image_urls"
                case price
                case isAnonymous = "is_anonymous"
                case status
                case createdAt = "created_at"
                case likeCount = "like_count"
                case commentCount = "comment_count"
                case rootCommentCount = "root_comment_count"
                case profile
            }
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let responses = try decoder.decode([WaterfallResponse].self, from: data)
        
        return responses.map { response in
            let post = PostWithMetadata(
                id: response.id,
                userId: response.userId,
                categoryId: response.categoryId,
                title: response.title,
                content: response.content,
                imageUrls: response.imageUrls,
                price: response.price,
                isAnonymous: response.isAnonymous,
                status: response.status,
                createdAt: response.createdAt,
                likeCount: response.likeCount,
                commentCount: response.commentCount,
                rootCommentCount: response.rootCommentCount
            )
            return WaterfallPost(post: post, profile: response.profile)
        }
    }
}
