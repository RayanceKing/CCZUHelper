//
//  PostDetailOperations.swift
//  CCZUHelper
//
//  Created by Codex on 2026/2/23.
//

import Foundation
import SwiftData
import Supabase

enum PostDetailOperations {
    @MainActor
    static func fetchLikeStatus(
        modelContext: ModelContext,
        postId: String,
        userId: String
    ) throws -> Bool {
        let descriptor = FetchDescriptor<UserLike>(
            predicate: #Predicate<UserLike> { like in
                like.postId == postId && like.userId == userId
            }
        )
        return try !modelContext.fetch(descriptor).isEmpty
    }

    @MainActor
    static func toggleLike(
        modelContext: ModelContext,
        postId: String,
        userId: String
    ) async throws -> Int {
        let descriptor = FetchDescriptor<UserLike>(
            predicate: #Predicate<UserLike> { like in
                like.userId == userId && like.postId == postId
            }
        )
        let localLike = try modelContext.fetch(descriptor).first

        if let like = localLike {
            _ = try await supabase
                .from("likes")
                .delete()
                .eq("post_id", value: postId)
                .eq("user_id", value: userId)
                .execute()
            modelContext.delete(like)
            try modelContext.save()
            return -1
        } else {
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
            modelContext.insert(UserLike(userId: userId, postId: postId))
            try modelContext.save()
            return 1
        }
    }

    static func fetchComments(
        service: TeahouseService,
        postId: String
    ) async throws -> [CommentWithProfile] {
        try await service.fetchComments(postId: postId)
    }

    static func deleteComment(commentId: String) async throws {
        _ = try await supabase
            .from("comments")
            .delete()
            .eq("id", value: commentId)
            .execute()
    }

    static func submitComment(
        postId: String,
        userId: String,
        content: String,
        isAnonymous: Bool
    ) async throws {
        let newComment = Comment(
            id: UUID().uuidString,
            postId: postId,
            userId: userId,
            parentCommentId: nil,
            content: content,
            isAnonymous: isAnonymous,
            createdAt: Date()
        )
        _ = try await supabase
            .from("comments")
            .insert(newComment)
            .execute()
    }
}

