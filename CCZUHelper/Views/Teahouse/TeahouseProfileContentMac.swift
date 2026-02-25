//
//  TeahouseProfileContentMac.swift
//  CCZUHelper
//
//  Created by rayanceking on 2026/2/23.
//

import SwiftUI

#if os(macOS)

/// macOS 版本的个人资料内容
struct TeahouseProfileContentMac: View {
    @Environment(AppSettings.self) private var settings
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    let userId: String?
    let serverProfile: Profile?
    let hideBannerBinding: Binding<Bool>
    let isPurchasingHideBanner: Bool
    let isRestoringPurchases: Bool
    let onShowPurchase: () -> Void
    let onRestorePurchase: () -> Void
    @Binding var showLogoutConfirmation: Bool
    @Binding var showDeleteAccountWarning: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let userId = userId {
                    macSettingsGroup(title: "post.my_content".localized) {
                        VStack(spacing: 0) {
                            NavigationLink {
                                UserPostsListView(type: .myPosts, userId: userId)
                                    .environmentObject(authViewModel)
                            } label: {
                                macRow(icon: "square.and.pencil", color: .blue, title: "post.my_posts".localized)
                            }
                            .buttonStyle(.plain)

                            macRowDivider

                            NavigationLink {
                                UserPostsListView(type: .likedPosts, userId: userId)
                                    .environmentObject(authViewModel)
                            } label: {
                                macRow(icon: "heart", color: .pink, title: "post.my_likes".localized)
                            }
                            .buttonStyle(.plain)

                            macRowDivider

                            NavigationLink {
                                UserPostsListView(type: .commentedPosts, userId: userId)
                                    .environmentObject(authViewModel)
                            } label: {
                                macRow(icon: "bubble.right", color: .indigo, title: "post.my_comments".localized)
                            }
                            .buttonStyle(.plain)

                            if settings.isPrivilege {
                                macRowDivider

                                NavigationLink {
                                    ReportedPostsView()
                                        .environmentObject(authViewModel)
                                } label: {
                                    macRow(icon: "exclamationmark.triangle", color: .orange, title: "report.pending".localized)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                macSettingsGroup(title: "privileges.title".localized) {
                    TeahouseBannerPurchaseControls(
                        hideBannerBinding: hideBannerBinding,
                        isPurchasing: isPurchasingHideBanner,
                        isRestoring: isRestoringPurchases,
                        onPurchase: onShowPurchase,
                        onRestore: onRestorePurchase
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }

                macSettingsGroup {
                    Button(role: .destructive, action: {
                        showLogoutConfirmation = true
                    }) {
                        macRow(icon: "rectangle.portrait.and.arrow.right", color: .red, title: "logout.confirm_title".localized, showChevron: false)
                    }
                    .buttonStyle(.plain)

                    macRowDivider

                    Button(role: .destructive, action: {
                        showDeleteAccountWarning = true
                    }) {
                        macRow(icon: "person.crop.circle.badge.xmark", color: .red, title: "account.delete_account".localized, showChevron: false)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func macSettingsGroup<Content: View>(title: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.headline)
                    .padding(.horizontal, 2)
            }

            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .quinaryLabel))
            )
        }
    }

    private func macRow(icon: String, color: Color, title: String, subtitle: String? = nil, showChevron: Bool = true) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(color.opacity(0.14))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var macRowDivider: some View {
        Divider().padding(.leading, 52)
    }
}

#endif

#if os(macOS)
#Preview {
    TeahouseProfileContentMac(
        userId: "test-user-id",
        serverProfile: nil,
        hideBannerBinding: .constant(false),
        isPurchasingHideBanner: false,
        isRestoringPurchases: false,
        onShowPurchase: {},
        onRestorePurchase: {},
        showLogoutConfirmation: .constant(false),
        showDeleteAccountWarning: .constant(false)
    )
    .environment(AppSettings())
    .environmentObject(AuthViewModel())
}
#endif
