//
//  TeahousePost.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/1.
//

import SwiftUI
import SwiftData

/// 茶楼帖子数据模型
@Model
final class TeahousePost {
    @Attribute(.unique) var id: String
    var type: String = "post" // 帖子类型，默认为普通帖子
    var author: String
    var authorId: String?
    var authorAvatarUrl: String?
    var category: String?
    var price: Double?
    var title: String
    var content: String
    var images: [String] // 图片URL或本地路径
    var likes: Int
    var comments: Int
    var reportCount: Int = 0 // 举报次数
    var createdAt: Date
    var isLocal: Bool // 标记是否为本地帖子（未同步到服务器）
    var isAuthorPrivileged: Bool? // 标记作者是否为特权用户
    var syncStatus: SyncStatus // 同步状态
    
    enum SyncStatus: String, Codable {
        case local = "local"
        case syncing = "syncing"
        case synced = "synced"
        case failed = "failed"
        
        var localized: String {
            switch self {
            case .local: return "sync.status.local".localized
            case .syncing: return "sync.status.syncing".localized
            case .synced: return "sync.status.synced".localized
            case .failed: return "sync.status.failed".localized
            }
        }
    }
    
    init(
        id: String = UUID().uuidString,
        type: String = "post",
        author: String,
        authorId: String? = nil,
        authorAvatarUrl: String? = nil,
        category: String? = nil,
        price: Double? = nil,
        title: String,
        content: String,
        images: [String] = [],
        likes: Int = 0,
        comments: Int = 0,
        reportCount: Int = 0,
        createdAt: Date = Date(),
        isLocal: Bool = true,
        isAuthorPrivileged: Bool? = nil,
        syncStatus: SyncStatus = .local
    ) {
        self.id = id
        self.type = type
        self.author = author
        self.authorId = authorId
        self.authorAvatarUrl = authorAvatarUrl
        self.category = category
        self.price = price
        self.title = title
        self.content = content
        self.images = images
        self.likes = likes
        self.comments = comments
        self.reportCount = reportCount
        self.createdAt = createdAt
        self.isLocal = isLocal
        self.isAuthorPrivileged = isAuthorPrivileged
        self.syncStatus = syncStatus
    }
}

/// 茶楼评论数据模型
@Model
final class TeahouseComment {
    @Attribute(.unique) var id: String
    var postId: String
    var author: String
    var authorId: String?
    var content: String
    var createdAt: Date
    var isLocal: Bool
    var syncStatus: TeahousePost.SyncStatus
    
    init(
        id: String = UUID().uuidString,
        postId: String,
        author: String,
        authorId: String? = nil,
        content: String,
        createdAt: Date = Date(),
        isLocal: Bool = true,
        syncStatus: TeahousePost.SyncStatus = .local
    ) {
        self.id = id
        self.postId = postId
        self.author = author
        self.authorId = authorId
        self.content = content
        self.createdAt = createdAt
        self.isLocal = isLocal
        self.syncStatus = syncStatus
    }
}

/// 用户点赞记录
@Model
final class UserLike {
    @Attribute(.unique) var id: String
    var userId: String
    var postId: String
    var createdAt: Date
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        postId: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.postId = postId
        self.createdAt = createdAt
    }
}
