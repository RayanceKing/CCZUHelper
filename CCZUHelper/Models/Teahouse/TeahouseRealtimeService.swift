//
//  TeahouseRealtimeService.swift
//  CCZUHelper
//
//  Created by Copilot on 2026/3/2.
//

import Foundation
import Supabase
import Combine

/// 茶楼实时订阅服务 - 负责监听帖子状态变化
@MainActor
final class TeahouseRealtimeService: ObservableObject {
    
    // MARK: - Properties
    
    @Published var posts: [WaterfallPost] = []
    
    private var realtimeChannel: RealtimeChannelV2?
    private var postgresUpdateSubscription: RealtimeSubscription?
    
    // MARK: - Lifecycle
    
    deinit {
        Task { @MainActor [weak self] in
            await self?.stopRealtimeSubscription()
        }
    }
    
    // MARK: - Subscription Management
    
    /// 开始实时订阅帖子状态变化
    func startRealtimeSubscription() {
        realtimeChannel = supabase.channel("public:posts")
        
        postgresUpdateSubscription = realtimeChannel?.onPostgresChange(
            UpdateAction.self,
            schema: "public",
            table: "posts"
        ) { [weak self] action in
            Task { @MainActor [weak self] in
                await self?.handlePostUpdate(action)
            }
        }
        
        Task {
            do {
                try await realtimeChannel?.subscribeWithError()
            } catch {
                print("⚠️ 实时订阅失败: \(error)")
            }
        }
    }
    
    /// 停止实时订阅
    func stopRealtimeSubscription() async {
        postgresUpdateSubscription?.cancel()
        postgresUpdateSubscription = nil
        
        await realtimeChannel?.unsubscribe()
        realtimeChannel = nil
    }
    
    // MARK: - Event Handling
    
    /// 处理帖子更新事件
    private func handlePostUpdate(_ action: UpdateAction) async {
        let record = action.record
        
        guard let postId = record["id"]?.value as? String,
              let statusString = record["status"]?.value as? String,
              let newStatus = PostStatus(rawValue: statusString) else {
            return
        }
        
        // 更新本地缓存中的帖子状态
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            var updatedPost = posts[index].post
            updatedPost = PostWithMetadata(
                id: updatedPost.id,
                userId: updatedPost.userId,
                categoryId: updatedPost.categoryId,
                title: updatedPost.title,
                content: updatedPost.content,
                imageUrls: updatedPost.imageUrls,
                price: updatedPost.price,
                isAnonymous: updatedPost.isAnonymous,
                status: newStatus,  // 更新状态
                createdAt: updatedPost.createdAt,
                likeCount: updatedPost.likeCount,
                commentCount: updatedPost.commentCount,
                rootCommentCount: updatedPost.rootCommentCount,
                reportCount: updatedPost.reportCount
            )
            posts[index] = WaterfallPost(post: updatedPost, profile: posts[index].profile)
        }
    }
}
