//
//  iForgetView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/23.
//

import SwiftUI
import Supabase

struct iForgetView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authViewModel = AuthViewModel()
    
    @State private var email = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var step: ResetStep = .email
    @Binding var forceStep: ResetStep?
    @State private var showError = false
    @State private var resetEmailSent = false
    @State private var isResetFlow = false
    
    enum ResetStep {
        case email
        case waitingEmail
        case newPassword
    }
    
    var body: some View {
        NavigationStack {
            Form {
                let _ = {
                    if let forced = forceStep, step != forced {
                        step = forced
                    }
                }()
                if step == .email {
                    Section {
                        VStack {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.blue)
                                .padding(.bottom, 8)
                            Text("忘记密码？")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("输入账户使用的电子邮件地址以继续。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical)
                    }
                    .listRowBackground(Color.clear)
                    Section {
                        TextField("teahouse.login.email.placeholder".localized, text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disabled(authViewModel.isLoading)
                    }
                    Section { // Button section
                        Button(action: sendResetEmail) {
                            HStack {
                                if authViewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                } else {
                                    Text("继续")
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .disabled(email.isEmpty || authViewModel.isLoading)
                        .modifier(ConditionalButtonStyling()) // Apply custom conditional styling
                        .controlSize(.large)
                        .buttonBorderShape(.automatic)
                    }
                    .listRowBackground(Color.clear)
                    Section { // Disclaimer text section, now separated
                        Text("我们非常重视保护你的隐私。如果你在其他人的设备上重设密码，你的个人信息将不会保存在该设备上。")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            // Removed .padding(.top, 16) as Section provides separation
                    }
                    .listRowBackground(Color.clear)
                } else if step == .waitingEmail {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.blue)
                                .frame(maxWidth: .infinity, alignment: .center)
                            Text("重置邮件已发送")
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .center)
                            Text("请检查您的邮箱，点击邮件中的链接来重置密码。")
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    }
                    .listRowBackground(Color.clear)
                } else if step == .newPassword {
                    Section {
                        VStack(spacing: 8) {
                            Text("设置新密码")
                                .font(.title2).bold()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            SecureField("新密码", text: $newPassword)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            SecureField("确认新密码", text: $confirmPassword)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        }
                        Button(action: updatePassword) {
                            HStack {
                                if authViewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                } else {
                                    Text("更新密码")
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .disabled(!canUpdatePassword || authViewModel.isLoading)
                        .modifier(ConditionalButtonStyling()) // Apply custom conditional styling
                        .controlSize(.large)
                        .buttonBorderShape(.automatic)
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .alert("错误", isPresented: $showError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(authViewModel.errorMessage ?? "未知错误")
            }
            .onAppear {
                isResetFlow = true
            }
            .onChange(of: authViewModel.session) { _, newSession in
                if isResetFlow && authViewModel.session == nil && newSession != nil && step == .waitingEmail {
                    step = .newPassword
                }
            }
        }
    }
    
    private func sendResetEmail() {
        Task {
            await authViewModel.resetPassword(email: email)
            if authViewModel.errorMessage == nil {
                step = .waitingEmail
            } else {
                showError = true
            }
        }
    }
    
    private func updatePassword() {
        Task {
            do {
                try await supabase.auth.update(user: UserAttributes(password: newPassword))
                dismiss()
            } catch {
                authViewModel.errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private var canUpdatePassword: Bool {
        !newPassword.isEmpty && newPassword == confirmPassword && newPassword.count >= 6
    }
}

struct ConditionalButtonStyling: ViewModifier {
    func body(content: Content) -> some View {
        #if os(visionOS)
        content.buttonStyle(.borderedProminent)
        #elseif os(iOS)
            if #available(iOS 26.0, *) {
                content.buttonStyle(.glassProminent)
            } else {
                content.buttonStyle(.borderedProminent)
            }
        #else
        content.buttonStyle(.borderedProminent)
        #endif
    }
}


#if DEBUG
struct iForgetView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State var forceStep: iForgetView.ResetStep? = nil
        var body: some View {
            iForgetView(forceStep: $forceStep)
        }
    }
    static var previews: some View {
        PreviewWrapper()
    }
}
#endif
