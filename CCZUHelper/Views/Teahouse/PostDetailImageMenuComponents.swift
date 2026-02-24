//
//  PostDetailImageMenuComponents.swift
//  CCZUHelper
//
//  Created by Codex on 2026/2/23.
//

import SwiftUI
import Kingfisher

struct PostDetailImageContextMenu: View {
    let onShare: () -> Void
    let onSave: () -> Void
    let onCopy: () -> Void

    var body: some View {
        Button(action: onShare) {
            Label("teahouse.image.menu.share".localized, systemImage: "square.and.arrow.up")
        }

        Button(action: onSave) {
            Label("teahouse.image.menu.save_to_photos".localized, systemImage: "square.and.arrow.down")
        }

        Button(action: onCopy) {
            Label("teahouse.image.menu.copy".localized, systemImage: "doc.on.doc")
        }

        Button {
            // not supported yet
        } label: {
            Label("teahouse.image.menu.copy_subject".localized, systemImage: "circle.dashed.rectangle")
        }
        .disabled(true)

        Button {
            // not supported yet
        } label: {
            Label("teahouse.image.menu.lookup".localized, systemImage: "magnifyingglass")
        }
        .disabled(true)
    }
}

struct PostDetailImageMenuPreview: View {
    let url: URL

    var body: some View {
        KFImage(url)
            .placeholder {
                ZStack {
                    Color.secondary.opacity(0.08)
                    ProgressView()
                }
            }
            .retry(maxCount: 2, interval: .seconds(2))
            .resizable()
            .scaledToFill()
            .frame(width: 260, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

