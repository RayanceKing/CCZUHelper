//
//  CommentDTO.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/14.
//

import Foundation

/// 茶楼评论数据传输对象 - 用于 Supabase API 请求
struct CommentDTO: Codable {
    let id: UUID?
    let postId: UUID
    let authorId: String
    let content: String
    let likeCount: Int
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case authorId = "author_id"
        case content
        case likeCount = "like_count"
        case createdAt = "created_at"
    }
}
