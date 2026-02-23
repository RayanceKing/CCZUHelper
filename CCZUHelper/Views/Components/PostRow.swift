//
//  PostRow.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/17.
//
import SwiftUI
import SwiftData
import Kingfisher
import MarkdownUI
internal import Auth

@ViewBuilder
func authorAvatarView(post: TeahousePost) -> some View {
    if let urlString = post.authorAvatarUrl {
        if let url = URL(string: urlString) {
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
    } else {
        Image(systemName: "person.circle.fill")
            .font(.title2)
            .foregroundStyle(.blue)
    }
}

struct PostRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @Environment(\.modelContext) private var modelContext
    let post: TeahousePost
    let onLike: () -> Void
    @ObservedObject var authViewModel: AuthViewModel

    @Environment(AppSettings.self) private var settings
    
    // Price badge component is defined in Components/PriceTagView.swift

    @Query var userLikes: [UserLike]

    init(post: TeahousePost, onLike: @escaping () -> Void, authViewModel: AuthViewModel) {
        self.post = post
        self.onLike = onLike
        self.authViewModel = authViewModel
        let postId = post.id
        let userId = authViewModel.session?.user.id.uuidString ?? "guest"
        self._userLikes = Query(filter: #Predicate { like in
            like.postId == postId && like.userId == userId
        })
    }

    private var isLiked: Bool {
        guard !userLikes.isEmpty else { return false }
        for like in userLikes {
            if like.postId == post.id {
                return true
            }
        }
        return false
    }

    private var isAuthorPrivileged: Bool {
        return post.isAuthorPrivileged == true
    }
    
    private var privilegedAuthorGradient: LinearGradient {
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
    }
    
    @ViewBuilder
    private var authorNameView: some View {
        if isAuthorPrivileged {
            Text(post.author)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(privilegedAuthorGradient)
        } else {
            Text(post.author)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
    
    private var cardBackgroundColor: Color {
        #if os(macOS)
        return colorScheme == .dark ? Color(nsColor: .controlBackgroundColor) : Color(nsColor: .windowBackgroundColor)
        #else
        return colorScheme == .dark ? Color(uiColor: .systemGray6) : .white
        #endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                authorAvatarView(post: post)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        authorNameView

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

            VStack(alignment: .leading, spacing: 6) {
                Text(post.title)
                    .font(.headline)

                Group {
                    if post.content.count > 80 {
                        HStack(alignment: .bottom, spacing: 4) {
                            Markdown(String(post.content.prefix(80)) + "...")
                                .markdownTheme(.gitHub)
                                .background(Color.clear)
                                .lineLimit(3)
                                .font(.body)
                                .foregroundStyle(.secondary)
                            Text("common.more".localized)
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    } else {
                        Markdown(post.content)
                            .markdownTheme(.gitHub)
                            .background(Color.clear)
                            .lineLimit(3)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if showPriceBadge {
                HStack {
                    PriceTagView(price: post.price ?? 0)
                    Spacer()
                }
            }

            if !post.images.isEmpty {
                let thumbnailSize = CGSize(width: 100, height: 100)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(post.images.prefix(3), id: \.self) { imagePath in
                            if let url = URL(string: imagePath), url.scheme?.hasPrefix("http") == true {
                                KFImage(url)
                                    .downsampling(size: thumbnailSize)
                                    .scaleFactor(displayScale)
                                    .cancelOnDisappear(true)
                                    .placeholder { ProgressView().frame(width: 100, height: 100) }
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                KFImage(URL(fileURLWithPath: imagePath))
                                    .downsampling(size: thumbnailSize)
                                    .scaleFactor(displayScale)
                                    .cancelOnDisappear(true)
                                    .placeholder { ProgressView().frame(width: 100, height: 100) }
                                    .resizable()
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
                    .foregroundStyle(isLiked ? .red : .secondary)
                }
                #if os(macOS)
                .buttonStyle(.plain)
                #endif

                HStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                    Text("\(post.comments)")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Spacer()

                Button(action: {}) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                #if os(macOS)
                .buttonStyle(.plain)
                #endif
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackgroundColor)
                .shadow(
                    color: colorScheme == .dark ? Color.black.opacity(0.22) : Color.black.opacity(0.12),
                    radius: colorScheme == .dark ? 10 : 8,
                    x: 0,
                    y: colorScheme == .dark ? 5 : 4
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }

    private var placeholderImage: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.2))
            .frame(width: 100, height: 100)
    }

    private var showPriceBadge: Bool {
        (post.category ?? "") == NSLocalizedString("teahouse.category.secondhand", comment: "") && post.price != nil
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
