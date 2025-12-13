//
//  TeahouseLoginView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/14.
//

import SwiftUI

/// 茶楼登录视图
struct TeahouseLoginView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authViewModel = AuthViewModel()
    
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var showError = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)
                            .padding(.bottom, 8)
                        
                        Text("teahouse.login.title")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("teahouse.login.subtitle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
                .listRowBackground(Color.clear)
                
                Section {
                    TextField("teahouse.login.email.placeholder", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disabled(authViewModel.isLoading)
                    
                    SecureField("teahouse.login.password.placeholder", text: $password)
                        .textContentType(.password)
                        .disabled(authViewModel.isLoading)
                        .onSubmit {
                            handleAuth()
                        }
                }
                
                Section {
                    VStack(spacing: 10) {
                        if #available(iOS 26.0, *) {
                            Button(action: handleAuth) {
                                HStack {
                                    if authViewModel.isLoading {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .tint(.white)
                                    } else {
                                        Text(isSignUp ? "teahouse.login.signup" : "teahouse.login.signin")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .disabled(!canLogin || authViewModel.isLoading)
                            .buttonStyle(.glassProminent)
                            .controlSize(.large)
                            .buttonBorderShape(.automatic)
                        } else {
                            Button(action: handleAuth) {
                                HStack {
                                    if authViewModel.isLoading {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .tint(.white)
                                    } else {
                                        Text(isSignUp ? "teahouse.login.signup" : "teahouse.login.signin")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .disabled(!canLogin || authViewModel.isLoading)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .buttonBorderShape(.automatic)
                        }
                        
                        Button(action: {
                            isSignUp.toggle()
                        }) {
                            Text(isSignUp ? "teahouse.login.has_account" : "teahouse.login.no_account")
                                .font(.subheadline)
                        }
                    }
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("teahouse.login.nav_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
            }
            .alert("teahouse.login.failed", isPresented: $showError) {
                Button("ok".localized, role: .cancel) { }
            } message: {
                Text(authViewModel.errorMessage ?? "Unknown error")
            }
            .onChange(of: authViewModel.session) { _, newSession in
                if newSession != nil {
                    dismiss()
                }
            }
        }
    }
    
    private var canLogin: Bool {
        !email.isEmpty && !password.isEmpty && email.contains("@")
    }
    
    private func handleAuth() {
        guard canLogin else { return }
        
        Task {
            if isSignUp {
                await authViewModel.signUp(email: email, password: password)
            } else {
                await authViewModel.signIn(email: email, password: password)
            }
            
            if authViewModel.errorMessage != nil {
                showError = true
            }
        }
    }
}

#Preview {
    TeahouseLoginView()
}
