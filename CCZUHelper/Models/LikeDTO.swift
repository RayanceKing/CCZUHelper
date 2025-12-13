//
//  LikeDTO.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/14.
//

import Foundation

/// 茶楼点赞数据传输对象 - 用于 Supabase API 请求
struct LikeDTO: Codable {
    let postId: UUID
    let userId: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case userId = "user_id"
        case createdAt = "created_at"
    }
}
