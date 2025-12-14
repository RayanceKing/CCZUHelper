//
//  TeahouseModels.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/14.
//  根据 Supabase 数据库类型定义生成的模型

import Foundation

// MARK: - Enums

/// 帖子状态枚举（对应数据库 post_status enum）
enum PostStatus: String, Codable, CaseIterable {
    case available
    case sold
    case pending
    case archived
}

// MARK: - Database Tables

/// 用户资料（对应 profiles 表）
struct Profile: Codable, Identifiable {
    let id: String
    let realName: String
    let studentId: String
    let className: String
    let collegeName: String
    let grade: Int
    let username: String
    let avatarUrl: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case realName = "real_name"
        case studentId = "student_id"
        case className = "class_name"
        case collegeName = "college_name"
        case grade
        case username
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
    }
}

/// 分类（对应 categories 表）
struct Category: Codable, Identifiable {
    let id: Int
    let name: String
}

/// 帖子（对应 posts 表）
struct TeahousePostDTO: Codable, Identifiable {
    let id: String
    let userId: String
    let categoryId: Int
    let title: String
    let content: String
    /// 注意：数据库中 image_urls 是 string 类型，可能是 JSON 字符串
    let imageUrls: String?
    let price: Double?
    let isAnonymous: Bool?
    let status: PostStatus
    let createdAt: Date
    
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
    }
    
    /// 解析 image_urls 为数组
    var imageUrlsArray: [String] {
        guard let imageUrls = imageUrls,
              !imageUrls.isEmpty else { return [] }
        
        // 尝试作为 JSON 数组解析
        if let data = imageUrls.data(using: .utf8),
           let urls = try? JSONDecoder().decode([String].self, from: data) {
            return urls
        }
        
        // 如果是单个 URL，返回包含单个元素的数组
        return [imageUrls]
    }
}

/// 评论（对应 comments 表）
struct Comment: Codable, Identifiable {
    let id: String
    let postId: String?
    let userId: String?
    let parentCommentId: String?
    let content: String
    let isAnonymous: Bool?
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case userId = "user_id"
        case parentCommentId = "parent_comment_id"
        case content
        case isAnonymous = "is_anonymous"
        case createdAt = "created_at"
    }
}

/// 点赞（对应 likes 表）
/// 注意：数据库中没有 created_at 字段
struct Like: Codable, Identifiable {
    let id: String
    let userId: String
    let postId: String?
    let commentId: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case postId = "post_id"
        case commentId = "comment_id"
    }
}

/// 横幅（对应 banners 表）
struct BannerDTO: Codable, Identifiable {
    let id: String
    let title: String
    let content: String?
    let color: String?
    let startDate: Date?
    let endDate: Date?
    let isActive: Bool?
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case content
        case color
        case startDate = "start_date"
        case endDate = "end_date"
        case isActive = "is_active"
        case createdAt = "created_at"
    }
}

// MARK: - Database Views

/// 带元数据的帖子（对应 posts_with_metadata 视图）
struct PostWithMetadata: Codable, Identifiable {
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
    /// 计算字段
    let likeCount: Int?
    let commentCount: Int?
    let rootCommentCount: Int?
    
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
    }
    
    /// 解析 image_urls 为数组
    var imageUrlsArray: [String] {
        guard let imageUrls = imageUrls,
              !imageUrls.isEmpty else { return [] }
        
        if let data = imageUrls.data(using: .utf8),
           let urls = try? JSONDecoder().decode([String].self, from: data) {
            return urls
        }
        
        return [imageUrls]
    }
}

/// 活跃横幅（对应 active_banners 视图）
struct ActiveBanner: Codable, Identifiable {
    let id: String?
    let title: String?
    let content: String?
    let color: String?
    let startDate: Date?
    let endDate: Date?
    let isActive: Bool?
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case content
        case color
        case startDate = "start_date"
        case endDate = "end_date"
        case isActive = "is_active"
        case createdAt = "created_at"
    }
}

// MARK: - Composite Models (for queries with joins)

/// 用户资料预览（只包含必要字段，从 WaterfallPost 中移出为顶级结构）
struct WaterfallProfilePreview: Codable {
    let username: String
    let avatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case username
        case avatarUrl = "avatar_url"
    }
}

/// 瀑布流帖子（包含用户信息）
struct WaterfallPost: Codable, Identifiable {
    let post: PostWithMetadata
    let profile: WaterfallProfilePreview? // Now references the top-level struct
    
    var id: String? { post.id }
}

/// 评论详情（包含用户信息）
struct CommentWithProfile: Codable, Identifiable {
    let comment: Comment
    let profile: Profile?
    
    var id: String { comment.id }
}
