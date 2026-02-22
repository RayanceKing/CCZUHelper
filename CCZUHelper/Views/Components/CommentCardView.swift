//
//  CommentCardView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/14.
//

import SwiftUI
internal import Auth

struct CommentCardView: View {
    @Environment(\.colorScheme) private var colorScheme
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
    @State private var isReplyAnonymous = false
    @State private var isDeleteArmed = false
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
            return "common.anonymous_user".localized
        }
        return commentWithProfile.profile?.username ?? "common.user".localized
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
            return "time.just_now".localized
        } else if interval < 3600 {
            return String(format: "time.minutes_ago".localized, Int(interval / 60))
        } else if interval < 86400 {
            return String(format: "time.hours_ago".localized, Int(interval / 3600))
        } else if interval < 604800 {
            return String(format: "time.days_ago".localized, Int(interval / 86400))
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd"
            return formatter.string(from: createdAt)
        }
    }
    
    private var isAuthorPrivileged: Bool {
        let isAnonymous = commentWithProfile.comment.isAnonymous == true
        return !isAnonymous && commentWithProfile.profile?.isPrivilege == true
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
    
    // 头部信息视图
    private var headerView: some View {
        HStack {
            if isAuthorPrivileged {
                Text(displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(hex: "#528BF3") ?? .blue,
                                Color(hex: "#9A6DE0") ?? .purple,
                                Color(hex: "#E14A70") ?? .red,
                                Color(hex: "#F08D3B") ?? .orange
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            } else {
                Text(displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            Text(timeAgo)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
    
    // 互动按钮视图
    private var actionButtonsView: some View {
        HStack(spacing: 16) {
            Button(action: toggleLike) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .foregroundStyle(isLiked ? .red : .secondary)
                    .font(.caption)
            }
            Button(action: {
                if authViewModel.isAuthenticated {
                    showReplyInput.toggle()
                } else {
                    showLoginPrompt = true
                }
            }) {
                Image(systemName: "bubble.right")
                    .font(.caption)
                Text("comment.reply".localized)
                    .font(.caption)
            }
            .foregroundStyle(.secondary)

//            if isCommentOwner {
                Button(action: {
                    if isDeleteArmed {
                        deleteComment()
                        isDeleteArmed = false
                    } else {
                        isDeleteArmed = true
                        // 自动2秒后恢复
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            isDeleteArmed = false
                        }
                    }
                }) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(isDeleteArmed ? .red : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("comment.delete_label".localized)
//            }
            Spacer()
        }
    }
    
    // 回复输入框视图
    private var replyInputView: some View {
        HStack(spacing: 8) {
            // +号菜单（匿名开关）
            Menu {
                Button(action: {
                    isReplyAnonymous.toggle()
                }) {
                    Label(
                        isReplyAnonymous ? "comment.cancel_anonymous".localized : "comment.set_anonymous".localized,
                        systemImage: isReplyAnonymous ? "eye.fill" : "eye.slash.fill"
                    )
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.body)
            }
            .buttonStyle(.borderless)
            
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
        .padding(.leading, 40)
    }
    

    
    // 主内容视图
    private var mainContentView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                AvatarView(avatarUrl: avatarUrl, isAnonymous: commentWithProfile.comment.isAnonymous)
                
                VStack(alignment: .leading, spacing: 4) {
                    headerView
                    
                    HStack(alignment: .bottom, spacing: 4) {
                        CommentBubbleView(content: commentWithProfile.comment.content)
                        Spacer(minLength: 0)
                    }
                    
                    actionButtonsView
                }
            }
            
            if showReplyInput {
                replyInputView
            }
        }
    }
    
    var body: some View {
        mainContentView
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.09), radius: 6, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.gray.opacity(0.08), lineWidth: 1)
            )
            .onLongPressGesture(minimumDuration: 0.5) {
                // 长按气泡时，如果是自己的评论则显示删除确认
                if isCommentOwner {
                    showDeleteConfirm = true
                }
            }
            .alert("comment.delete".localized, isPresented: $showDeleteConfirm) {
                Button("common.delete".localized, role: .destructive) {
                    deleteComment()
                }
                Button("common.cancel".localized, role: .cancel) {}
            } message: {
                Text("comment.delete_confirm".localized)
            }
            .alert("teahouse.login.required".localized, isPresented: $showLoginPrompt) {
                Button("common.ok".localized, role: .cancel) { }
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
        let anonymous = isReplyAnonymous
        replyText = ""
        showReplyInput = false
        
        Task {
            do {
                _ = try await teahouseService.addComment(
                    postId: postId,
                    content: replyContent,
                    userId: userId,
                    parentCommentId: commentWithProfile.comment.id,
                    isAnonymous: anonymous
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
        
        let sampleProfile = CommentProfilePreview(
            username: "zhangsan",
            realName: "张三",
            avatarUrl: nil,
            isPrivilege: false
        )
        
        let sampleCommentWithProfile = CommentWithProfile(
            comment: sampleComment,
            profile: sampleProfile,
        )
        
        VStack {
            CommentCardView(commentWithProfile: sampleCommentWithProfile, postId: "post1")
                .padding()
            Spacer()
        }
        //
    }
}
