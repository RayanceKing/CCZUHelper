//
//  TeahouseBannerPurchaseControls.swift
//  CCZUHelper
//
//  Created by Codex on 2026/2/21.
//

import SwiftUI

struct TeahouseBannerPurchaseControls: View {
    let hideBannerBinding: Binding<Bool>
    let isPurchasing: Bool
    let isRestoring: Bool
    let onRestore: () -> Void

    var body: some View {
        Toggle(isOn: hideBannerBinding) {
            VStack(alignment: .leading, spacing: 4) {
                Text("teahouse.hide_banners".localized)
                Text("teahouse.hide_banners.description".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .disabled(isPurchasing || isRestoring)

        Button(action: onRestore) {
            HStack {
                Text("teahouse.hide_banners.restore_purchase".localized)
                if isRestoring {
                    Spacer()
                    ProgressView()
                }
            }
        }
        .disabled(isRestoring || isPurchasing)
    }
}
