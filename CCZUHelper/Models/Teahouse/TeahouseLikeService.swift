//
//  TeahouseLikeService.swift
//  CCZUHelper
//
//  Created by Copilot on 2026/3/2.
//

import Foundation
import Supabase

/// 茶楼点赞服务 - 负责点赞相关操作
@MainActor
final class TeahouseLikeService {
    
    // MARK: - Post Like
    
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
                    profile:profiles!user_id (
                        id,
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
        
        // 去重
        var uniquePosts: [String: WaterfallPost] = [:]
        for item in response {
            if let postResp = item.posts, let postId = postResp.id {
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
                    rootCommentCount: postResp.rootCommentCount,
                    reportCount: postResp.reportCount
                )
                uniquePosts[postId] = WaterfallPost(post: post, profile: postResp.profile)
            }
        }
        
        return Array(uniquePosts.values)
    }
    
    // MARK: - Comment Like
    
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
                    profile:profiles!user_id (
                        id,
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
        
        // 去重
        var uniquePosts: [String: WaterfallPost] = [:]
        for item in response {
            if let postResp = item.posts, let postId = postResp.id {
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
                    rootCommentCount: postResp.rootCommentCount,
                    reportCount: postResp.reportCount
                )
                uniquePosts[postId] = WaterfallPost(post: post, profile: postResp.profile)
            }
        }
        
        return Array(uniquePosts.values)
    }
}
