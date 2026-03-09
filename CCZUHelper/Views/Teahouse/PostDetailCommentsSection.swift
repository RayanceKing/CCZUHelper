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
            CommentThreadView(
                comment: commentWithProfile,
                repliesByParentID: commentChildren,
                depth: 0,
                postId: postId,
                currentUserId: currentUserId,
                onCommentChanged: onCommentChanged,
                onConfirmDelete: onConfirmDelete,
                armedDeleteCommentIDs: $armedDeleteCommentIDs
            )
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
}

private struct CommentThreadView: View {
    let comment: CommentWithProfile
    let repliesByParentID: [String: [CommentWithProfile]]
    let depth: Int
    let postId: String
    let currentUserId: String?
    let onCommentChanged: () -> Void
    let onConfirmDelete: (CommentWithProfile) -> Void
    @Binding var armedDeleteCommentIDs: Set<String>

    private var replies: [CommentWithProfile] {
        repliesByParentID[comment.id] ?? []
    }

    private var isDeleteArmed: Bool {
        armedDeleteCommentIDs.contains(comment.id)
    }

    var body: some View {
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
                    Button(action: handleDeleteTap) {
                        Image(systemName: "trash")
                            .font(.subheadline)
                            .foregroundStyle(isDeleteArmed ? .red : .secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(
                                    isDeleteArmed
                                    ? Color.red.opacity(0.12)
                                    : Color.secondary.opacity(0.08)
                                )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        Text(
                            isDeleteArmed
                            ? "teahouse.comment.delete_again".localized
                            : "common.delete".localized
                        )
                    )
                }
            }
            .padding(.trailing, depth == 0 ? 0 : 24)

            ForEach(replies) { reply in
                CommentThreadView(
                    comment: reply,
                    repliesByParentID: repliesByParentID,
                    depth: depth + 1,
                    postId: postId,
                    currentUserId: currentUserId,
                    onCommentChanged: onCommentChanged,
                    onConfirmDelete: onConfirmDelete,
                    armedDeleteCommentIDs: $armedDeleteCommentIDs
                )
            }
        }
        .contentShape(Rectangle())
    }

    private func handleDeleteTap() {
        if isDeleteArmed {
            onConfirmDelete(comment)
        } else {
            armedDeleteCommentIDs.insert(comment.id)
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                armedDeleteCommentIDs.remove(comment.id)
            }
        }
    }
}
