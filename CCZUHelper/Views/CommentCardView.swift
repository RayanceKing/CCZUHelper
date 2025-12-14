//
//  CommentCardView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/14.
//

import SwiftUI
internal import Auth

struct CommentCardView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    let commentWithProfile: CommentWithProfile
    let postId: String
    let onCommentChanged: (() -> Void)?
    
    @State private var isLiked = false
    @State private var isProcessingLike = false
    @State private var replyText = ""
    @State private var showReplyInput = false
    @State private var showLoginPrompt = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @StateObject private var teahouseService = TeahouseService()

    init(
        commentWithProfile: CommentWithProfile,
        postId: String,
        onCommentChanged: (() -> Void)? = nil
    ) {
        self.commentWithProfile = commentWithProfile
        self.postId = postId
        self.onCommentChanged = onCommentChanged
    }
    
    private var displayName: String {
        if commentWithProfile.comment.isAnonymous == true {
            return "匿名用户"
        }
        return commentWithProfile.profile?.username ?? "用户"
    }
    
    private var avatarUrl: URL? {
        if commentWithProfile.comment.isAnonymous == true {
            return nil
        }
        if let urlString = commentWithProfile.profile?.avatarUrl {
            return URL(string: urlString)
        }
        return nil
    }
    
    private var timeAgo: String {
        guard let createdAt = commentWithProfile.comment.createdAt else {
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
    
    /// 检查当前用户是否是评论的所有者
    private var isCommentOwner: Bool {
        guard let currentUserId = authViewModel.session?.user.id.uuidString,
              let commentUserId = commentWithProfile.comment.userId else {
            return false
        }
        let isAnonymous = commentWithProfile.comment.isAnonymous ?? false
        return currentUserId == commentUserId && !isAnonymous
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                // 头像
                Group {
                    if let url = avatarUrl {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure:
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.gray)
                                    )
                            @unknown default:
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                            }
                        }
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: commentWithProfile.comment.isAnonymous == true ? "questionmark" : "person.fill")
                                    .foregroundColor(.gray)
                            )
                    }
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    // 用户名和时间
                    HStack {
                        Text(displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(timeAgo)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    // 评论内容
                    Text(commentWithProfile.comment.content)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // 互动按钮
                    HStack(spacing: 16) {
                        Button(action: toggleLike) {
                            HStack(spacing: 4) {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .foregroundStyle(isLiked ? .red : .secondary)
                                    .font(.caption)
                            }
                        }
                        
                        Button(action: {
                            if authViewModel.isAuthenticated {
                                showReplyInput.toggle()
                            } else {
                                showLoginPrompt = true
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "bubble.right")
                                    .font(.caption)
                                Text("comment.reply".localized)
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                }
            }
            
            // 回复输入框
            if showReplyInput {
                HStack(spacing: 8) {
                    TextField("comment.reply_placeholder".localized, text: $replyText)
                        .textFieldStyle(.roundedBorder)
                        .font(.subheadline)
                    
                    Button(action: submitReply) {
                        Image(systemName: "paperplane.fill")
                            .foregroundStyle(.blue)
                    }
                    .disabled(replyText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.top, 4)
                .padding(.leading, 48)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
        .contextMenu {
            if isCommentOwner {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("comment.delete".localized, systemImage: "trash")
                }
            }
        }
        .alert("comment.delete".localized, isPresented: $showDeleteConfirm) {
            Button("comment.delete_button".localized, role: .destructive) {
                deleteComment()
            }
            Button("cancel".localized, role: .cancel) {}
        } message: {
            Text("comment.delete_confirm".localized)
        }
        .alert("teahouse.login.required".localized, isPresented: $showLoginPrompt) {
            Button("ok".localized, role: .cancel) { }
        } message: {
            Text("teahouse.login.required_message".localized)
        }
        .task {
            await loadInitialLikeState()
        }
    }
    
    private func toggleLike() {
        guard authViewModel.isAuthenticated else {
            showLoginPrompt = true
            return
        }
        guard !isProcessingLike,
              let userId = authViewModel.session?.user.id.uuidString else {
            return
        }
        isProcessingLike = true
        Task {
            do {
                let liked = try await teahouseService.toggleCommentLike(commentId: commentWithProfile.comment.id, userId: userId)
                await MainActor.run {
                    isLiked = liked
                }
            } catch {
                print("切换评论点赞失败: \(error.localizedDescription)")
            }
            await MainActor.run {
                isProcessingLike = false
            }
        }
    }
    
    private func submitReply() {
        guard !replyText.trimmingCharacters(in: .whitespaces).isEmpty,
              authViewModel.isAuthenticated,
              let userId = authViewModel.session?.user.id.uuidString else {
            return
        }
        
        let replyContent = replyText
        replyText = ""
        showReplyInput = false
        Task {
            do {
                _ = try await teahouseService.addComment(
                    postId: postId,
                    content: replyContent,
                    userId: userId,
                    parentCommentId: commentWithProfile.comment.id,
                    isAnonymous: false
                )
                await MainActor.run {
                    onCommentChanged?()
                }
            } catch {
                await MainActor.run {
                    replyText = replyContent
                    showReplyInput = true
                }
                print("回复评论失败: \(error.localizedDescription)")
            }
        }
    }
    
    private func deleteComment() {
        let commentId = commentWithProfile.comment.id
        
        isDeleting = true
        Task {
            do {
                try await teahouseService.deleteComment(commentId: commentId)
                // 删除成功后，调用方应该刷新评论列表
                print("评论已删除: \(commentId)")
                await MainActor.run {
                    onCommentChanged?()
                }
            } catch {
                print("删除评论失败: \(error.localizedDescription)")
            }
            isDeleting = false
        }
    }

    private func loadInitialLikeState() async {
        guard authViewModel.isAuthenticated,
              let userId = authViewModel.session?.user.id.uuidString else {
            return
        }
        do {
            let liked = try await teahouseService.isCommentLiked(commentId: commentWithProfile.comment.id, userId: userId)
            await MainActor.run {
                isLiked = liked
            }
        } catch {
            print("获取评论点赞状态失败: \(error.localizedDescription)")
        }
    }
}

#Preview {
    let sampleComment = Comment(
        id: "1",
        postId: "post1",
        userId: "user1",
        parentCommentId: nil,
        content: "这是一条测试评论，内容可以很长很长很长很长很长很长很长很长",
        isAnonymous: false,
        createdAt: Date().addingTimeInterval(-3600)
    )
    
    let sampleProfile = Profile(
        id: "user1",
        realName: "张三",
        studentId: "2201150225",
        className: "软件2201",
        collegeName: "信息科学与工程学院",
        grade: 2022,
        username: "zhangsan",
        avatarUrl: nil,
        createdAt: Date()
    )
    
    let sampleCommentWithProfile = CommentWithProfile(
        comment: sampleComment,
        profile: sampleProfile
    )
    
    VStack {
        CommentCardView(commentWithProfile: sampleCommentWithProfile, postId: "post1")
            .padding()
        Spacer()
    }
}
