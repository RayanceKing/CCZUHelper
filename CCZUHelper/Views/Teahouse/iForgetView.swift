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
    @State private var isResetFlow = false
    @State private var isDismissing = false
    
    enum ResetStep {
        case email
        case waitingEmail
        case newPassword
    }
    
    private var headerIconName: String {
        switch step {
        case .email: return "key.fill"
        case .waitingEmail: return "envelope.badge.fill"
        case .newPassword: return "lock.rotation"
        }
    }

    private var headerTitle: String {
        switch step {
        case .email: return "forget.title".localized
        case .waitingEmail: return "forget.email_sent".localized
        case .newPassword: return "forget.set_password".localized
        }
    }

    private var headerSubtitle: String {
        switch step {
        case .email: return "forget.subtitle".localized
        case .waitingEmail: return "forget.email_sent_message".localized
        case .newPassword: return "forget.subtitle".localized
        }
    }

    @ViewBuilder
    private var contentCard: some View {
        VStack(spacing: 14) {
            switch step {
            case .email:
                TextField("teahouse.login.email.placeholder".localized, text: $email)
                    .textContentType(.emailAddress)
                    #if os(iOS) || os(tvOS) || os(visionOS)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    #endif
                    .textFieldStyle(.roundedBorder)
                    .disabled(authViewModel.isLoading)

                Text("forget.privacy_notice".localized)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

            case .waitingEmail:
                VStack(spacing: 10) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.blue)
                    Text("forget.email_sent".localized)
                        .font(.headline)
                    Text("forget.email_sent_message".localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)

            case .newPassword:
                SecureField("forget.new_password.placeholder".localized, text: $newPassword)
                    .textContentType(.newPassword)
                    .disableAutocorrection(true)
                    #if os(iOS) || os(tvOS) || os(visionOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .textFieldStyle(.roundedBorder)
                    .disabled(authViewModel.isLoading)

                SecureField("forget.confirm_password.placeholder".localized, text: $confirmPassword)
                    .textContentType(.newPassword)
                    .disableAutocorrection(true)
                    #if os(iOS) || os(tvOS) || os(visionOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .textFieldStyle(.roundedBorder)
                    .disabled(authViewModel.isLoading)
            }
        }
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var actionButton: some View {
        if step == .email || step == .newPassword {
            Button(action: {
                if step == .email {
                    sendResetEmail()
                } else {
                    updatePassword()
                }
            }) {
                HStack {
                    if authViewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Text(step == .email ? "forget.continue".localized : "forget.update_button".localized)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(
                (step == .email && (email.isEmpty || authViewModel.isLoading)) ||
                (step == .newPassword && (!canUpdatePassword || authViewModel.isLoading))
            )
            .modifier(ConditionalButtonStyling())
            .controlSize(.large)
            .buttonBorderShape(.automatic)
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 10) {
                        Image(systemName: headerIconName)
                            .font(.system(size: 48, weight: .semibold))
                            .foregroundStyle(.blue)

                        Text(headerTitle)
                            .font(.system(size: 30, weight: .bold))
                            .multilineTextAlignment(.center)

                        Text(headerSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                    }
                    .frame(maxWidth: .infinity)

                    contentCard

                    actionButton
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(Color.clear)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                }
            }
            .alert("forget.error".localized, isPresented: $showError) {
                Button("common.ok".localized, role: .cancel) { }
            } message: {
                Text(authViewModel.errorMessage ?? "forget.error.unknown".localized)
            }
            .onAppear {
                isResetFlow = true
                if let forced = forceStep, step != forced {
                    step = forced
                }
            }
            .onChange(of: forceStep) { _, newValue in
                if let forced = newValue, step != forced {
                    step = forced
                }
            }
            .onChange(of: authViewModel.session) { _, newSession in
                // 只在未处于 dismiss 状态且确实有新的 session 时才自动跳转到密码设置页面
                if isResetFlow && !isDismissing && authViewModel.session != nil && newSession != nil && step == .waitingEmail {
                    step = .newPassword
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ResetPasswordTokenReceived"))) { _ in
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
