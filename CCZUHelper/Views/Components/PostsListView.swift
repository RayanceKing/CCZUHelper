//
//  PostsListView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/17.
//

import SwiftUI

struct PostsListView: View {
    let filteredPosts: [TeahousePost]
    let isLoading: Bool
    let loadError: String?
    let validBanners: [ActiveBanner]
    let isRefreshing: Bool
    let onRetry: () -> Void
    let onLike: (TeahousePost) -> Void
    @ObservedObject var authViewModel: AuthViewModel

    var body: some View {
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
                            .environmentObject(authViewModel)
                    } label: {
                        PostRow(post: post, onLike: { onLike(post) }, authViewModel: authViewModel)
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
                            Button(action: onRetry) {
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
            .padding(.top, (validBanners.isEmpty ? 0 : 130))
        }
    }
}

