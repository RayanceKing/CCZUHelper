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
    @State private var resetToken: String? = nil
    @State private var isDismissing = false
    
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
                            Text("forget.title".localized)
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("forget.subtitle".localized)
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
                                    Text("forget.continue".localized)
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
                        Text("forget.privacy_notice".localized)
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
                            Text("forget.email_sent".localized)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .center)
                            Text("forget.email_sent_message".localized)
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
                    Text("forget.set_password".localized)
                        .font(.title2).bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical)
                        .listRowBackground(Color.clear)
                    Section {
                        SecureField("forget.new_password.placeholder".localized, text: $newPassword)
                            .textContentType(.newPassword)
                            .disableAutocorrection(true)
                            .textInputAutocapitalization(.never)
                            .disabled(authViewModel.isLoading)
                        SecureField("forget.confirm_password.placeholder".localized, text: $confirmPassword)
                            .textContentType(.newPassword)
                            .disableAutocorrection(true)
                            .textInputAutocapitalization(.never)
                            .disabled(authViewModel.isLoading)
                    }
                    Section {
                        Button(action: updatePassword) {
                            HStack {
                                if authViewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                } else {
                                    Text("forget.update_button".localized)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .disabled(!canUpdatePassword || authViewModel.isLoading)
                        .modifier(ConditionalButtonStyling())
                        .controlSize(.large)
                        .buttonBorderShape(.automatic)
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("forget.cancel".localized) {
                        dismiss()
                    }
                }
            }
            .alert("forget.error".localized, isPresented: $showError) {
                Button("ok".localized, role: .cancel) { }
            } message: {
                Text(authViewModel.errorMessage ?? "forget.error.unknown".localized)
            }
            .onAppear {
                isResetFlow = true
            }
            .onChange(of: authViewModel.session) { _, newSession in
                // 只在未处于 dismiss 状态且确实有新的 session 时才自动跳转到密码设置页面
                if isResetFlow && !isDismissing && authViewModel.session != nil && newSession != nil && step == .waitingEmail {
                    step = .newPassword
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ResetPasswordTokenReceived"))) { notification in
                // 接收到 deep link 通知时立即跳转到新密码步骤
                // Supabase已经在邮件链接验证后建立了session，我们只需跳转到密码重置页面
                if step != .newPassword && !isDismissing {
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
            // 防止重复调用
            await MainActor.run { isDismissing = true }
            
            // 优先检查当前session（邮件链接验证后Supabase建立的session）
            // 如果有session，使用SDK直接更新密码
            do {
                try await supabase.auth.update(user: UserAttributes(password: newPassword))
                await MainActor.run { dismiss() }
            } catch {
                // 如果SDK更新失败，输出错误但不直接返回，继续尝试其他方法
                print("[DEBUG] Supabase SDK password update failed: \(error.localizedDescription)")
                // 如果用户提供了邮箱，尝试使用邮箱和新密码重新登录
                if !email.isEmpty {
                    do {
                        _ = try await supabase.auth.signIn(email: email, password: newPassword)
                        // 登录成功，关闭视图
                        await MainActor.run { dismiss() }
                        return
                    } catch {
                        print("[DEBUG] Sign in with new password failed: \(error.localizedDescription)")
                    }
                }
                
                // 所有方法都失败
                await MainActor.run {
                    authViewModel.errorMessage = String(format: "forget.error.update_failed".localized, error.localizedDescription)
                    showError = true
                    isDismissing = false
                }
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
