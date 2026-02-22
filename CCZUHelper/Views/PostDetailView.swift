//
//  PostDetailView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/17.
import Kingfisher

import SwiftUI
import SwiftData
import MarkdownUI
import Supabase
import Photos
#if canImport(UIKit)
import UIKit
#endif

#if canImport(Foundation)
import Foundation
#endif
#if canImport(FoundationModels)
import FoundationModels
#endif

struct PostDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    let post: TeahousePost
    
    @State private var commentText = ""
    @State private var isSubmitting = false
    @State private var showLoginPrompt = false
    @State private var comments: [CommentWithProfile] = []
    @State private var isLoadingComments = false
    @State private var selectedImageForPreview: String? = nil
    @State private var showImagePreview = false
    @State private var isAnonymous = false
    @State private var showDeleteConfirm = false
    @State private var commentPendingDeletion: CommentWithProfile? = nil
    @State private var armedDeleteCommentIDs: Set<String> = []

    @State private var isSummarizing = false
    @State private var summaryText: String? = nil
    @State private var showSummarySheet = false
    @State private var summarizeError: String? = nil
    
    @State private var canSummarizeOnDevice = false
    @State private var isCheckingSummaryAvailability = false
    @State private var showReportSheet = false
    @State private var showImageShareSheet = false
    @State private var imageShareItems: [Any] = []
    @State private var showImageActionResult = false
    @State private var imageActionResultMessage = ""
    @State private var isKeyboardPresented = false
    
    @StateObject private var teahouseService = TeahouseService()
    
    @Query var userLikes: [UserLike]
    
    private var isAuthorPrivileged: Bool {
        return post.isAuthorPrivileged == true
    }
    
    init(post: TeahousePost) {
        self.post = post
        let postId = post.id
        let userId = AppSettings().username ?? "guest"
        self._userLikes = Query(filter: #Predicate { like in
            like.postId == postId && like.userId == userId
        })
    }
    
    private var isLiked: Bool {
        !userLikes.isEmpty && userLikes.contains { $0.postId == post.id }
    }
    
    private var attributedContent: AttributedString? {
        try? AttributedString(
            markdown: post.content,
            options: .init(interpretedSyntax: .full)
        )
    }
    
    private var showPriceBadge: Bool {
        (post.category ?? "") == "二手" && post.price != nil
    }

    @ViewBuilder
    private var pageBackground: some View {
#if os(macOS)
        Color(nsColor: .windowBackgroundColor)
#else
        colorScheme == .dark ? Color(.systemGroupedBackground) : Color.white
#endif
    }

    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return NSLocalizedString("teahouse.just_now", comment: "")
        } else if interval < 3600 {
            return String(format: NSLocalizedString("teahouse.minutes_ago", comment: ""), Int(interval / 60))
        } else if interval < 86400 {
            return String(format: NSLocalizedString("teahouse.hours_ago", comment: ""), Int(interval / 3600))
        } else if interval < 604800 {
            return String(format: NSLocalizedString("teahouse.days_ago", comment: ""), Int(interval / 86400))
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd"
            return formatter.string(from: date)
        }
    }
    
    private var titleAndContentView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(post.title)
                .font(.title2)
                .fontWeight(.semibold)
            Markdown(post.content)
                .markdownTheme(.gitHub)
                .background(Color.clear)
                // 去除阴影：如有 .shadow 修饰符则移除
        }
    }
    
    private var imagesGridView: some View {
        Group {
            if !post.images.isEmpty {
                let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(post.images, id: \.self) { imagePath in
                        if let url = URL(string: imagePath), !imagePath.isEmpty {
                            GeometryReader { geo in
                                let side = geo.size.width
                                KFImage(url)
                                    .downsampling(size: CGSize(width: max(1, side), height: max(1, side)))
                                    .scaleFactor(displayScale)
                                    .cancelOnDisappear(true)
                                    .placeholder {
                                        ZStack {
                                            Color.secondary.opacity(0.08)
                                            ProgressView()
                                        }
                                        .frame(width: side, height: side)
                                    }
                                    .retry(maxCount: 2, interval: .seconds(2))
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: side, height: side)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .aspectRatio(1, contentMode: .fit)
                            .contentShape(RoundedRectangle(cornerRadius: 8))
                            .onTapGesture {
                                selectedImageForPreview = imagePath
                                showImagePreview = true
                            }
                            .contextMenu {
                                imageContextMenu(imageURL: url)
                            } preview: {
                                menuPreviewImage(url: url)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var headerView: some View {
        HStack(spacing: 8) {
            Group {
                if let urlString = post.authorAvatarUrl, let url = URL(string: urlString) {
                    KFImage(url)
                        .placeholder { ProgressView() }
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                if isAuthorPrivileged {
                    Text(post.author)
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
                    Text(post.author)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                Text(timeAgoString(from: post.createdAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let category = post.category {
                Text(category)
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
    }
    
    private var actionButtonsView: some View {
        HStack(spacing: 24) {
            Button(action: {
                if authViewModel.isAuthenticated {
                    toggleLike()
                } else {
                    showLoginPrompt = true
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .foregroundStyle(isLiked ? .red : .secondary)
                    Text("\(post.likes)")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 4) {
                Image(systemName: "bubble.right")
                Text("\(post.comments)")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            
            Button(action: {
                if authViewModel.isAuthenticated {
                    showReportSheet = true
                } else {
                    showLoginPrompt = true
                }
            }) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.top, 8)
    }
    
    private var commentsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if comments.isEmpty && !isLoadingComments {
                Text("teahouse.post.no_comments".localized)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 32)
            } else {
                ForEach(rootComments) { commentWithProfile in
                    commentThread(for: commentWithProfile)
                }
            }
        }
    }
    
    private var mainContentView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if post.reportCount > 5 {
                // 帖子被隐藏
                VStack(spacing: 16) {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    
                    Text("teahouse.post.hidden.title".localized)
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    Text("teahouse.post.hidden.message".localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            Color(
                                colorScheme == .dark ?
                                    UIColor.systemGray6 :
                                    UIColor.white
                            )
                        )
                        .shadow(
                            color: colorScheme == .dark ? Color.black.opacity(0.2) : Color.black.opacity(0.1),
                            radius: colorScheme == .dark ? 10 : 8,
                            x: 0,
                            y: colorScheme == .dark ? 5 : 4
                        )
                )
            } else {
                // 帖子内容卡片
                VStack(alignment: .leading, spacing: 12) {
                    headerView
                    titleAndContentView
                    imagesGridView
                    actionButtonsView
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            Color(
                                colorScheme == .dark ?
                                    UIColor.systemGray6 :
                                    UIColor.white
                            )
                        )
                        .shadow(
                            color: colorScheme == .dark ? Color.black.opacity(0.2) : Color.black.opacity(0.1),
                            radius: colorScheme == .dark ? 10 : 8,
                            x: 0,
                            y: colorScheme == .dark ? 5 : 4
                        )
                )
            }

            Divider()
                .padding(.vertical, 8)

            // 评论区
            if comments.isEmpty && !isLoadingComments {
                Text("teahouse.post.no_comments".localized)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 32)
            } else {
                ForEach(rootComments) { commentWithProfile in
                    commentThread(for: commentWithProfile)
                }
            }
            Spacer(minLength: 40)
        }
    }
    
    var body: some View {
        ZStack {
            pageBackground
                .ignoresSafeArea()

            ScrollView {
                mainContentView
                    .padding()
            }
        }
        .onAppear {
            selectedImageForPreview = nil
            loadComments()
            updateSummarizationAvailability()
        }
        .onDisappear {
            selectedImageForPreview = nil
            summaryText = nil
            summarizeError = nil
            ImageCache.default.clearMemoryCache()
        }
        .navigationTitle(post.category ?? "teahouse.post.default_title".localized)
        .toolbar {
            #if os(iOS)
            if #available(iOS 26.0, *) {
                if canSummarizeOnDevice {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: { Task { await summarizePost() } }) {
                            if isSummarizing {
                                ProgressView()
                            } else {
                                Image(systemName: "text.line.3.summary")
                            }
                        }
                        .disabled(isSummarizing)
                        .accessibilityLabel(Text("teahouse.summary.button".localized))
                    }
                }
            }
            #endif
        }
#if canImport(UIKit)
        .sheet(isPresented: $showImageShareSheet) {
            ActivityView(activityItems: imageShareItems)
        }
#endif
        .sheet(isPresented: $showImagePreview, onDismiss: {
            selectedImageForPreview = nil
        }) {
            if let imagePath = selectedImageForPreview, let url = URL(string: imagePath) {
                ImagePreviewView(url: url)
            }
        }
        .sheet(isPresented: $showSummarySheet) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if let text = summaryText {
                            Text(text)
                                .font(.body)
                                .foregroundStyle(.primary)
                        } else if let err = summarizeError {
                            Text("teahouse.summary.failed".localized(with: err))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("teahouse.summary.no_content".localized)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                }
                .navigationTitle("teahouse.summary.sheet_title".localized)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common.close".localized) { showSummarySheet = false }
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            hideKeyboard()
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SeparateMessageInputField(
                text: $commentText,
                isAnonymous: $isAnonymous,
                isLoading: isSubmitting,
                isAuthenticated: authViewModel.isAuthenticated,
                onSend: { submitComment() },
                onRequireLogin: { showLoginPrompt = true }
            )
            .frame(maxWidth: 700)
            .padding(.horizontal, 18)
            .padding(.bottom, isKeyboardPresented ? 8 : -4)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardPresented = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardPresented = false
        }
        .alert("teahouse.auth.login_required_title".localized, isPresented: $showLoginPrompt) {
            Button("common.ok".localized, role: .cancel) { }
        } message: {
            Text("teahouse.auth.login_required_message".localized)
        }
        .alert("teahouse.image.action.title".localized, isPresented: $showImageActionResult) {
            Button("common.ok".localized, role: .cancel) { }
        } message: {
            Text(imageActionResultMessage)
        }
        .alert("comment.delete".localized, isPresented: $showDeleteConfirm, presenting: commentPendingDeletion) { item in
            Button("common.cancel".localized, role: .cancel) { commentPendingDeletion = nil }
            Button("common.delete".localized, role: .destructive) { deleteComment(item) }
        } message: { _ in
            Text("teahouse.comment.delete_message".localized)
        }
        .sheet(isPresented: $showReportSheet) {
            ReportPostView(postId: post.id, postTitle: post.title)
                .environmentObject(authViewModel)
        }
    }
    
    private var rootComments: [CommentWithProfile] {
        comments.filter { $0.comment.parentCommentId == nil }
    }
    
    private var commentChildren: [String: [CommentWithProfile]] {
        Dictionary(grouping: comments.filter { $0.comment.parentCommentId != nil }) { item in
            item.comment.parentCommentId!
        }
    }
    
    private func commentThread(for comment: CommentWithProfile, depth: Int = 0) -> some View {
        let replies = commentChildren[comment.id] ?? []
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                CommentCardView(
                    commentWithProfile: comment,
                    postId: post.id,
                    onCommentChanged: loadComments
                )
                .environmentObject(authViewModel)
                .padding(.leading, depth == 0 ? 0 : 24)
                
                HStack {
                    Spacer()
                    if let currentUserId = authViewModel.session?.user.id.uuidString,
                       comment.comment.userId == currentUserId {
                        Button(action: {
                            if armedDeleteCommentIDs.contains(comment.id) {
                                // Second tap: perform delete
                                commentPendingDeletion = comment
                                showDeleteConfirm = true
                            } else {
                                // First tap: arm
                                armedDeleteCommentIDs.insert(comment.id)
                                // Auto-disarm after 5 seconds
                                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                    armedDeleteCommentIDs.remove(comment.id)
                                }
                            }
                        }) {
                            Image(systemName: "trash")
                                .font(.subheadline)
                                .foregroundStyle(armedDeleteCommentIDs.contains(comment.id) ? .red : .secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule().fill(armedDeleteCommentIDs.contains(comment.id) ? Color.red.opacity(0.12) : Color.secondary.opacity(0.08))
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            Text(
                                armedDeleteCommentIDs.contains(comment.id)
                                ? "teahouse.comment.delete_again".localized
                                : "common.delete".localized
                            )
                        )
                    }
                }
                .padding(.trailing, depth == 0 ? 0 : 24)
                
                ForEach(replies) { reply in
                    commentThread(for: reply, depth: depth + 1)
                }
            }
            .contentShape(Rectangle())
        )
    }
    
    private func toggleLike() {
        guard authViewModel.isAuthenticated else {
            showLoginPrompt = true
            return
        }
        
        guard let userId = authViewModel.session?.user.id.uuidString else { return }
        let postId = post.id
        
        let descriptor = FetchDescriptor<UserLike>(
            predicate: #Predicate { like in
                like.userId == userId && like.postId == postId
            }
        )
        
        // 检查本地是否已点赞
        let isCurrentlyLiked = (try? modelContext.fetch(descriptor).first) != nil
        
        Task {
            do {
                if isCurrentlyLiked {
                    // 取消点赞 - 删除 Supabase 中的点赞记录
                    _ = try await supabase
                        .from("likes")
                        .delete()
                        .eq("post_id", value: postId)
                        .eq("user_id", value: userId)
                        .execute()
                    
                    // 更新本地
                    if let likes = try? modelContext.fetch(descriptor), !likes.isEmpty {
                        for like in likes {
                            modelContext.delete(like)
                        }
                        post.likes = max(0, post.likes - 1)
                    }
                } else {
                    // 添加点赞 - 插入 Supabase 点赞记录
                    let newLike = Like(
                        id: UUID().uuidString,
                        userId: userId,
                        postId: postId,
                        commentId: nil
                    )
                    
                    _ = try await supabase
                        .from("likes")
                        .insert(newLike)
                        .execute()
                    
                    // 更新本地
                    let like = UserLike(userId: userId, postId: postId)
                    modelContext.insert(like)
                    post.likes += 1
                }
                
                try modelContext.save()
            } catch {
                print("点赞操作失败: \(error.localizedDescription)")
            }
        }
    }
    
    private func deleteComment(_ item: CommentWithProfile) {
        guard authViewModel.isAuthenticated,
              let currentUserId = authViewModel.session?.user.id.uuidString else {
            showLoginPrompt = true
            return
        }
        // 仅允许删除自己的评论
        guard item.comment.userId == currentUserId else {
            return
        }
        Task {
            do {
                // 删除该评论（以及可能的子评论，若需要可在服务端设置级联删除）
                _ = try await supabase
                    .from("comments")
                    .delete()
                    .eq("id", value: item.comment.id)
                    .execute()
                await MainActor.run {
                    // 本地减少评论数（最简单处理：减 1；若有级联删除，建议服务端返回受影响行数）
                    post.comments = max(0, post.comments - 1)
                    // 关闭弹窗并刷新
                    commentPendingDeletion = nil
                    showDeleteConfirm = false
                    loadComments()
                }
            } catch {
                await MainActor.run {
                    print("❌ 删除评论失败: \(error.localizedDescription)")
                    showDeleteConfirm = false
                    commentPendingDeletion = nil
                }
            }
        }
    }
    
    private func loadComments() {
        isLoadingComments = true
        Task {
            do {
                let fetchedComments = try await teahouseService.fetchComments(postId: post.id)
                await MainActor.run {
                    comments = fetchedComments
                    isLoadingComments = false
                }
            } catch {
                await MainActor.run {
                    print("❌ 加载评论失败: \(error.localizedDescription)")
                    isLoadingComments = false
                }
            }
        }
    }
    
    private func submitComment() {
        print("🔵 submitComment 被调用")
        print("🔵 commentText: '\(commentText)'")
        print("🔵 isAuthenticated: \(authViewModel.isAuthenticated)")
        
        guard !commentText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty else {
            print("🔴 评论内容为空")
            return
        }
        guard authViewModel.isAuthenticated else {
            print("🔴 用户未登录")
            showLoginPrompt = true
            return
        }
        
        guard let userId = authViewModel.session?.user.id.uuidString else {
            print("🔴 无法获取用户ID")
            return
        }
        
        print("✅ 准备发送评论")
        isSubmitting = true
        let commentContent = commentText
        commentText = ""
        
        Task {
            do {
                let newComment = Comment(
                    id: UUID().uuidString,
                    postId: post.id,
                    userId: userId,
                    parentCommentId: nil,
                    content: commentContent,
                    isAnonymous: isAnonymous,
                    createdAt: Date()
                )
                
                print("📤 发送评论到 Supabase: \(newComment)")
                
                // 插入评论到 Supabase
                let response = try await supabase
                    .from("comments")
                    .insert(newComment)
                    .execute()
                
                print("✅ 评论发送成功: \(response)")
                
                // 更新本地评论计数并重新加载评论列表
                await MainActor.run {
                    post.comments += 1
                    isSubmitting = false
                    // 重新加载评论列表以显示新评论
                    loadComments()
                }
            } catch {
                await MainActor.run {
                    print("❌ 评论发送失败: \(error.localizedDescription)")
                    isSubmitting = false
                    // 如果失败，恢复评论文本
                    commentText = commentContent
                }
            }
        }
    }
    
    private func hideKeyboard() {
#if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
#endif
    }

    private func saveImageToPhotos(from url: URL) async {
#if canImport(UIKit)
        do {
            let image = try await loadUIImage(from: url)
            try await requestPhotoLibraryAuthorization()
            try await saveToPhotoLibrary(image)
            await MainActor.run {
                imageActionResultMessage = "teahouse.image.action.saved_to_photos".localized
                showImageActionResult = true
            }
        } catch {
            await MainActor.run {
                imageActionResultMessage = "teahouse.image.action.save_failed".localized(with: error.localizedDescription)
                showImageActionResult = true
            }
        }
#endif
    }

    private func copyImage(from url: URL) async {
#if canImport(UIKit)
        do {
            let image = try await loadUIImage(from: url)
            await MainActor.run {
                UIPasteboard.general.image = image
                imageActionResultMessage = "teahouse.image.action.copied".localized
                showImageActionResult = true
            }
        } catch {
            await MainActor.run {
                UIPasteboard.general.string = url.absoluteString
                imageActionResultMessage = "teahouse.image.action.copy_fallback_link".localized
                showImageActionResult = true
            }
        }
#endif
    }

    @ViewBuilder
    private func imageContextMenu(imageURL: URL) -> some View {
        Button {
            imageShareItems = [imageURL]
            showImageShareSheet = true
        } label: {
            Label("teahouse.image.menu.share".localized, systemImage: "square.and.arrow.up")
        }

        Button {
            Task { await saveImageToPhotos(from: imageURL) }
        } label: {
            Label("teahouse.image.menu.save_to_photos".localized, systemImage: "square.and.arrow.down")
        }

        Button {
            Task { await copyImage(from: imageURL) }
        } label: {
            Label("teahouse.image.menu.copy".localized, systemImage: "doc.on.doc")
        }

        Button {
            // 暂未支持
        } label: {
            Label("teahouse.image.menu.copy_subject".localized, systemImage: "circle.dashed.rectangle")
        }
        .disabled(true)

        Button {
            // 暂未支持
        } label: {
            Label("teahouse.image.menu.lookup".localized, systemImage: "magnifyingglass")
        }
        .disabled(true)
    }

    private func menuPreviewImage(url: URL) -> some View {
        KFImage(url)
            .placeholder {
                ZStack {
                    Color.secondary.opacity(0.08)
                    ProgressView()
                }
            }
            .retry(maxCount: 2, interval: .seconds(2))
            .resizable()
            .scaledToFill()
            .frame(width: 260, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func loadUIImage(from url: URL) async throws -> UIImage {
        if url.isFileURL {
            let data = try Data(contentsOf: url)
            guard let image = UIImage(data: data) else {
                throw NSError(
                    domain: "PostDetailView",
                    code: 101,
                    userInfo: [NSLocalizedDescriptionKey: "teahouse.image.error.decode_data_failed".localized]
                )
            }
            return image
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let image = UIImage(data: data) else {
            throw NSError(
                domain: "PostDetailView",
                code: 102,
                userInfo: [NSLocalizedDescriptionKey: "teahouse.image.error.decode_remote_failed".localized]
            )
        }
        return image
    }

    private func requestPhotoLibraryAuthorization() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                switch status {
                case .authorized, .limited:
                    continuation.resume(returning: ())
                case .denied, .restricted, .notDetermined:
                    continuation.resume(
                        throwing: NSError(
                            domain: "PostDetailView",
                            code: 103,
                            userInfo: [NSLocalizedDescriptionKey: "teahouse.image.error.photo_permission_denied".localized]
                        )
                    )
                @unknown default:
                    continuation.resume(
                        throwing: NSError(
                            domain: "PostDetailView",
                            code: 104,
                            userInfo: [NSLocalizedDescriptionKey: "teahouse.image.error.photo_permission_unknown".localized]
                        )
                    )
                }
            }
        }
    }

    private func saveToPhotoLibrary(_ image: UIImage) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }, completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(
                        throwing: NSError(
                            domain: "PostDetailView",
                            code: 105,
                            userInfo: [NSLocalizedDescriptionKey: "teahouse.image.error.save_failed".localized]
                        )
                    )
                }
            })
        }
    }
    
    private func updateSummarizationAvailability() {
        if let cached = OnDeviceSummaryAvailabilityCache.cachedAvailability() {
            self.canSummarizeOnDevice = cached
            if !OnDeviceSummaryAvailabilityCache.shouldRefresh() { return }
        }
        if isCheckingSummaryAvailability { return }
        isCheckingSummaryAvailability = true

        // TODO: 如果 SDK 提供了明确的 availability 枚举类型，例如：
        // switch model.availability {
        // case .available: self.canSummarizeOnDevice = true
        // case .unavailable(.deviceNotEligible): self.canSummarizeOnDevice = false
        // case .unavailable(.appleIntelligenceNotEnabled): self.canSummarizeOnDevice = false
        // case .unavailable(.modelNotReady): self.canSummarizeOnDevice = false
        // case .unavailable(_): self.canSummarizeOnDevice = false
        // }
        Task { @MainActor in
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                let instructions = "teahouse.summary.instructions".localized
                let session = LanguageModelSession(instructions: instructions)

                // Use a lightweight probe to avoid reflection on FoundationModels internals.
                do {
                    _ = try await session.respond(to: "ping")
                    self.canSummarizeOnDevice = true
                    OnDeviceSummaryAvailabilityCache.save(true)
                } catch {
                    self.canSummarizeOnDevice = false
                    OnDeviceSummaryAvailabilityCache.save(false)
                }
            } else {
                self.canSummarizeOnDevice = false
                OnDeviceSummaryAvailabilityCache.save(false)
            }
            #else
            self.canSummarizeOnDevice = false
            OnDeviceSummaryAvailabilityCache.save(false)
            #endif
            self.isCheckingSummaryAvailability = false
        }
    }
    
    @MainActor
    private func summarizePost() async {
        guard !isSummarizing else { return }
        isSummarizing = true
        summarizeError = nil
        summaryText = nil
        // Build the prompt from the post content and title
        let title = post.title
        let content = post.content
        let fullText = "teahouse.summary.prompt".localized(with: title, content)
        if #available(iOS 26.0, *) {
#if canImport(FoundationModels)
    do {
        let generator = try await TextGenerator.makeDefault()
        let request = TextGenerationRequest(prompt: fullText, maxTokens: 200)
        let response = try await generator.generate(request)
        self.summaryText = response.text
    } catch {
        self.summarizeError = error.localizedDescription
    }
#else
    // Fallback: 简单截断作为示例
    self.summaryText = "teahouse.summary.fallback_prefix".localized + String(fullText.prefix(120))
#endif
            self.showSummarySheet = true
        } else {
            self.summarizeError = "teahouse.summary.unsupported_system".localized
            self.showSummarySheet = true
        }
        isSummarizing = false
    }
    
    
    
    struct CategoryBarOverlay: View {
        let categories: [CategoryItem]
        @Binding var selectedCategory: Int
        
        var body: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(categories) { category in
                        CategoryTag(
                            title: category.title,
                            isSelected: selectedCategory == category.id
                        ) {
                            withAnimation {
                                selectedCategory = category.id
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - Image Preview View

    struct ImagePreviewView: View {
        @Environment(\.dismiss) var dismiss
        @Environment(\.displayScale) private var displayScale
        let url: URL

        @State private var uiImage: UIImage? = nil
        @State private var scale: CGFloat = 1.0
        @State private var lastScale: CGFloat = 1.0
        @State private var offset: CGSize = .zero
        @State private var lastOffset: CGSize = .zero
        @State private var isSaving: Bool = false
        @State private var showSaveSuccess: Bool = false
        @State private var showSaveError: Bool = false
        @State private var saveErrorMessage: String = ""
        @State private var showShareSheet: Bool = false
        @State private var shareItems: [Any] = []

        var body: some View {
            ZStack(alignment: .topTrailing) {
                Color.black.ignoresSafeArea()

                GeometryReader { proxy in
                    let maxW = proxy.size.width
                    let maxH = proxy.size.height

                    ZStack {
                        KFImage(url)
                            .downsampling(size: CGSize(width: max(1, maxW), height: max(1, maxH)))
                            .scaleFactor(displayScale)
                            .cancelOnDisappear(true)
                            .placeholder {
                                ProgressView()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .retry(maxCount: 2, interval: .seconds(2))
                            .onSuccess { result in
                                #if canImport(UIKit)
                                uiImage = result.image
                                #endif
                            }
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: maxW, maxHeight: maxH)
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                SimultaneousGesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            let newScale = lastScale * value
                                            scale = max(1.0, min(newScale, 6.0))
                                        }
                                        .onEnded { _ in
                                            lastScale = scale
                                        },
                                    DragGesture()
                                        .onChanged { v in
                                            offset = CGSize(width: lastOffset.width + v.translation.width, height: lastOffset.height + v.translation.height)
                                        }
                                        .onEnded { _ in
                                            lastOffset = offset
                                        }
                                )
                            )
                            .onTapGesture(count: 2) {
                                // 双击复位或放大
                                withAnimation(.spring()) {
                                    if scale > 1.1 {
                                        scale = 1.0; lastScale = 1.0; offset = .zero; lastOffset = .zero
                                    } else {
                                        scale = 2.0; lastScale = 2.0
                                    }
                                }
                            }
                            .contextMenu {
                                Button {
#if canImport(UIKit)
                                    if let image = uiImage {
                                        shareItems = [image]
                                    } else {
                                        shareItems = [url]
                                    }
                                    showShareSheet = true
#endif
                                } label: {
                                    Label("teahouse.image.menu.share".localized, systemImage: "square.and.arrow.up")
                                }

                                Button {
                                    Task { await saveImageAction() }
                                } label: {
                                    Label("teahouse.image.menu.save_to_photos".localized, systemImage: "square.and.arrow.down")
                                }

                                Button {
#if canImport(UIKit)
                                    if let image = uiImage {
                                        UIPasteboard.general.image = image
                                    } else {
                                        UIPasteboard.general.string = url.absoluteString
                                    }
#endif
                                } label: {
                                    Label("teahouse.image.menu.copy".localized, systemImage: "doc.on.doc")
                                }

                                Button {
                                    // 暂未支持
                                } label: {
                                    Label("teahouse.image.menu.copy_subject".localized, systemImage: "circle.dashed.rectangle")
                                }
                                .disabled(true)

                                Button {
                                    // 暂未支持
                                } label: {
                                    Label("teahouse.image.menu.lookup".localized, systemImage: "magnifyingglass")
                                }
                                .disabled(true)
                            } preview: {
                                KFImage(url)
                                    .downsampling(size: CGSize(width: 280, height: 220))
                                    .scaleFactor(displayScale)
                                    .cancelOnDisappear(true)
                                    .placeholder {
                                        ZStack {
                                            Color.secondary.opacity(0.08)
                                            ProgressView()
                                        }
                                    }
                                    .retry(maxCount: 2, interval: .seconds(2))
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 280, height: 220)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                    }
                    .frame(maxWidth: maxW, maxHeight: maxH)
                }

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white)
                        .padding(16)
                }
            }
            .onDisappear {
                uiImage = nil
                shareItems.removeAll()
                scale = 1.0
                lastScale = 1.0
                offset = .zero
                lastOffset = .zero
            }
            .overlay {
                if isSaving {
                    ProgressView {
                        Text("teahouse.saving".localized)
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
#if canImport(UIKit)
            .sheet(isPresented: $showShareSheet) {
                ActivityView(activityItems: shareItems)
            }
#endif
            .alert(Text("teahouse.save_success"), isPresented: $showSaveSuccess) {
                Button(role: .cancel) { } label: { Text("common.ok".localized) }
            }
            .alert(Text("teahouse.save_failed"), isPresented: $showSaveError) {
                Button(role: .cancel) { } label: { Text("common.ok".localized) }
            } message: {
                Text(saveErrorMessage)
            }
        }

        private func saveImageAction() async {
            guard let image = uiImage else {
                saveErrorMessage = "teahouse.image.error.image_not_loaded".localized
                showSaveError = true
                return
            }
            await MainActor.run { isSaving = true }
            do {
                try await requestAndSave(image: image)
                await MainActor.run {
                    isSaving = false
                    showSaveSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    saveErrorMessage = error.localizedDescription
                    showSaveError = true
                }
            }
        }

        private func requestAndSave(image: UIImage) async throws {
            // 请求权限
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                switch status {
                case .authorized, .limited:
                    continuation.resume(returning: ())
                case .denied, .restricted, .notDetermined:
                    continuation.resume(
                        throwing: NSError(
                            domain: "Teahouse",
                            code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "teahouse.image.error.photo_permission_denied".localized]
                        )
                    )
                @unknown default:
                    continuation.resume(
                        throwing: NSError(
                            domain: "Teahouse",
                            code: 2,
                            userInfo: [NSLocalizedDescriptionKey: "teahouse.image.error.photo_permission_unknown".localized]
                        )
                    )
                }
            }
        }

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }, completionHandler: { success, error in
                    if let e = error {
                        continuation.resume(throwing: e)
                    } else if success {
                        continuation.resume(returning: ())
                    } else {
                        continuation.resume(
                            throwing: NSError(
                                domain: "Teahouse",
                                code: 3,
                                userInfo: [NSLocalizedDescriptionKey: "teahouse.image.error.save_failed".localized]
                            )
                        )
                    }
                })
            }
        }
    }
    
    // MARK: - VisualEffectBlur
    struct VisualEffectBlur: UIViewRepresentable {
        func makeUIView(context: Context) -> UIVisualEffectView {
            UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        }
        func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
    }
}
