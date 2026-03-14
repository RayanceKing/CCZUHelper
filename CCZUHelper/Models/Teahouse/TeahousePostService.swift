//
//  TeahousePostService.swift
//  CCZUHelper
//
//  Created by Copilot on 2026/3/2.
//

import Foundation
import Supabase

/// 茶楼帖子服务 - 负责帖子的CRUD操作
@MainActor
final class TeahousePostService {
    
    // MARK: - Post Fetching
    
    /// 获取瀑布流帖子数据
    func fetchWaterfallPosts(
        status: [PostStatus] = [.available, .sold],
        blockedUserIds: Set<String>,
        blockedPostIds: Set<String>
    ) async throws -> [WaterfallPost] {
        // 查询 posts_with_metadata 视图并关联 profiles
        let data = try await supabase
            .from("posts_with_metadata")
            .select("""
                *,
                profile:profiles!user_id (
                    id,
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

        // 从 posts 表中查询这些帖子是否被封禁
        let ids = fetchedPosts.compactMap { $0.id }
        var blockedIds = Set<String>()
        if !ids.isEmpty {
            struct BlockedItem: Codable {
                let id: String
                let isBlocked: Bool
                
                enum CodingKeys: String, CodingKey {
                    case id
                    case isBlocked = "is_blocked"
                }
            }

            do {
                let blockedData = try await supabase
                    .from("posts")
                    .select("id,is_blocked")
                    .in("id", values: ids)
                    .eq("is_blocked", value: true)
                    .execute()
                    .data
                
                let blockedItems = try JSONDecoder().decode([BlockedItem].self, from: blockedData)
                blockedIds = Set(blockedItems.map(\.id))
            } catch {
                print("⚠️ 查询帖子封禁状态失败: \(error)")
            }
        }

        // 过滤掉已被封禁的帖子
        let visiblePosts = fetchedPosts.filter { post in
            guard let id = post.id else { return true }
            if blockedIds.contains(id) {
                return false
            }
            if blockedPostIds.contains(id) {
                return false
            }
            if let authorId = post.post.userId, blockedUserIds.contains(authorId) {
                return false
            }
            return true
        }

        return visiblePosts
    }
    
    /// 获取单个帖子详情
    func fetchPost(id: String) async throws -> WaterfallPost? {
        let data = try await supabase
            .from("posts_with_metadata")
            .select("""
                *,
                profile:profiles!user_id (
                    id,
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
    
    /// 获取用户发布的帖子
    func fetchUserPosts(userId: String) async throws -> [WaterfallPost] {
        let data = try await supabase
            .from("posts_with_metadata")
            .select("""
                *,
                profile:profiles!user_id (
                    id,
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
    
    // MARK: - Post Creation & Update
    
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
            let reportCount: Int?
            let profile: WaterfallProfilePreview?
            
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
                case reportCount = "report_count"
                case profile
            }
        }
        
        let responses = try TeahouseDecoding.decode([WaterfallResponse].self, from: data)
        
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
                rootCommentCount: response.rootCommentCount,
                reportCount: response.reportCount
            )
            return WaterfallPost(post: post, profile: response.profile)
        }
    }
}
