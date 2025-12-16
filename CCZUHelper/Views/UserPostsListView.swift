//
//  UserPostsListView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/14.
//

import SwiftUI
import Kingfisher

enum UserPostType {
    case myPosts
    case likedPosts
    case commentedPosts
    
    var title: String {
        switch self {
        case .myPosts: return "我发的帖"
        case .likedPosts: return "我点赞的"
        case .commentedPosts: return "我评论的"
        }
    }
    
    var emptyMessage: String {
        switch self {
        case .myPosts: return "还没有发布过帖子"
        case .likedPosts: return "还没有点赞过帖子"
        case .commentedPosts: return "还没有评论过帖子"
        }
    }
}

struct UserPostsListView: View {
    let type: UserPostType
    let userId: String
    
    @StateObject private var teahouseService = TeahouseService()
    @State private var posts: [WaterfallPost] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirm = false
    @State private var postToDelete: WaterfallPost?
    @State private var showDeleteCommentsConfirm = false
    @State private var postIdForCommentDelete: String?
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("加载中...")
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)
                    Text(error)
                        .foregroundStyle(.secondary)
                    Button("重试") {
                        loadPosts()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else if posts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text(type.emptyMessage)
                        .foregroundStyle(.secondary)
                }
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(posts) { waterfallPost in
                            if type == .myPosts {
                                // 自己发的帖子支持删除
                                NavigationLink {
                                    PostDetailView(post: convertToTeahousePost(waterfallPost))
                                } label: {
                                    PostCardCompactView(waterfallPost: waterfallPost)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        deletePost(waterfallPost)
                                    } label: {
                                        Label("删除帖子", systemImage: "trash")
                                    }
                                }
                            } else {
                                // 其他类型的帖子只能查看；评论过的帖子允许长按删除自己的评论
                                NavigationLink {
                                    PostDetailView(post: convertToTeahousePost(waterfallPost))
                                } label: {
                                    PostCardCompactView(waterfallPost: waterfallPost)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    if type == .commentedPosts {
                                        Button(role: .destructive) {
                                            postIdForCommentDelete = waterfallPost.post.id
                                            showDeleteCommentsConfirm = true
                                        } label: {
                                            Label("删除我的评论", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(type.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadPosts()
        }
        .alert("删除帖子", isPresented: $showDeleteConfirm) {
            Button("删除", role: .destructive) {
                if let post = postToDelete {
                    performDeletePost(post)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("确定要删除这篇帖子吗？删除后无法恢复。")
        }
        .alert("删除评论", isPresented: $showDeleteCommentsConfirm) {
            Button("删除", role: .destructive) {
                if let postId = postIdForCommentDelete {
                    performDeleteComments(postId: postId)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("确定要删除你在该帖下的所有评论吗？删除后无法恢复。")
        }
    }
    
    private func loadPosts() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fetchedPosts: [WaterfallPost]
                
                switch type {
                case .myPosts:
                    fetchedPosts = try await teahouseService.fetchUserPosts(userId: userId)
                case .likedPosts:
                    fetchedPosts = try await teahouseService.fetchUserLikedPosts(userId: userId)
                case .commentedPosts:
                    fetchedPosts = try await teahouseService.fetchUserCommentedPosts(userId: userId)
                }
                
                await MainActor.run {
                    posts = fetchedPosts
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "加载失败: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    private func deletePost(_ post: WaterfallPost) {
        postToDelete = post
        showDeleteConfirm = true
    }
    
    private func performDeletePost(_ post: WaterfallPost) {
        guard let postId = post.post.id else { return }
        
        Task {
            do {
                try await teahouseService.deletePost(postId: postId)
                // 删除成功后，从列表中移除该帖子
                await MainActor.run {
                    posts.removeAll { $0.post.id == postId }
                    postToDelete = nil
                }
            } catch {
                await MainActor.run {
                    errorMessage = "删除失败: \(error.localizedDescription)"
                }
            }
        }
    }

    private func performDeleteComments(postId: String) {
        Task {
            do {
                try await teahouseService.deleteCommentsForPost(userId: userId, postId: postId)
                await MainActor.run {
                    // 移除该帖子，使列表反映删除后的状态
                    posts.removeAll { $0.post.id == postId }
                    postIdForCommentDelete = nil
                }
            } catch {
                await MainActor.run {
                    errorMessage = "删除评论失败: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func convertToTeahousePost(_ waterfallPost: WaterfallPost) -> TeahousePost {
        let post = waterfallPost.post
        let profile = waterfallPost.profile
        
        // 解析图片URLs
        var imageUrls: [String] = []
        if let urlsString = post.imageUrls, !urlsString.isEmpty, urlsString != "{}" {
            if let data = urlsString.data(using: .utf8),
               let urls = try? JSONDecoder().decode([String].self, from: data) {
                imageUrls = urls
            }
        }
        
        let author = (post.isAnonymous ?? false) ? "匿名用户" : (profile?.username ?? "用户")
        
        return TeahousePost(
            id: post.id ?? UUID().uuidString,
            author: author,
            authorId: (post.isAnonymous ?? false) ? nil : post.userId,
            authorAvatarUrl: (post.isAnonymous ?? false) ? nil : profile?.avatarUrl,
            category: nil,
            price: post.price,
            title: post.title ?? "无标题",
            content: post.content ?? "",
            images: imageUrls,
            likes: post.likeCount ?? 0,
            comments: post.commentCount ?? 0,
            createdAt: post.createdAt ?? Date(),
            isLocal: false,
            syncStatus: .synced
        )
    }
}

// MARK: - Compact Post Card View

struct PostCardCompactView: View {
    let waterfallPost: WaterfallPost
    
    private var authorName: String {
        if waterfallPost.post.isAnonymous ?? false {
            return "匿名用户"
        }
        return waterfallPost.profile?.username ?? "用户"
    }
    
    private var timeAgo: String {
        guard let createdAt = waterfallPost.post.createdAt else {
            return ""
        }
        
        let now = Date()
        let interval = now.timeIntervalSince(createdAt)
        
        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            return "\(Int(interval / 60))分钟前"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))小时前"
        } else if interval < 604800 {
            return "\(Int(interval / 86400))天前"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd"
            return formatter.string(from: createdAt)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 作者和时间
            HStack {
                Group {
                    if let urlString = waterfallPost.profile?.avatarUrl,
                       !(waterfallPost.post.isAnonymous ?? false),
                       let url = URL(string: urlString) {
                        KFImage(url)
                            .placeholder { ProgressView().frame(width: 28, height: 28) }
                            .retry(maxCount: 2, interval: .seconds(2))
                            .resizable()
                            .scaledToFill()
                            .frame(width: 28, height: 28)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
                Text(authorName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(timeAgo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // 标题
            Text(waterfallPost.post.title ?? "无标题")
                .font(.headline)
                .lineLimit(2)
                .foregroundStyle(.primary)
            
            // 内容预览
            Text(waterfallPost.post.content ?? "")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            
            // 互动数据
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "heart")
                    Text("\(waterfallPost.post.likeCount ?? 0)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                
                HStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                    Text("\(waterfallPost.post.commentCount ?? 0)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        UserPostsListView(type: .myPosts, userId: "test-user-id")
    }
}
