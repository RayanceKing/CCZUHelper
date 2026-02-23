//
//  TeahouseProfileContentList.swift
//  CCZUHelper
//
//  Created by rayanceking on 2026/2/23.
//

import SwiftUI

/// iOS 版内容列表组件
struct TeahouseProfileContentList: View {
    @Environment(AppSettings.self) private var settings
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    let userId: String?
    let serverProfile: Profile?
    let hideBannerBinding: Binding<Bool>
    let isPurchasingHideBanner: Bool
    let isRestoringPurchases: Bool
    let onRestorePurchase: () -> Void
    @Binding var showLogoutConfirmation: Bool
    @Binding var showDeleteAccountWarning: Bool

    var body: some View {
        NavigationStack {
            List {
                // 我的内容部分
                Section {
                    if let userId = userId {
                        NavigationLink {
                            UserPostsListView(type: .myPosts, userId: userId)
                                .environmentObject(authViewModel)
                        } label: {
                            Label("post.my_posts".localized, systemImage: "square.and.pencil")
                        }
                        
                        NavigationLink {
                            UserPostsListView(type: .likedPosts, userId: userId)
                                .environmentObject(authViewModel)
                        } label: {
                            Label("post.my_likes".localized, systemImage: "heart")
                        }
                        
                        NavigationLink {
                            UserPostsListView(type: .commentedPosts, userId: userId)
                                .environmentObject(authViewModel)
                        } label: {
                            Label("post.my_comments".localized, systemImage: "bubble.right")
                        }
                        
                        // 管理员功能：待处理举报
                        if settings.isPrivilege {
                            NavigationLink {
                                ReportedPostsView()
                                    .environmentObject(authViewModel)
                            } label: {
                                Label("report.pending".localized, systemImage: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                } header: {
                    Text("post.my_content".localized)
                }
                
                // 特权功能
                Section {
                    TeahouseBannerPurchaseControls(
                        hideBannerBinding: hideBannerBinding,
                        isPurchasing: isPurchasingHideBanner,
                        isRestoring: isRestoringPurchases,
                        onRestore: onRestorePurchase
                    )
                } header: {
                    Text("privileges.title".localized)
                }
                
                // 退出登录按钮
                Section {
                    Button(role: .destructive, action: {
                        showLogoutConfirmation = true
                    }) {
                        HStack {
                            Spacer()
                            Text("logout.confirm_title".localized)
                            Spacer()
                        }
                    }
                }
                
                // 注销账户按钮
                Section {
                    Button(role: .destructive, action: {
                        showDeleteAccountWarning = true
                    }) {
                        HStack {
                            Spacer()
                            Text("account.delete_account".localized)
                            Spacer()
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    TeahouseProfileContentList(
        userId: "test-user-id",
        serverProfile: nil,
        hideBannerBinding: .constant(false),
        isPurchasingHideBanner: false,
        isRestoringPurchases: false,
        onRestorePurchase: {},
        showLogoutConfirmation: .constant(false),
        showDeleteAccountWarning: .constant(false)
    )
    .environment(AppSettings())
    .environmentObject(AuthViewModel())
}
