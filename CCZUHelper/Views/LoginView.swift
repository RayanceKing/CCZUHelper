//
//  LoginView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/11/30.
//

import SwiftUI
import CCZUKit

#if canImport(UIKit)
import UIKit
#endif

/// 登录视图
struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Logo
                VStack(spacing: 12) {
                    Image(systemName: "graduationcap.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.blue)
                    
                    Text("app.name".localized)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("app.subtitle".localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
                
                // 输入表单
                VStack(spacing: 16) {
                    TextField("login.username.placeholder".localized, text: $username)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.username)
                        .keyboardType(.default)
                        .disabled(isLoading)
                        .accessibilityLabel("login.username.accessibility".localized)
                    
                    SecureField("login.password.placeholder".localized, text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)
                        .disabled(isLoading)
                        .accessibilityLabel("login.password.accessibility".localized)
                }
                .padding(.horizontal, 24)
                
                // 登录按钮
                Button(action: login) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        } else {
                            Text("login.button".localized)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canLogin ? Color.blue : Color.gray)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!canLogin || isLoading)
                .padding(.horizontal, 24)
                
                // 提示信息
                Text("login.hint".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("login.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
            }
            .alert("login.failed".localized, isPresented: $showError) {
                Button("ok".localized, role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var canLogin: Bool {
        !username.isEmpty && !password.isEmpty
    }
    
    private func login() {
        guard canLogin else { return }
        
        isLoading = true
        
        Task {
            do {
                // 使用 CCZUKit 进行登录（移除SSO方式）
                let client = DefaultHTTPClient(username: username, password: password)
                
                // 获取用户真实姓名
                let app = JwqywxApplication(client: client)
                _ = try await app.login()
                let userInfoResponse = try await app.getStudentBasicInfo()
                let realName = userInfoResponse.message.first?.name
                
                await MainActor.run {
                    // 同步账号到iCloud Keychain（启用跨设备同步）
                    let syncSuccess = AccountSyncManager.syncAccountToiCloud(
                        username: username,
                        password: password
                    )
                    
                    if syncSuccess {
                        print("✅ Account synced to iCloud successfully")
                    } else {
                        print("⚠️ Failed to sync to iCloud, using local storage only")
                    }
                    
                    settings.isLoggedIn = true
                    settings.username = username
                    // 使用真实姓名作为显示名称，如果获取失败则使用学号
                    settings.userDisplayName = realName ?? username
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    
                    // 触发震动反馈
                    triggerErrorHaptic()
                    
                    // 根据错误信息提供友好的错误提示
                    let errorDesc = error.localizedDescription.lowercased()
                    if errorDesc.contains("authentication") || errorDesc.contains("认证") || 
                       errorDesc.contains("401") || errorDesc.contains("用户名") || 
                       errorDesc.contains("密码") || errorDesc.contains("incorrect") {
                        errorMessage = "账号或密码错误，请检查后重试"
                    } else if errorDesc.contains("network") || errorDesc.contains("网络") || 
                              errorDesc.contains("connection") || errorDesc.contains("连接") {
                        errorMessage = "网络连接失败，请检查网络后重试"
                    } else if errorDesc.contains("timeout") || errorDesc.contains("超时") {
                        errorMessage = "请求超时，请稍后重试"
                    } else if errorDesc.contains("server") || errorDesc.contains("服务器") {
                        errorMessage = "服务器异常，请稍后重试"
                    } else {
                        errorMessage = "登录失败：\(error.localizedDescription)"
                    }
                    
                    showError = true
                }
            }
        }
    }
    
    /// 触发错误震动反馈
    private func triggerErrorHaptic() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        #endif
    }
}

#Preview {
    LoginView()
        .environment(AppSettings())
}
