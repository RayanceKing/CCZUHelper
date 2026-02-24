//
//  PostDetailSections.swift
//  CCZUHelper
//
//  Created by Codex on 2026/2/23.
//

import SwiftUI
import Kingfisher
import MarkdownUI

struct PostDetailHiddenView: View {
    let colorScheme: ColorScheme
    let backgroundColor: Color

    var body: some View {
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
                .fill(backgroundColor)
                .shadow(
                    color: colorScheme == .dark ? Color.black.opacity(0.2) : Color.black.opacity(0.1),
                    radius: colorScheme == .dark ? 10 : 8,
                    x: 0,
                    y: colorScheme == .dark ? 5 : 4
                )
        )
    }
}

struct PostDetailHeaderView: View {
    let post: TeahousePost
    let isAuthorPrivileged: Bool
    let timeText: String

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if let urlString = post.authorAvatarUrl, let url = URL(string: urlString) {
                    KFImage(url)
                        .placeholder { ProgressView() }
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.blue.opacity(0.3), lineWidth: 1))
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
                Text(timeText)
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
}

struct PostDetailTitleContentView: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            Markdown(content)
                .markdownTheme(.gitHub)
                .background(Color.clear)
        }
    }
}

struct PostDetailActionButtonsView: View {
    let isLiked: Bool
    let likes: Int
    let comments: Int
    let isAuthenticated: Bool
    let onLike: () -> Void
    let onReport: () -> Void
    let onRequireLogin: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            Button(action: {
                if isAuthenticated {
                    onLike()
                } else {
                    onRequireLogin()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .foregroundStyle(isLiked ? .red : .secondary)
                    Text("\(likes)")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            #if os(macOS)
            .buttonStyle(.plain)
            #endif

            HStack(spacing: 4) {
                Image(systemName: "bubble.right")
                Text("\(comments)")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Button(action: {
                if isAuthenticated {
                    onReport()
                } else {
                    onRequireLogin()
                }
            }) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
            }
            #if os(macOS)
            .buttonStyle(.plain)
            #endif

            Spacer()
        }
        .padding(.top, 8)
    }
}

