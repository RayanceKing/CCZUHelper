//
//  TeahouseView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/11/30.
//

import SwiftUI
import SwiftData

/// 茶楼视图 - 社交/论坛功能
struct TeahouseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    
    @Query(sort: \TeahousePost.createdAt, order: .reverse) private var allPosts: [TeahousePost]
    
    @State private var selectedCategory = 0
    @State private var showCreatePost = false
    
    private let categories = ["全部", "学习", "生活", "二手", "表白墙", "失物招领"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 分类选择器
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(categories.indices, id: \.self) { index in
                            CategoryTag(
                                title: categories[index],
                                isSelected: selectedCategory == index
                            ) {
                                withAnimation {
                                    selectedCategory = index
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                
                Divider()
                
                // 帖子列表
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredPosts) { post in
                            PostRow(post: post, onLike: {
                                toggleLike(post)
                            })
                            Divider()
                        }
                        
                        if filteredPosts.isEmpty {
                            ContentUnavailableView {
                                Label("暂无帖子", systemImage: "bubble.left.and.bubble.right")
                            } description: {
                                Text("点击右上角发布第一条帖子吧～")
                            }
                            .frame(height: 400)
                        }
                    }
                }
            }
            .navigationTitle("茶楼")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showCreatePost = true }) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .sheet(isPresented: $showCreatePost) {
                CreatePostView()
                    .environment(settings)
            }
        }
    }
    
    private var filteredPosts: [TeahousePost] {
        if selectedCategory == 0 {
            return allPosts
        } else {
            let category = categories[selectedCategory]
            return allPosts.filter { $0.category == category }
        }
    }
    
    private func toggleLike(_ post: TeahousePost) {
        // 检查用户是否已点赞
        guard let userId = settings.username ?? "guest" as String? else { return }
        
        let postId = post.id
        let descriptor = FetchDescriptor<UserLike>(
            predicate: #Predicate { like in
                like.userId == userId && like.postId == postId
            }
        )
        
        if let likes = try? modelContext.fetch(descriptor), !likes.isEmpty {
            // 已点赞，取消点赞
            for like in likes {
                modelContext.delete(like)
            }
            post.likes = max(0, post.likes - 1)
        } else {
            // 未点赞，添加点赞
            let like = UserLike(userId: userId, postId: post.id)
            modelContext.insert(like)
            post.likes += 1
        }
    }
    
    // 移除示例数据
    }


// 移除旧的Post模型，因为现在使用TeahousePost

/// 分类标签
struct CategoryTag: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// 帖子行
struct PostRow: View {
    @Environment(\.modelContext) private var modelContext
    let post: TeahousePost
    let onLike: () -> Void

    @Environment(AppSettings.self) private var settings

    @Query var userLikes: [UserLike]
    
    init(post: TeahousePost, onLike: @escaping () -> Void) {
        self.post = post
        self.onLike = onLike
        // Capture values for predicate construction
        let postId = post.id
        let userId = AppSettings().username ?? "guest"
        self._userLikes = Query(filter: #Predicate { like in
            like.postId == postId && like.userId == userId
        })
    }
    
    private var isLiked: Bool {
        userLikes.contains { $0.postId == post.id }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 用户信息
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(post.author)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if post.isLocal {
                            Text("本地")
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .foregroundStyle(.orange)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(timeAgoString(from: post.createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text(post.category)
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
            }
            
            // 帖子内容
            VStack(alignment: .leading, spacing: 6) {
                Text(post.title)
                    .font(.headline)
                
                Text(post.content)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            
            // 图片（如果有）
            if !post.images.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(post.images.prefix(3), id: \.self) { imagePath in
                            if let uiImage = loadImage(from: imagePath) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }
            
            // 互动按钮
            HStack(spacing: 24) {
                Button(action: onLike) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundStyle(isLiked ? .red : .secondary)
                        Text("\(post.likes)")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                        Text("\(post.comments)")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
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
            return formatter.string(from: date)
        }
    }
    
    private func loadImage(from path: String) -> UIImage? {
        if path.hasPrefix("http") {
            // TODO: 从网络加载图片
            return nil
        } else {
            // 从本地加载
            return UIImage(contentsOfFile: path)
        }
    }
}

// 移除旧的Post模型，因为现在使用TeahousePost

#Preview {
    TeahouseView()
        .environment(AppSettings())
        .modelContainer(for: [TeahousePost.self, UserLike.self], inMemory: true)
}

