//
//  MacTeachingUserInfoSheet.swift
//  CCZUHelper
//
//  Created by Codex on 2026/02/25.
//

import SwiftUI

#if os(macOS)
struct MacTeachingUserInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings

    @State private var showLogoutConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            NavigationStack {
                UserInfoView()
                    .environment(settings)
            }

            Divider()

            HStack {
                Spacer()
                Button("settings.logout".localized, role: .destructive) {
                    showLogoutConfirmation = true
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 700, minHeight: 760)
        .alert("settings.logout_confirm_title".localized, isPresented: $showLogoutConfirmation) {
            Button("common.cancel".localized, role: .cancel) { }
            Button("settings.logout".localized, role: .destructive) {
                settings.logout()
                dismiss()
            }
        } message: {
            Text("settings.logout_confirm_message".localized)
        }
    }
}
#endif

