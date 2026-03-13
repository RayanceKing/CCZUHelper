//
//  PostDetailView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/17.
import Kingfisher

import SwiftUI
import SwiftData
import Supabase
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

#if canImport(Foundation)
import Foundation
#endif
#if canImport(FoundationModels)
import FoundationModels
#endif

#if os(macOS)
typealias PostDetailPlatformImage = NSImage
#elseif canImport(UIKit)
typealias PostDetailPlatformImage = UIImage
#endif

struct PostDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @Environment(\.modelContext) var modelContext
    @Environment(AppSettings.self) private var settings
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    let post: TeahousePost
    
    @State private var commentText = ""
    @State private var isSubmitting = false
    @State private var showLoginPrompt = false
    @State private var comments: [CommentWithProfile] = []
    @State private var isLoadingComments = false
    @State private var hasLoadedComments = false
    @State private var commentLoadingTask: Task<Void, Never>? = nil
    @State private var selectedImageIndex: Int = 0
    @State private var showImagePreview = false
    @State private var isAnonymous = false
    @State private var showDeleteConfirm = false
    @State private var commentPendingDeletion: CommentWithProfile? = nil
    @State private var armedDeleteCommentIDs: Set<String> = []

    @State var isSummarizing = false
    @State var summaryText: String? = nil
    @State var showSummarySheet = false
    @State var summarizeError: String? = nil
    
    @State var canSummarizeOnDevice = false
    @State var isCheckingSummaryAvailability = false
    @State private var showReportSheet = false
    @State private var showReportUserSheet = false
    @State var showModerationActions = false
    @State var showBlockUserConfirm = false
    @State var showBlockPostConfirm = false
    @State var showDeletePostConfirm = false
    @State var showModerationError = false
    @State var moderationErrorMessage = ""
    @State private var showImageShareSheet = false
    @State private var imageShareItems: [Any] = []
    @State private var showImageActionResult = false
    @State private var imageActionResultMessage = ""
    @State private var isKeyboardPresented = false
    @State private var isLiked = false
    @State private var selectedCommentImageURL: URL? = nil
    @State private var selectedCommentImagePreview: PostDetailPlatformImage? = nil
    @State private var showCommentImagePicker = false
    
    @StateObject var teahouseService = TeahouseService()

    private let minimumSkeletonDisplayNanos: UInt64 = 300_000_000
    private static let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        return formatter
    }()
    
    private var isAuthorPrivileged: Bool {
        return post.isAuthorPrivileged == true
    }
    
    private var currentUserId: String? {
        authViewModel.session?.user.id.uuidString
    }

    private var canModerateAuthor: Bool {
        guard let authorId = post.authorId, let currentUserId else { return false }
        return authorId != currentUserId
    }

    private var moderationTargetName: String {
        post.author.isEmpty ? "teahouse.moderation.target_default".localized : post.author
    }

    var isOwnPost: Bool {
        guard let currentUserId else { return false }
        if let authorId = post.authorId, authorId == currentUserId {
            return true
        }
        if let authorId = post.authorId, let username = settings.username, authorId == username {
            return true
        }
        return false
    }
    
    private func checkLikeStatus() {
        guard let userId = currentUserId else {
            isLiked = false
            return
        }

        do {
            isLiked = try PostDetailOperations.fetchLikeStatus(
                modelContext: modelContext,
                postId: post.id,
                userId: userId
            )
        } catch {
            isLiked = false
        }
    }

    private var postCardBackgroundColor: Color {
        #if os(macOS)
        return Color(nsColor: colorScheme == .dark ? .controlBackgroundColor : .windowBackgroundColor)
        #else
        return Color(colorScheme == .dark ? .systemGray6 : .white)
        #endif
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
            return Self.monthDayFormatter.string(from: date)
        }
    }
    
    private var titleAndContentView: some View {
        PostDetailTitleContentView(title: post.title, content: post.content)
    }
    
    private var imagesGridView: some View {
        Group {
            if !post.images.isEmpty {
                let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Array(post.images.enumerated()), id: \.offset) { index, imagePath in
                        if let url = URL(string: imagePath), !imagePath.isEmpty {
                            Button {
                                selectedImageIndex = index
                                showImagePreview = true
                            } label: {
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
                            }
                            .buttonStyle(.plain)
                            .contentShape(RoundedRectangle(cornerRadius: 8))
                            .contextMenu {
                                PostDetailImageContextMenu(
                                    onShare: {
                                        imageShareItems = [url]
                                        showImageShareSheet = true
                                    },
                                    onSave: {
                                        Task { await saveImageToPhotos(from: url) }
                                    },
                                    onCopy: {
                                        Task { await copyImage(from: url) }
                                    }
                                )
                            } preview: {
                                PostDetailImageMenuPreview(url: url)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var headerView: some View {
        PostDetailHeaderView(
            post: post,
            isAuthorPrivileged: isAuthorPrivileged,
            timeText: timeAgoString(from: post.createdAt)
        )
    }
    
    private var actionButtonsView: some View {
        PostDetailActionButtonsView(
            isLiked: isLiked,
            likes: post.likes,
            comments: post.comments,
            isAuthenticated: authViewModel.isAuthenticated,
            isOwnPost: isOwnPost,
            onLike: { toggleLike() },
            onModeration: { showModerationActions = true },
            onDeletePost: { showDeletePostConfirm = true },
            onRequireLogin: { showLoginPrompt = true }
        )
    }
    
    private var mainContentView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if post.reportCount > 5 {
                PostDetailHiddenView(colorScheme: colorScheme, backgroundColor: postCardBackgroundColor)
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
                        .fill(postCardBackgroundColor)
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
            if shouldShowCommentSkeleton {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(skeletonBaseColor)
                            .frame(width: 96, height: 10)
                    }
                    CommentSkeletonListView(baseColor: skeletonBaseColor)
                }
                    .modifier(ShimmerModifier(highlightColor: skeletonHighlightColor))
                    .allowsHitTesting(false)
                    .padding(.vertical, 8)
            } else if comments.isEmpty {
                Text("teahouse.post.no_comments".localized)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 32)
            } else {
                PostDetailCommentsSection(
                    comments: comments,
                    postId: post.id,
                    currentUserId: authViewModel.session?.user.id.uuidString,
                    onCommentChanged: loadComments,
                    onConfirmDelete: { item in
                        commentPendingDeletion = item
                        showDeleteConfirm = true
                    },
                    armedDeleteCommentIDs: $armedDeleteCommentIDs
                )
                .environmentObject(authViewModel)
            }
            Spacer(minLength: 40)
        }
    }
    
    private var previewURLs: [URL] {
        post.images.compactMap { path in
            guard !path.isEmpty else { return nil }
            return URL(string: path)
        }
    }

    private var shouldShowCommentSkeleton: Bool {
        isLoadingComments || !hasLoadedComments
    }

    private var skeletonBaseColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.22) : Color.black.opacity(0.16)
    }

    private var skeletonHighlightColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.45) : Color.white.opacity(0.95)
    }

    @ViewBuilder
    private var rootContentView: some View {
        ZStack {
            pageBackground
                .ignoresSafeArea()

            #if os(macOS)
            ScrollView {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    mainContentView
                        .padding()
                        .frame(maxWidth: 760, alignment: .leading)
                        .padding(.horizontal, 20)
                    Spacer(minLength: 0)
                }
                .padding(.top, 6)
            }
            #else
            ScrollView {
                mainContentView
                    .padding()
            }
            #endif
        }
    }

    @ViewBuilder
    private var imagePreviewSheetView: some View {
        if !previewURLs.isEmpty {
            ImagePreviewView(
                urls: previewURLs,
                initialIndex: min(max(0, selectedImageIndex), previewURLs.count - 1)
            )
        }
    }

    private var summarySheetView: some View {
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
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if #available(iOS 26.0, macOS 26.0, visionOS 2, *) {
                        Button(role: .cancel) { showSummarySheet = false }
                    } else {
                        Button("common.close".localized) { showSummarySheet = false }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func commentPreviewImageView(_ preview: PostDetailPlatformImage) -> some View {
        #if canImport(UIKit)
        Image(uiImage: preview)
            .resizable()
            .scaledToFill()
            .frame(width: 92, height: 92)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
        #elseif canImport(AppKit)
        Image(nsImage: preview)
            .resizable()
            .scaledToFill()
            .frame(width: 92, height: 92)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
        #endif
    }

    private var commentInputBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let preview = selectedCommentImagePreview {
                ZStack(alignment: .topTrailing) {
                    commentPreviewImageView(preview)

                    Button {
                        clearSelectedCommentImage()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white, .black.opacity(0.55))
                    }
                    .offset(x: 6, y: -6)
                }
                .padding(.leading, 8)
            }

            SeparateMessageInputField(
                text: $commentText,
                isAnonymous: $isAnonymous,
                hasSelectedImage: selectedCommentImageURL != nil,
                isLoading: isSubmitting,
                isAuthenticated: authViewModel.isAuthenticated,
                onSend: { submitComment() },
                onSelectImage: {
                    showCommentImagePicker = true
                },
                onRemoveImage: {
                    clearSelectedCommentImage()
                },
                onRequireLogin: { showLoginPrompt = true }
            )
        }
        #if os(macOS)
        .frame(maxWidth: 700)
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
        #else
        .frame(maxWidth: 700)
        .padding(.horizontal, 18)
        .padding(.bottom, isKeyboardPresented ? 8 : -4)
        #endif
    }

    var body: some View {
        rootContentView
        .onAppear {
            selectedImageIndex = 0
            comments = []
            hasLoadedComments = false
            loadComments()
            updateSummarizationAvailability()
            checkLikeStatus()
        }
        .onChange(of: authViewModel.session?.user.id) { _, _ in
            checkLikeStatus()
        }
        .onChange(of: post.id) { _, _ in
            checkLikeStatus()
            comments = []
            hasLoadedComments = false
            loadComments()
        }
        .onDisappear {
            selectedImageIndex = 0
            commentLoadingTask?.cancel()
            commentLoadingTask = nil
            summaryText = nil
            summarizeError = nil
            ImageCache.default.clearMemoryCache()
        }
        .onReceive(NotificationCenter.default.publisher(for: .teahouseUserBlocked)) { notification in
            guard let blockedId = notification.object as? String,
                  blockedId == post.authorId else { return }
            dismiss()
        }
        .navigationTitle(post.category ?? "teahouse.post.default_title".localized)
        .toolbar {
            #if os(iOS)
            if #available(iOS 26.0, macOS 26.0, visionOS 2, *) {
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
            selectedImageIndex = 0
        }) {
            imagePreviewSheetView
        }
        .sheet(isPresented: $showSummarySheet) {
            summarySheetView
        }
        .sheet(isPresented: $showCommentImagePicker) {
            ImagePickerView(completion: { url in
                guard let url else { return }
                selectedCommentImageURL = url
                selectedCommentImagePreview = PostDetailPlatformImage(contentsOfFile: url.path)
                showCommentImagePicker = false
            }, filePrefix: "temp_comment")
        }
        .contentShape(Rectangle())
        .onTapGesture {
            hideKeyboard()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            commentInputBar
        }
        #if canImport(UIKit)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardPresented = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardPresented = false
        }
        #endif
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
        .alert("user_posts.delete_post.title".localized, isPresented: $showDeletePostConfirm) {
            Button("common.cancel".localized, role: .cancel) { }
            Button("common.delete".localized, role: .destructive) {
                deleteCurrentPost()
            }
        } message: {
            Text(String(format: "user_posts.delete_confirm_message".localized, post.title))
        }
        .alert("teahouse.moderation.block_user_title".localized, isPresented: $showBlockUserConfirm) {
            Button("common.cancel".localized, role: .cancel) { }
            Button("teahouse.moderation.block_user_confirm".localized, role: .destructive) {
                blockAuthor()
            }
        } message: {
            Text(String(format: "teahouse.moderation.block_user_message".localized, moderationTargetName))
        }
        .alert("teahouse.moderation.block_post_title".localized, isPresented: $showBlockPostConfirm) {
            Button("common.cancel".localized, role: .cancel) { }
            Button("teahouse.moderation.block_post_confirm".localized, role: .destructive) {
                blockCurrentPost()
            }
        } message: {
            Text("teahouse.moderation.block_post_message".localized)
        }
        .alert("teahouse.moderation.error_title".localized, isPresented: $showModerationError) {
            Button("common.ok".localized, role: .cancel) { }
        } message: {
            Text(moderationErrorMessage)
        }
        .confirmationDialog("teahouse.moderation.more_actions".localized, isPresented: $showModerationActions, titleVisibility: .visible) {
            Button("teahouse.moderation.report_post".localized) {
                showReportSheet = true
            }
            if canModerateAuthor {
                Button("teahouse.moderation.report_user".localized) {
                    showReportUserSheet = true
                }
                Button("teahouse.moderation.block_user".localized, role: .destructive) {
                    showBlockUserConfirm = true
                }
            }
            Button("teahouse.moderation.block_post".localized, role: .destructive) {
                showBlockPostConfirm = true
            }
            Button("common.cancel".localized, role: .cancel) { }
        }
        .sheet(isPresented: $showReportSheet) {
            ReportPostView(postId: post.id, postTitle: post.title)
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showReportUserSheet) {
            if let authorId = post.authorId {
                ReportUserView(userId: authorId, username: moderationTargetName)
            }
        }
#if os(macOS)
        .frame(minWidth: 700, minHeight: 620)
#endif
    }
    
    private func toggleLike() {
        guard authViewModel.isAuthenticated else {
            showLoginPrompt = true
            return
        }

        guard let userId = authViewModel.session?.user.id.uuidString else { return }
        Task {
            do {
                let delta = try await PostDetailOperations.toggleLike(
                    modelContext: modelContext,
                    postId: post.id,
                    userId: userId
                )
                await MainActor.run {
                    post.likes = max(0, post.likes + delta)
                }
            } catch {
                print("teahouse.like.error".localized(with: error.localizedDescription))
            }

            await MainActor.run {
                checkLikeStatus()
                NotificationCenter.default.post(name: NSNotification.Name("TeahouseLikeToggled"), object: nil)
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
                try await PostDetailOperations.deleteComment(commentId: item.comment.id)
                await MainActor.run {
                    post.comments = max(0, post.comments - 1)
                    commentPendingDeletion = nil
                    showDeleteConfirm = false
                    loadComments()
                }
            } catch {
                await MainActor.run {
                    print("teahouse.comment.delete_error".localized(with: error.localizedDescription))
                    showDeleteConfirm = false
                    commentPendingDeletion = nil
                }
            }
        }
    }
    
    private func loadComments() {
        commentLoadingTask?.cancel()
        isLoadingComments = true
        let loadingStartedAt = ContinuousClock.now

        commentLoadingTask = Task {
            do {
                let fetchedComments = try await PostDetailOperations.fetchComments(
                    service: teahouseService,
                    postId: post.id
                )

                let elapsed = loadingStartedAt.duration(to: .now)
                if elapsed < .nanoseconds(Int64(minimumSkeletonDisplayNanos)) {
                    let remaining = .nanoseconds(Int64(minimumSkeletonDisplayNanos)) - elapsed
                    try? await Task.sleep(for: remaining)
                }

                if Task.isCancelled { return }

                await MainActor.run {
                    comments = fetchedComments
                    isLoadingComments = false
                    hasLoadedComments = true
                }
            } catch {
                if Task.isCancelled { return }

                await MainActor.run {
                    print("teahouse.comment.load_error".localized(with: error.localizedDescription))
                    isLoadingComments = false
                    hasLoadedComments = true
                }
            }
        }
    }
    
    private func submitComment() {
        guard !commentText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty || selectedCommentImageURL != nil else {
            return
        }
        guard authViewModel.isAuthenticated else {
            showLoginPrompt = true
            return
        }
        guard let userId = authViewModel.session?.user.id.uuidString else {
            return
        }

        isSubmitting = true
        let commentContent = commentText
        let commentImageURL = selectedCommentImageURL
        commentText = ""
        clearSelectedCommentImage()
        
        Task {
            do {
                var uploadedPhotoURL: String? = nil
                if let localImageURL = commentImageURL {
                    uploadedPhotoURL = try await ImageUploadService.uploadImage(at: localImageURL)
                }
                try await PostDetailOperations.submitComment(
                    postId: post.id,
                    userId: userId,
                    content: commentContent,
                    isAnonymous: isAnonymous,
                    photoUrl: uploadedPhotoURL
                )
                await MainActor.run {
                    post.comments += 1
                    isSubmitting = false
                    loadComments()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    commentText = commentContent
                    if let localImageURL = commentImageURL {
                        selectedCommentImageURL = localImageURL
                        selectedCommentImagePreview = PostDetailPlatformImage(contentsOfFile: localImageURL.path)
                    }
                }
            }
        }
    }

    private func clearSelectedCommentImage() {
        selectedCommentImageURL = nil
        selectedCommentImagePreview = nil
    }
    
    private func hideKeyboard() {
#if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
#endif
    }

    private func saveImageToPhotos(from url: URL) async {
#if canImport(UIKit)
        do {
            let image = try await PostDetailImageIO.loadImage(from: url)
            try await PostDetailImageIO.requestPhotoLibraryAuthorization()
            try await PostDetailImageIO.saveToPhotoLibrary(image)
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
            let image = try await PostDetailImageIO.loadImage(from: url)
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
}

private struct CommentSkeletonListView: View {
    let baseColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(0..<4, id: \.self) { _ in
                CommentSkeletonRow(baseColor: baseColor)
            }
        }
    }
}

private struct CommentSkeletonRow: View {
    let baseColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(baseColor)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(baseColor)
                        .frame(width: 120, height: 12)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(baseColor)
                        .frame(width: 80, height: 10)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(baseColor)
                    .frame(height: 12)
                RoundedRectangle(cornerRadius: 4)
                    .fill(baseColor)
                    .frame(width: 220, height: 12)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(baseColor.opacity(0.35))
        )
    }
}

private struct ShimmerModifier: ViewModifier {
    let highlightColor: Color
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { proxy in
                    let width = proxy.size.width
                    LinearGradient(
                        gradient: Gradient(colors: [
                            highlightColor.opacity(0),
                            highlightColor,
                            highlightColor.opacity(0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: width * 1.5)
                    .offset(x: phase * width)
                }
                .blendMode(.screen)
            }
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}
