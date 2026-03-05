//
//  TeahouseCommentService.swift
//  CCZUHelper
//
//  Created by Copilot on 2026/3/2.
//

import Foundation
import Supabase

/// 茶楼评论服务 - 负责评论的CRUD操作
@MainActor
final class TeahouseCommentService {
    
    // MARK: - Comment Fetching
    
    /// 获取帖子评论
    func fetchComments(postId: String, blockedUserIds: Set<String>) async throws -> [CommentWithProfile] {
        struct CommentResponse: Codable {
            let id: String
            let postId: String?
            let userId: String?
            let parentCommentId: String?
            let content: String
            let photoUrl: String?
            let isAnonymous: Bool?
            let createdAt: Date?
            let replyCount: Int?
            let profiles: CommentProfilePreview?
            
            enum CodingKeys: String, CodingKey {
                case id
                case postId = "post_id"
                case userId = "user_id"
                case parentCommentId = "parent_comment_id"
                case content
                case photoUrl = "photo_url"
                case isAnonymous = "is_anonymous"
                case createdAt = "created_at"
                case replyCount = "reply_count"
                case profiles
            }
        }
        
        let response: [CommentResponse] = try await supabase
            .from("comments")
            .select("""
                *,
                profiles!user_id (
                    id,
                    username,
                    avatar_url
                )
            """)
            .eq("post_id", value: postId)
            .order("created_at", ascending: true)
            .execute()
            .value

        return response.compactMap { resp in
            if let userId = resp.userId, blockedUserIds.contains(userId) {
                return nil
            }

            let comment = Comment(
                id: resp.id,
                postId: resp.postId,
                userId: resp.userId,
                parentCommentId: resp.parentCommentId,
                content: resp.content,
                photoUrl: resp.photoUrl,
                isAnonymous: resp.isAnonymous,
                createdAt: resp.createdAt
            )
            return CommentWithProfile(comment: comment, profile: resp.profiles)
        }
    }
    
    // MARK: - Comment Creation & Update
    
    /// 添加评论
    func addComment(
        postId: String,
        content: String,
        userId: String,
        parentCommentId: String? = nil,
        isAnonymous: Bool = false,
        photoUrl: String? = nil
    ) async throws -> Comment {
        struct InsertComment: Codable {
            let postId: String
            let content: String
            let userId: String
            let parentCommentId: String?
            let isAnonymous: Bool
            let photoUrl: String?
            
            enum CodingKeys: String, CodingKey {
                case postId = "post_id"
                case content
                case userId = "user_id"
                case parentCommentId = "parent_comment_id"
                case isAnonymous = "is_anonymous"
                case photoUrl = "photo_url"
            }
        }
        
        let newComment = InsertComment(
            postId: postId,
            content: content,
            userId: userId,
            parentCommentId: parentCommentId,
            isAnonymous: isAnonymous,
            photoUrl: photoUrl
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
}
