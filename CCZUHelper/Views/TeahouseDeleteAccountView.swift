//
//  TeahouseDeleteAccountView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/24.
//

import SwiftUI
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
    
    private var warningSection: some View {
        Section {
            VStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.red)
                    .padding(.bottom, 8)
                
                Text("account.delete_account".localized)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("account.delete_warning".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical)
        }
        .listRowBackground(Color.clear)
    }
    
    private var credentialsSection: some View {
        Section {
            TextField(NSLocalizedString("login.email", comment: "邮箱"), text: $email)
                .textContentType(.emailAddress)
                #if os(iOS) || os(tvOS) || os(visionOS)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                #endif
                .disabled(isDeleting)
            
            SecureField(NSLocalizedString("login.password", comment: "密码"), text: $password)
                .textContentType(.password)
                .disabled(isDeleting)
                .onSubmit {
                    handleDeleteAccount()
                }
        }
    }
    
    private var actionSection: some View {
        Section {
            VStack(spacing: 10) {
                Button(action: handleDeleteAccount) {
                    HStack {
                        if isDeleting {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        } else {
                            Text("account.confirm_delete".localized)
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
    
    var body: some View {
        NavigationStack {
            Form {
                warningSection
                credentialsSection
                actionSection
            }
            .navigationTitle("account.delete_account".localized)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                }
            }
            .alert("account.delete_failed".localized, isPresented: $showError) {
                Button("common.ok".localized, role: .cancel) { }
            } message: {
                Text(authViewModel.errorMessage ?? "error.unknown".localized)
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
