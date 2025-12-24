//
//  ReportedPostsView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/24.
//

import SwiftUI
import SwiftData

/// 被举报帖子管理视图（管理员功能）
struct ReportedPostsView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var teahouseService = TeahouseService()
    @State private var reportedPosts: [ReportedPost] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var showDeleteConfirmation = false
    @State private var postToDelete: ReportedPost?
    @State private var showIgnoreConfirmation = false
    @State private var reportToIgnore: (reportId: String, postId: String)?
    
    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Text("加载中...")
                    Spacer()
                }
            } else if let error = error {
                HStack {
                    Spacer()
                    Text("错误: \(error)")
                        .foregroundColor(.red)
                    Spacer()
                }
            } else if reportedPosts.isEmpty {
                HStack {
                    Spacer()
                    Text("暂无被举报的帖子")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ForEach(reportedPosts) { post in
                    NavigationLink(destination: PostDetailView(post: convertToTeahousePost(post))) {
                        VStack(alignment: .leading, spacing: 8) {
                            // 帖子标题和举报次数
                            HStack {
                                Text(post.post.title ?? "无标题")
                                    .font(.headline)
                                    .lineLimit(1)
                                Spacer()
                                Text("举报: \(post.post.reportCount ?? 0)")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            
                            // 帖子内容预览
                            Text(post.post.content ?? "无内容")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                            
                            // 举报原因
                            if !post.reports.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("举报原因:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    ForEach(post.reports.prefix(3)) { report in
                                        HStack {
                                            Text("• \(report.reason)")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                            Spacer()
                                            Text(report.createdAt.formatted(date: .abbreviated, time: .shortened))
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    if post.reports.count > 3 {
                                        Text("...还有\(post.reports.count - 3)条举报")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(Color.orange.opacity(0.05))
                                .cornerRadius(6)
                            }
                            
                            // 发布者信息
                            HStack {
                                if let profile = post.profile {
                                    Text("发布者: \(profile.username)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("发布者: 匿名")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text(post.post.createdAt?.formatted(date: .abbreviated, time: .shortened) ?? "未知时间")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        // 删除按钮
                        Button(role: .destructive) {
                            postToDelete = post
                            showDeleteConfirmation = true
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                        
                        // 忽略按钮
                        Button {
                            if let firstReport = post.reports.first,
                               let postId = post.post.id {
                                reportToIgnore = (firstReport.id, postId)
                                showIgnoreConfirmation = true
                            }
                        } label: {
                            Label("忽略", systemImage: "eye.slash")
                        }
                        .tint(.orange)
                    }
                }
            }
        }
        .navigationTitle("待处理举报")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadReportedPosts()
        }
        .refreshable {
            await loadReportedPosts()
        }
        .alert("确认删除", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let post = postToDelete {
                    Task {
                        await deletePost(post)
                    }
                }
            }
        } message: {
            if let post = postToDelete {
                let title = post.post.title ?? "无标题"
                Text("确定要删除帖子\"\(title)\"吗？此操作不可撤销。")
            }
        }
        .alert("确认忽略", isPresented: $showIgnoreConfirmation) {
            Button("取消", role: .cancel) {}
            Button("忽略") {
                if let reportInfo = reportToIgnore {
                    Task {
                        await ignoreReport(reportId: reportInfo.reportId, postId: reportInfo.postId)
                    }
                }
            }
        } message: {
            Text("确定要忽略这条举报吗？这条举报将被移除，但帖子将保留。")
        }
    }
    
    private func loadReportedPosts() async {
        isLoading = true
        error = nil
        
        do {
            reportedPosts = try await teahouseService.fetchReportedPosts()
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func deletePost(_ post: ReportedPost) async {
        guard let postId = post.post.id else {
            self.error = "帖子ID无效"
            return
        }
        
        do {
            try await teahouseService.deletePost(postId: postId)
            // 从列表中移除
            reportedPosts.removeAll { $0.post.id == postId }
        } catch {
            self.error = "删除失败: \(error.localizedDescription)"
        }
    }
    
    private func ignoreReport(reportId: String, postId: String) async {
        do {
            try await teahouseService.ignoreReport(reportId: reportId, postId: postId)
            // 从列表中移除该帖子（如果举报数为0）
            await loadReportedPosts() // 重新加载以反映更新后的举报计数
        } catch {
            self.error = "忽略失败: \(error.localizedDescription)"
        }
    }
    
    private func convertToTeahousePost(_ reportedPost: ReportedPost) -> TeahousePost {
        let post = reportedPost.post
        let profile = reportedPost.profile
        
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