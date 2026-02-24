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
    @State private var isLiked = false
    
    @StateObject private var teahouseService = TeahouseService()
    
    private var isAuthorPrivileged: Bool {
        return post.isAuthorPrivileged == true
    }
    
    private var currentUserId: String? {
        authViewModel.session?.user.id.uuidString
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
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd"
            return formatter.string(from: date)
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
            onLike: { toggleLike() },
            onReport: { showReportSheet = true },
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
            if comments.isEmpty && !isLoadingComments {
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
    
    var body: some View {
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
        .onAppear {
            selectedImageForPreview = nil
            loadComments()
            updateSummarizationAvailability()
            checkLikeStatus()
        }
        .onChange(of: authViewModel.session?.user.id) { _, _ in
            checkLikeStatus()
        }
        .onChange(of: post.id) { _, _ in
            checkLikeStatus()
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
                #if !os(macOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
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
        #if !os(macOS)
        .toolbar(.hidden, for: .tabBar)
        #endif
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SeparateMessageInputField(
                text: $commentText,
                isAnonymous: $isAnonymous,
                isLoading: isSubmitting,
                isAuthenticated: authViewModel.isAuthenticated,
                onSend: { submitComment() },
                onRequireLogin: { showLoginPrompt = true }
            )
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
        .sheet(isPresented: $showReportSheet) {
            ReportPostView(postId: post.id, postTitle: post.title)
                .environmentObject(authViewModel)
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
                print("点赞操作失败: \(error.localizedDescription)")
            }

            DispatchQueue.main.async {
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
                let fetchedComments = try await PostDetailOperations.fetchComments(
                    service: teahouseService,
                    postId: post.id
                )
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
        guard !commentText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty else {
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
        commentText = ""
        
        Task {
            do {
                try await PostDetailOperations.submitComment(
                    postId: post.id,
                    userId: userId,
                    content: commentContent,
                    isAnonymous: isAnonymous,
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
            if #available(iOS 26.0, macOS 26.0, *) {
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
        if #available(iOS 26.0, macOS 26.0, *) {
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
}
