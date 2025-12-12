//
//  TeahouseView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/11/30.
//

import SwiftUI
import SwiftData
import TeahouseKit

#if canImport(UIKit)
import UIKit
#endif

/// 茶楼视图 - 社交/论坛功能
struct TeahouseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings

    @Query(sort: \TeahousePost.createdAt, order: .reverse) private var allPosts: [TeahousePost]

    @State private var selectedCategory = 0
    @State private var showCreatePost = false
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var loadError: String?
    @State private var banners: [TeahouseBanner] = []

    private let teahouseClient = TeahouseClient()

    private var categories: [CategoryItem] {
        [
            CategoryItem(id: 0, title: NSLocalizedString("teahouse.category.all", comment: ""), backendValue: nil),
            CategoryItem(id: 1, title: NSLocalizedString("teahouse.category.study", comment: ""), backendValue: "学习"),
            CategoryItem(id: 2, title: NSLocalizedString("teahouse.category.life", comment: ""), backendValue: "生活"),
            CategoryItem(id: 3, title: NSLocalizedString("teahouse.category.secondhand", comment: ""), backendValue: "二手"),
            CategoryItem(id: 4, title: NSLocalizedString("teahouse.category.confession", comment: ""), backendValue: "表白墙"),
            CategoryItem(id: 5, title: NSLocalizedString("teahouse.category.lost_found", comment: ""), backendValue: "失物招领")
        ]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部自定义标题，紧贴安全区
                HStack {
                    Text(NSLocalizedString("teahouse.title", comment: ""))
                        .font(.largeTitle)
                        .bold()
                        .padding(.horizontal)
                    Spacer()
                }
                .padding(.top, -50)
                .padding(.bottom, 6)

                ZStack(alignment: .top) {
                    // Posts list
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if isLoading && filteredPosts.isEmpty {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 24)
                            }

                            ForEach(filteredPosts) { post in
                                NavigationLink {
                                    PostDetailView(post: post)
                                } label: {
                                    PostRow(post: post, onLike: {
                                        toggleLike(post)
                                    })
                                    .padding(.horizontal, 16)
                                }
                                .buttonStyle(.plain)
                                .padding(.vertical, 8)
                            }

                            if let loadError {
                                ContentUnavailableView {
                                    Label(NSLocalizedString("teahouse.load_failed", comment: ""), systemImage: "exclamationmark.triangle")
                                } description: {
                                    VStack(spacing: 8) {
                                        Text(loadError)
                                        Button(action: {
                                            Task { await loadTeahouseContent(force: true) }
                                        }) {
                                            Text(NSLocalizedString("teahouse.retry", comment: ""))
                                        }
                                    }
                                }
                                .padding(.vertical, 24)
                            } else if filteredPosts.isEmpty && !isLoading {
                                ContentUnavailableView {
                                    Label(NSLocalizedString("teahouse.no_posts", comment: ""), systemImage: "bubble.left.and.bubble.right")
                                } description: {
                                    Text(NSLocalizedString("teahouse.no_posts_hint", comment: ""))
                                }
                                .frame(height: 320)
                            }
                        }
                        .padding(.top, (banners.isEmpty ? 0 : 156) + 56)
                    }

                    // Floating category overlay (transparent)
                    CategoryBarOverlay(categories: categories, selectedCategory: $selectedCategory)
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                        .ignoresSafeArea(edges: .horizontal)

                    // Floating banner overlay (below category)
                    if !banners.isEmpty {
                        BannerCarousel(banners: banners)
                            .padding(.horizontal)
                            .padding(.top, 64)
                            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                    }

                    if isRefreshing {
                        ProgressView()
                            .tint(.primary)
                            .padding(.top, banners.isEmpty ? 88 : 156)
                    }
                }
            }
            //.navigationTitle(NSLocalizedString("teahouse.title", comment: ""))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showCreatePost = true }) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            #if os(macOS)
            .background(Color(nsColor: .windowBackgroundColor))
            #else
            .background(Color(.systemGroupedBackground))
            #endif
            .sheet(isPresented: $showCreatePost) {
                CreatePostView()
                    .environment(settings)
            }
            .task { await loadTeahouseContent() }
            .refreshable { await loadTeahouseContent(force: true, showRefreshIndicator: true) }
        }
    }

    private var filteredPosts: [TeahousePost] {
        guard selectedCategory < categories.count else { return allPosts }
        if let backendValue = categories[selectedCategory].backendValue {
            return allPosts.filter { $0.category == backendValue }
        }
        return allPosts
    }

    @MainActor
    private func loadTeahouseContent(force: Bool = false, showRefreshIndicator: Bool = false) async {
        if isLoading && !force { return }
        isLoading = true
        if showRefreshIndicator { isRefreshing = true }
        loadError = nil

        do {
            async let postsPage = teahouseClient.fetchPosts(page: 1)
            async let bannerList = teahouseClient.fetchBanners()
            let (page, bannerResult) = try await (postsPage, bannerList)

            try syncRemotePosts(page.posts)
            banners = bannerResult
        } catch {
            loadError = error.localizedDescription
        }

        isLoading = false
        isRefreshing = false
    }

    @MainActor
    private func syncRemotePosts(_ remotePosts: [TeahouseFeedPost]) throws {
        let remoteInStore = allPosts.filter { !$0.isLocal }
        remoteInStore.forEach { modelContext.delete($0) }

        for remote in remotePosts {
            let model = TeahousePost(
                id: remote.id,
                author: remote.isAnonymous ? NSLocalizedString("teahouse.anonymous", comment: "") : remote.user,
                authorId: nil,
                category: remote.category,
                title: remote.title,
                content: remote.content ?? remote.price ?? "",
                images: remote.images.map(\.absoluteString),
                likes: remote.likes,
                comments: remote.comments,
                createdAt: remote.createdAt ?? Date(),
                isLocal: false,
                syncStatus: .synced
            )
            modelContext.insert(model)
        }

        try modelContext.save()
    }

    private func toggleLike(_ post: TeahousePost) {
        let userId = settings.username ?? "guest"

        let postId = post.id
        let descriptor = FetchDescriptor<UserLike>(
            predicate: #Predicate { like in
                like.userId == userId && like.postId == postId
            }
        )

        if let likes = try? modelContext.fetch(descriptor), !likes.isEmpty {
            for like in likes {
                modelContext.delete(like)
            }
            post.likes = max(0, post.likes - 1)
        } else {
            let like = UserLike(userId: userId, postId: post.id)
            modelContext.insert(like)
            post.likes += 1
        }
    }
}

struct CategoryItem: Identifiable {
    let id: Int
    let title: String
    let backendValue: String?
}

/// 浮动分类按钮（支持液态玻璃，向下兼容）
private struct FloatingTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    // 可选：交互与风格开关
    private var isInteractive: Bool { true }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(
                    {
                        if #available(iOS 26.0, macOS 15.0, *) {
                            return isSelected ? AnyShapeStyle(.black.opacity(0.9)) : AnyShapeStyle(.primary)
                        } else {
                            // 旧系统：保持原有样式
                            return isSelected ? AnyShapeStyle(.black) : AnyShapeStyle(.primary.opacity(0.7))
                        }
                    }()
                )
                .padding(.horizontal, isSelected ? 18 : 16)
                .padding(.vertical, isSelected ? 11 : 10)
                .background(
                    Group {
                        if #available(iOS 26.0, macOS 15.0, *) {
                            RoundedRectangle(cornerRadius: 100)
                                .fill(isSelected ? Color.white.opacity(0.8) : Color.clear)
                                .glassEffect(.clear.interactive(isInteractive), in: .rect(cornerRadius: 100))
//                                .shadow(
//                                    color: .black.opacity(isSelected ? 0.25 : 0.08),
//                                    radius: isSelected ? 4 : 2,
//                                    x: 0, y: isSelected ? 2 : 1
//                                )
                        }
                            else {
                            #if os(macOS)
                            RoundedRectangle(cornerRadius: 100)
                                .fill(isSelected ? Color.blue : Color(nsColor: .controlBackgroundColor))
                            #else
                            RoundedRectangle(cornerRadius: 100)
                                .fill(isSelected ? Color.blue : Color(.systemGray5))
                            #endif
                        }
                    }
                )
                .overlay(
                    Capsule()
                    //RoundedRectangle(cornerRadius: 100)
                        .strokeBorder(
                            Color.white.opacity(isSelected ? 0.3 : 0.1),
                            lineWidth: 0.5
                        )
                )
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.95))
    }
}

private struct PressScaleButtonStyle: ButtonStyle {
    let scale: CGFloat
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

/// 分类标签
struct CategoryTag: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        FloatingTabButton(title: title, isSelected: isSelected, action: action)
    }
}

struct BannerCarousel: View {
    let banners: [TeahouseBanner]

    var body: some View {
        TabView {
            ForEach(banners) { banner in
                BannerCard(banner: banner)
            }
        }
        .frame(height: 140)
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
}

struct BannerCard: View {
    let banner: TeahouseBanner

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if #available(iOS 26.0, macOS 15.0, *) {
                    Text(banner.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(banner.content)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text(banner.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(banner.content)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }

            if let start = banner.startDate, let end = banner.endDate {
                Text("\(dateLabel(for: start)) - \(dateLabel(for: end))")
                    .font(.caption)
                    .foregroundStyle(
                        {
                            if #available(iOS 26.0, macOS 15.0, *) {
                                return AnyShapeStyle(.secondary)
                            } else {
                                return AnyShapeStyle(.white.opacity(0.8))
                            }
                        }()
                    )
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Group {
                if #available(iOS 26.0, macOS 15.0, *) {
                    // 无颜色液态玻璃
                    RoundedRectangle(cornerRadius: 60)
                        .fill(Color.clear)
                        .glassEffect(.clear.interactive(true), in: .rect(cornerRadius: 14))
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                } else {
                    // 旧系统回退到原有有色背景
                    color(from: banner.colorHex)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        )
    }

    private func color(from hex: String) -> Color {
        var hexString = hex.replacingOccurrences(of: "#", with: "")
        if hexString.count == 6 {
            hexString.append("FF")
        }
        guard let value = UInt64(hexString, radix: 16) else { return .blue }
        let r = Double((value & 0xFF000000) >> 24) / 255
        let g = Double((value & 0x00FF0000) >> 16) / 255
        let b = Double((value & 0x0000FF00) >> 8) / 255
        let a = Double(value & 0x000000FF) / 255
        return Color(red: r, green: g, blue: b, opacity: a)
    }

    private func dateLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        return formatter.string(from: date)
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
                            Text(NSLocalizedString("teahouse.local", comment: ""))
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

            VStack(alignment: .leading, spacing: 6) {
                Text(post.title)
                    .font(.headline)

                Text(post.content)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            if !post.images.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(post.images.prefix(3), id: \.self) { imagePath in
                            if let url = URL(string: imagePath), url.scheme?.hasPrefix("http") == true {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                            .frame(width: 100, height: 100)
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    case .failure:
                                        placeholderImage
                                    @unknown default:
                                        placeholderImage
                                    }
                                }
                            } else if let image = PlatformImage(contentsOfFile: imagePath) {
                                PlatformImageView(platformImage: image)
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }

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
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    {
                        #if os(macOS)
                        Color(nsColor: .underPageBackgroundColor)
                        #else
                        Color(.secondarySystemBackground)
                        #endif
                    }()
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 6)
    }

    private var placeholderImage: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.2))
            .frame(width: 100, height: 100)
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
}

struct PostDetailView: View {
    let post: TeahousePost

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(post.title)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(post.content)
                    .font(.body)
                    .foregroundStyle(.primary)

                if !post.images.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(post.images, id: \.self) { imagePath in
                            if let url = URL(string: imagePath) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 180)
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 180)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    case .failure:
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.gray.opacity(0.15))
                                            .frame(height: 180)
                                    @unknown default:
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.gray.opacity(0.15))
                                            .frame(height: 180)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(post.category)
        #if os(macOS)
        .background(Color(nsColor: .windowBackgroundColor))
        #else
        .background(Color(.systemGroupedBackground))
        #endif
    }
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

#Preview {
    TeahouseView()
        .environment(AppSettings())
        .modelContainer(for: [TeahousePost.self, UserLike.self], inMemory: true)
}

