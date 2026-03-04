//
//  TeahouseModerationService.swift
//  CCZUHelper
//
//  Created by Copilot on 2026/3/2.
//

import Foundation
import Supabase

/// 茶楼管理服务 - 负责举报、屏蔽和管理员功能
@MainActor
final class TeahouseModerationService {
    
    // MARK: - Report
    
    /// 举报用户
    func reportUser(reportedId: String, reason: String, details: String? = nil) async throws {
        guard supabase.auth.currentSession != nil else {
            throw AppError.notAuthenticated
        }

        var payload: [String: String] = [
            "reported_id": reportedId,
            "reason": reason,
        ]

        let trimmed = details?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            payload["details"] = trimmed
        }

        _ = try await supabase
            .from("user_reports")
            .insert(payload)
            .execute()
    }
    
    // MARK: - User Block
    
    /// 屏蔽用户
    func blockUser(blockedId: String) async throws {
        guard supabase.auth.currentSession != nil else {
            throw AppError.notAuthenticated
        }

        let payload = ["blocked_id": blockedId]
        do {
            _ = try await supabase
                .from("user_blocks")
                .insert(payload)
                .execute()
        } catch {
            let message = error.localizedDescription.lowercased()
            let isDuplicate = message.contains("duplicate") || message.contains("unique")
            if !isDuplicate {
                throw error
            }
        }

        await MainActor.run {
            NotificationCenter.default.post(name: .teahouseUserBlocked, object: blockedId)
        }
    }

    /// 取消屏蔽用户
    func unblockUser(blockedId: String) async throws {
        _ = try await supabase
            .from("user_blocks")
            .delete()
            .eq("blocked_id", value: blockedId)
            .execute()
    }
    
    /// 加载当前用户屏蔽的用户ID列表
    func loadBlockedUserIds() async -> Set<String> {
        guard supabase.auth.currentSession != nil else {
            return []
        }

        struct BlockedUserRow: Decodable {
            let blockedId: String

            enum CodingKeys: String, CodingKey {
                case blockedId = "blocked_id"
            }
        }

        do {
            let data = try await supabase
                .from("user_blocks")
                .select("blocked_id")
                .execute()
                .data

            let rows = try JSONDecoder().decode([BlockedUserRow].self, from: data)
            return Set(rows.map(\.blockedId))
        } catch {
            return []
        }
    }
    
    /// 获取屏蔽用户详细信息列表
    func fetchBlockedUsers() async throws -> [BlockedUserInfo] {
        struct UserBlockRow: Decodable {
            let blockedId: String
            let createdAt: Date?

            enum CodingKeys: String, CodingKey {
                case blockedId = "blocked_id"
                case createdAt = "created_at"
            }
        }

        struct ProfileRow: Decodable {
            let id: String
            let username: String?
            let avatarUrl: String?

            enum CodingKeys: String, CodingKey {
                case id
                case username
                case avatarUrl = "avatar_url"
            }
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let blockData = try await supabase
            .from("user_blocks")
            .select("blocked_id,created_at")
            .order("created_at", ascending: false)
            .execute()
            .data

        let blockRows = try decoder.decode([UserBlockRow].self, from: blockData)
        let userIds = Array(Set(blockRows.map(\.blockedId)))
        guard !userIds.isEmpty else { return [] }

        let profileRows: [ProfileRow] = try await supabase
            .from("profiles")
            .select("id,username,avatar_url")
            .in("id", values: userIds)
            .execute()
            .value

        let profileMap = Dictionary(uniqueKeysWithValues: profileRows.map { ($0.id, $0) })
        return blockRows.map { row in
            let profile = profileMap[row.blockedId]
            return BlockedUserInfo(
                blockedUserId: row.blockedId,
                username: profile?.username ?? "未知用户",
                avatarUrl: profile?.avatarUrl,
                blockedAt: row.createdAt
            )
        }
    }
    
    // MARK: - Post Block
    
    /// 屏蔽帖子
    func blockPost(postId: String) async throws {
        guard supabase.auth.currentSession != nil else {
            throw AppError.notAuthenticated
        }

        let payload = ["post_id": postId]
        do {
            _ = try await supabase
                .from("post_blocks")
                .insert(payload)
                .execute()
        } catch {
            let message = error.localizedDescription.lowercased()
            let isDuplicate = message.contains("duplicate") || message.contains("unique")
            if !isDuplicate {
                throw error
            }
        }

        await MainActor.run {
            NotificationCenter.default.post(name: .teahousePostBlocked, object: postId)
        }
    }

    /// 取消屏蔽帖子
    func unblockPost(postId: String) async throws {
        _ = try await supabase
            .from("post_blocks")
            .delete()
            .eq("post_id", value: postId)
            .execute()
    }
    
    /// 加载当前用户屏蔽的帖子ID列表
    func loadBlockedPostIds() async -> Set<String> {
        guard supabase.auth.currentSession != nil else {
            return []
        }

        struct BlockedPostRow: Decodable {
            let postId: String

            enum CodingKeys: String, CodingKey {
                case postId = "post_id"
            }
        }

        do {
            let data = try await supabase
                .from("post_blocks")
                .select("post_id")
                .execute()
                .data

            let rows = try JSONDecoder().decode([BlockedPostRow].self, from: data)
            return Set(rows.map(\.postId))
        } catch {
            return []
        }
    }
    
    /// 获取屏蔽帖子详细信息列表
    func fetchBlockedPosts() async throws -> [BlockedPostInfo] {
        struct PostBlockRow: Decodable {
            let postId: String
            let createdAt: Date?

            enum CodingKeys: String, CodingKey {
                case postId = "post_id"
                case createdAt = "created_at"
            }
        }

        struct PostLiteRow: Decodable {
            let id: String?
            let title: String?
            let userId: String?
            let createdAt: Date?
            let profile: WaterfallProfilePreview?

            enum CodingKeys: String, CodingKey {
                case id
                case title
                case userId = "user_id"
                case createdAt = "created_at"
                case profile
            }
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let blockData = try await supabase
            .from("post_blocks")
            .select("post_id,created_at")
            .order("created_at", ascending: false)
            .execute()
            .data

        let blockRows = try decoder.decode([PostBlockRow].self, from: blockData)
        let postIds = Array(Set(blockRows.map(\.postId)))
        guard !postIds.isEmpty else { return [] }

        let postsData = try await supabase
            .from("posts_with_metadata")
            .select("""
                id,
                title,
                user_id,
                created_at,
                profile:profiles!user_id (
                    id,
                    username,
                    avatar_url
                )
            """)
            .in("id", values: postIds)
            .execute()
            .data

        let postRows = try decoder.decode([PostLiteRow].self, from: postsData)
        var postMap: [String: PostLiteRow] = [:]
        for row in postRows {
            guard let id = row.id else { continue }
            postMap[id] = row
        }

        return blockRows.map { row in
            let post = postMap[row.postId]
            return BlockedPostInfo(
                postId: row.postId,
                title: post?.title ?? "已删除帖子",
                author: post?.profile?.username ?? "未知用户",
                createdAt: post?.createdAt,
                blockedAt: row.createdAt
            )
        }
    }
    
    // MARK: - Admin Functions
    
    /// 获取被举报的帖子（管理员功能）
    func fetchReportedPosts() async throws -> [ReportedPost] {
        struct ReportedPostResponse: Codable {
            let id: String
            let userId: String
            let categoryId: Int
            let title: String
            let content: String
            let imageUrls: String?
            let price: Double?
            let isAnonymous: Bool?
            let status: PostStatus
            let createdAt: Date
            let reportCount: Int?
            let profile: WaterfallProfilePreview?
            let reports: [Report]
            
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
                case reportCount = "report_count"
                case profile
                case reports
            }
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let data = try await supabase
            .from("posts")
            .select("""
                *,
                profile:profiles!user_id (
                    id,
                    username,
                    avatar_url
                ),
                reports:reports!post_id (
                    id,
                    reason,
                    created_at
                )
            """)
            .gt("report_count", value: 0)
            .order("report_count", ascending: false)
            .order("created_at", ascending: false)
            .execute()
            .data
        
        let responses = try decoder.decode([ReportedPostResponse].self, from: data)
        
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
                likeCount: nil,
                commentCount: nil,
                rootCommentCount: nil,
                reportCount: response.reportCount
            )
            return ReportedPost(post: post, profile: response.profile, reports: response.reports)
        }
    }
    
    /// 忽略举报（管理员功能）
    func ignoreReport(reportId: String, postId: String) async throws {
        // 1. 删除举报记录
        try await supabase
            .from("reports")
            .delete()
            .eq("id", value: reportId)
            .execute()
        
        // 2. 更新帖子的举报计数（减1）
        try await supabase
            .from("posts")
            .update(["report_count" : 0])
            .eq("id", value: postId)
            .execute()
    }
}
