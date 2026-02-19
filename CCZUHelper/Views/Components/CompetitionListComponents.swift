//
//  CompetitionListComponents.swift
//  CCZUHelper
//

import SwiftUI

struct CompetitionRow: View {
    let item: CompetitionListItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)

            HStack(spacing: 8) {
                CompetitionTag(text: item.college, color: .blue)
                CompetitionTag(text: item.category, color: .orange)
                if let level = item.level, !level.isEmpty {
                    CompetitionTag(text: level, color: .purple)
                }
            }

            HStack(spacing: 12) {
                Label(item.publishDate, systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let deadline = item.deadline, !deadline.isEmpty {
                    Label(deadline, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct CompetitionTag: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}
