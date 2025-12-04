//
//  LoginView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/11/30.
//

import SwiftUI
import CCZUKit

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
                    
                    Text("CCZUHelper")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("常州大学助手")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
                
                // 输入表单
                VStack(spacing: 16) {
                    TextField("学号", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.username)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .disabled(isLoading)
                    
                    SecureField("密码", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)
                        .disabled(isLoading)
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
                            Text("登录")
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
                Text("使用您的常州大学统一身份认证账号登录")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("登录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .alert("登录失败", isPresented: $showError) {
                Button("确定", role: .cancel) { }
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
                // 使用 CCZUKit 进行登录
                let client = DefaultHTTPClient(username: username, password: password)
                _ = try await client.ssoUniversalLogin()
                
                await MainActor.run {
                    // 保存密码到 Keychain
                    KeychainHelper.save(
                        service: "com.cczu.helper",
                        account: username,
                        password: password
                    )
                    
                    settings.isLoggedIn = true
                    settings.username = username
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "登录失败: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}

#Preview {
    LoginView()
        .environment(AppSettings())
}
