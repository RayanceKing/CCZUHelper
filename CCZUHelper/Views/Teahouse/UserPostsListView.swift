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
        case .myPosts: return "user_posts.my_posts".localized
        case .likedPosts: return "user_posts.liked_posts".localized
        case .commentedPosts: return "user_posts.commented_posts".localized
        }
    }
    
    var emptyMessage: String {
        switch self {
        case .myPosts: return "user_posts.empty.my_posts".localized
        case .likedPosts: return "user_posts.empty.liked_posts".localized
        case .commentedPosts: return "user_posts.empty.commented_posts".localized
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

    @ViewBuilder
    private var baseContent: some View {
        #if os(macOS)
        macContent
        #else
        mobileListContent
        #endif
    }
    
    var body: some View {
        baseContent
            .navigationTitle(type.title)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .task {
                await loadPosts()
            }
            .refreshable {
                await loadPosts()
            }
            .alert("user_posts.delete_confirm_title".localized, isPresented: $showDeleteConfirm) {
                Button("common.cancel".localized, role: .cancel) {}
                Button("common.delete".localized, role: .destructive) {
                    if let post = postToDelete {
                        performDeletePost(post)
                    }
                }
            } message: {
                if let post = postToDelete, let title = post.post.title {
                    Text(String(format: "user_posts.delete_confirm_message".localized, title))
                } else {
                    Text("user_posts.delete_confirm_message_generic".localized)
                }
            }
            .alert("comment.delete".localized, isPresented: $showDeleteCommentsConfirm) {
                Button("common.cancel".localized, role: .cancel) {}
                Button("common.delete".localized, role: .destructive) {
                    if let postId = postIdForCommentDelete {
                        performDeleteComments(postId: postId)
                    }
                }
            } message: {
                Text("user_posts.delete_comment_confirm_message".localized)
            }
#if os(macOS)
            .frame(minWidth: 680, minHeight: 560)
#endif
    }

    #if os(macOS)
    private var macContent: some View {
        VStack(spacing: 0) {
            if isLoading {
                Spacer()
                VStack(spacing: 12) {
                    ProgressView()
                    Text("common.loading".localized)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)
                    Text(error)
                        .foregroundStyle(.secondary)
                    Button("common.retry".localized) {
                        Task { await loadPosts() }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else if posts.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text(type.emptyMessage)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(posts.enumerated()), id: \.offset) { index, waterfallPost in
                            NavigationLink(destination: PostDetailView(post: convertToTeahousePost(waterfallPost))) {
                                PostListItemView(waterfallPost: waterfallPost, dateAtTrailing: true)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                if type == .myPosts {
                                    Button(role: .destructive) {
                                        deletePost(waterfallPost)
                                    } label: {
                                        Label("common.delete".localized, systemImage: "trash")
                                    }
                                } else if type == .commentedPosts {
                                    Button(role: .destructive) {
                                        postIdForCommentDelete = waterfallPost.post.id
                                        showDeleteCommentsConfirm = true
                                    } label: {
                                        Label("comment.delete".localized, systemImage: "trash")
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            if index < posts.count - 1 {
                                Divider()
                                    .padding(.leading, 16)
                                    .padding(.trailing, 16)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    #endif

    private var mobileListContent: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Text("common.loading".localized)
                    Spacer()
                }
            } else if let error = errorMessage {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundStyle(.orange)
                        Text(error)
                            .foregroundStyle(.secondary)
                        Button("common.retry".localized) {
                            Task { await loadPosts() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Spacer()
                }
            } else if posts.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text(type.emptyMessage)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            } else {
                ForEach(posts) { waterfallPost in
                    NavigationLink(destination: PostDetailView(post: convertToTeahousePost(waterfallPost))) {
                        PostListItemView(waterfallPost: waterfallPost)
                    }
                    #if os(macOS)
                    .contextMenu {
                        if type == .myPosts {
                            Button(role: .destructive) {
                                deletePost(waterfallPost)
                            } label: {
                                Label("common.delete".localized, systemImage: "trash")
                            }
                        } else if type == .commentedPosts {
                            Button(role: .destructive) {
                                postIdForCommentDelete = waterfallPost.post.id
                                showDeleteCommentsConfirm = true
                            } label: {
                                Label("comment.delete".localized, systemImage: "trash")
                            }
                        }
                    }
                    #else
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if type == .myPosts {
                            // 自己发的帖子支持删除
                            Button(role: .destructive) {
                                deletePost(waterfallPost)
                            } label: {
                                Label("common.delete".localized, systemImage: "trash")
                            }
                        } else if type == .commentedPosts {
                            // 评论过的帖子允许删除自己的评论
                            Button(role: .destructive) {
                                postIdForCommentDelete = waterfallPost.post.id
                                showDeleteCommentsConfirm = true
                            } label: {
                                Label("comment.delete".localized, systemImage: "trash")
                            }
                        }
                    }
                    #endif
                }
            }
        }
    }
    
    @MainActor
    private func loadPosts() async {
        isLoading = true
        errorMessage = nil

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

            posts = fetchedPosts
            isLoading = false
        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
            isLoading = false
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

    private var cardBackgroundColor: Color {
        #if os(macOS)
        return Color(nsColor: .windowBackgroundColor)
        #else
        return Color(.systemBackground)
        #endif
    }
    
    private var authorName: String {
        if waterfallPost.post.isAnonymous ?? false {
            return "user_posts.anonymous_user".localized
        }
        return waterfallPost.profile?.username ?? "common.user".localized
    }
    
    private var timeAgo: String {
        guard let createdAt = waterfallPost.post.createdAt else {
            return ""
        }
        
        let now = Date()
        let interval = now.timeIntervalSince(createdAt)
        
        if interval < 60 {
            return "user_posts.just_now".localized
        } else if interval < 3600 {
            return String(format: "user_posts.minutes_ago".localized, Int(interval / 60))
        } else if interval < 86400 {
            return String(format: "user_posts.hours_ago".localized, Int(interval / 3600))
        } else if interval < 604800 {
            return String(format: "user_posts.days_ago".localized, Int(interval / 86400))
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
                HStack(spacing: 2) {
                    Image(systemName: "heart")
                        .imageScale(.small)
                    Text("\(waterfallPost.post.likeCount ?? 0)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                
                HStack(spacing: 2) {
                    Image(systemName: "bubble.right")
                        .imageScale(.small)
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
                .fill(cardBackgroundColor)
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
}

/// 帖子列表项视图
struct PostListItemView: View {
    let waterfallPost: WaterfallPost
    var dateAtTrailing: Bool = true
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(waterfallPost.post.title ?? "无标题")
                    .font(.headline)
                    .lineLimit(1)
                
                Text(waterfallPost.post.content ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack(spacing: 12) {
                    Label("\(waterfallPost.post.likeCount ?? 0)", systemImage: "heart")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Label("\(waterfallPost.post.commentCount ?? 0)", systemImage: "bubble.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if !dateAtTrailing, let createdAt = waterfallPost.post.createdAt {
                    Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if dateAtTrailing, let createdAt = waterfallPost.post.createdAt {
                Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: 120, alignment: .trailing)
            }
        }
        .padding(.vertical, 8)
        .padding(.trailing, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack {
        UserPostsListView(type: .myPosts, userId: "test-user-id")
    }
}
