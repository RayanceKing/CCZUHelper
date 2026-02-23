//
//  PostDetailCommentsSection.swift
//  CCZUHelper
//
//  Created by Codex on 2026/2/23.
//

import SwiftUI

struct PostDetailCommentsSection: View {
    let comments: [CommentWithProfile]
    let postId: String
    let currentUserId: String?
    let onCommentChanged: () -> Void
    let onConfirmDelete: (CommentWithProfile) -> Void
    @Binding var armedDeleteCommentIDs: Set<String>

    var body: some View {
        ForEach(rootComments) { commentWithProfile in
            commentThread(for: commentWithProfile)
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
                    postId: postId,
                    onCommentChanged: onCommentChanged
                )
                .padding(.leading, depth == 0 ? 0 : 24)

                HStack {
                    Spacer()
                    if let currentUserId, comment.comment.userId == currentUserId {
                        Button(action: {
                            if armedDeleteCommentIDs.contains(comment.id) {
                                onConfirmDelete(comment)
                            } else {
                                armedDeleteCommentIDs.insert(comment.id)
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
                                    Capsule().fill(
                                        armedDeleteCommentIDs.contains(comment.id)
                                        ? Color.red.opacity(0.12)
                                        : Color.secondary.opacity(0.08)
                                    )
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
}

