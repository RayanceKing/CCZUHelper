//
//  TeahouseDeleteAccountView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/24.
//

import SwiftUI
import SafariServices
internal import Auth
import Supabase

/// 茶楼注销账户视图
struct TeahouseDeleteAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @StateObject private var authViewModel = AuthViewModel()
    
    @State private var email = ""
    @State private var password = ""
    @State private var showError = false
    @State private var isDeleting = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.red)
                            .padding(.bottom, 8)
                        
                        Text("注销账户")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("此操作不可逆转，将永久删除您的账户和所有相关数据")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
                .listRowBackground(Color.clear)
                
                Section {
                    TextField("邮箱", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disabled(isDeleting)
                    
                    SecureField("密码", text: $password)
                        .textContentType(.password)
                        .disabled(isDeleting)
                        .onSubmit {
                            handleDeleteAccount()
                        }
                }
                
                Section {
                    VStack(spacing: 10) {
                        Button(action: handleDeleteAccount) {
                            HStack {
                                if isDeleting {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                } else {
                                    Text("确认注销账户")
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .disabled(!canProceed || isDeleting)
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.large)
                        .buttonBorderShape(.automatic)
                    }
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("注销账户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .alert("注销失败", isPresented: $showError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(authViewModel.errorMessage ?? "未知错误")
            }
            .onChange(of: authViewModel.session) { _, newSession in
                if newSession == nil {
                    // 账户删除成功，关闭视图
                    dismiss()
                }
            }
        }
    }
    
    private var canProceed: Bool {
        !email.isEmpty && !password.isEmpty && email.contains("@")
    }
    
    private func handleDeleteAccount() {
        guard canProceed else { return }
        
        Task {
            isDeleting = true
            await authViewModel.deleteAccount(email: email, password: password)
            isDeleting = false
            
            if authViewModel.errorMessage != nil {
                showError = true
            }
        }
    }
}