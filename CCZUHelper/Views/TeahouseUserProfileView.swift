//
//  TeahouseUserProfileView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/14.
//

import SwiftUI
internal import Auth

/// 茶楼用户档案视图 - 仅在已登录时显示
struct TeahouseUserProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    @State private var showLogoutConfirmation = false
    
    private var userEmail: String {
        authViewModel.session?.user.email ?? "未知"
    }
    
    var body: some View {
        NavigationStack {
            List {
                // 用户信息部分
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.blue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("茶楼用户")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                Text("已登录")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("账户信息")
                }
                
                // 邮箱信息
                Section {
                    HStack {
                        Label("邮箱", systemImage: "envelope")
                            .foregroundStyle(.blue)
                        Spacer()
                        Text(userEmail)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                } header: {
                    Text("账户详情")
                }
                
                // 退出登录按钮
                Section {
                    Button(role: .destructive, action: {
                        showLogoutConfirmation = true
                    }) {
                        HStack {
                            Spacer()
                            Text("退出登录")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("茶楼账户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .alert("退出登录", isPresented: $showLogoutConfirmation) {
                Button("取消", role: .cancel) { }
                Button("退出登录", role: .destructive) {
                    Task {
                        await authViewModel.signOut()
                        dismiss()
                    }
                }
            } message: {
                Text("确定要退出登录吗？")
            }
        }
    }
}

#Preview {
    TeahouseUserProfileView()
        .environmentObject(AuthViewModel())
}
