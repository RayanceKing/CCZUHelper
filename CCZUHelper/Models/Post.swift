//
//  Post.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/13.
//

import Foundation

struct Post: Identifiable, Codable {
    let id: UUID
    let type: String
    let category: String?
    let title: String
    let content: String
    let images: [String]
    let likeCount: Int
    let commentCount: Int
    let createdAt: Date
    let author: String?
    let authorId: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case category
        case title
        case content
        case images
        case likeCount = "like_count"
        case commentCount = "comment_count"
        case createdAt = "created_at"
        case author
        case authorId = "author_id"
    }
}
