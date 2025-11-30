//
//  TeahouseView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/11/30.
//

import SwiftUI

/// 茶楼视图 - 社交/论坛功能
struct TeahouseView: View {
    @Environment(AppSettings.self) private var settings
    
    @State private var selectedCategory = 0
    
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
                        ForEach(samplePosts) { post in
                            PostRow(post: post)
                            Divider()
                        }
                    }
                }
            }
            .navigationTitle("茶楼")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {}) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }
    
    // 示例帖子数据
    private var samplePosts: [Post] {
        [
            Post(
                id: "1",
                author: "匿名用户",
                avatar: "person.circle.fill",
                category: "学习",
                title: "期末复习资料分享",
                content: "高数期末复习笔记整理，需要的同学私信我～",
                likes: 42,
                comments: 15,
                time: "2小时前"
            ),
            Post(
                id: "2",
                author: "小明",
                avatar: "person.circle.fill",
                category: "生活",
                title: "食堂推荐",
                content: "强烈推荐三食堂的麻辣香锅，真的很好吃！",
                likes: 88,
                comments: 23,
                time: "3小时前"
            ),
            Post(
                id: "3",
                author: "匿名",
                avatar: "person.circle.fill",
                category: "二手",
                title: "出二手教材",
                content: "大一教材低价出，九成新，有意者联系",
                likes: 12,
                comments: 5,
                time: "5小时前"
            ),
            Post(
                id: "4",
                author: "失物招领处",
                avatar: "magnifyingglass.circle.fill",
                category: "失物招领",
                title: "拾到校园卡一张",
                content: "在图书馆二楼拾到一张校园卡，姓名王XX，请到图书馆服务台认领",
                likes: 5,
                comments: 2,
                time: "1天前"
            ),
        ]
    }
}

/// 帖子模型
struct Post: Identifiable {
    let id: String
    let author: String
    let avatar: String
    let category: String
    let title: String
    let content: String
    let likes: Int
    let comments: Int
    let time: String
}

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
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 用户信息
            HStack {
                Image(systemName: post.avatar)
                    .font(.title2)
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.author)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(post.time)
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
            
            // 互动按钮
            HStack(spacing: 24) {
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart")
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
}

#Preview {
    TeahouseView()
        .environment(AppSettings())
}
