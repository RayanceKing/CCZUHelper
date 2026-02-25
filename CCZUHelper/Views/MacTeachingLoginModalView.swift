//
//  MacTeachingLoginModalView.swift
//  CCZUHelper
//
//  Created by Codex on 2026/02/24.
//

import SwiftUI
import CCZUKit

#if os(macOS)
struct MacTeachingLoginModalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppSettings.self) private var settings

    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSystemClosedAlert = false

    private let monitor = TeachingSystemMonitor.shared

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 16) {
                    Image("AppIcon-iOS-Default-128x128")
                        .resizable()
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("login.title".localized)
                            .font(.system(size: 38, weight: .bold))
                            .foregroundStyle(.primary)

                        Text("app.subtitle".localized)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 22)
                .padding(.bottom, 16)

                VStack(spacing: 10) {
                    TextField("login.username.placeholder".localized, text: $username)
                        .textContentType(.username)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .frame(height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(inputBackgroundColor)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(inputBorderColor, lineWidth: 1)
                                )
                        )
                        .disabled(isLoading)

                    SecureField("login.password.placeholder".localized, text: $password)
                        .textContentType(.password)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .frame(height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(inputBackgroundColor)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(inputBorderColor, lineWidth: 1)
                                )
                        )
                        .disabled(isLoading)
                        .onSubmit { login() }

                    HStack {
                        Button("login.forgot_password".localized) {
                            guard let url = URL(string: "http://jwqywx.cczu.edu.cn/") else { return }
                            openURL(url)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                        .padding(.top, 6)

                        Spacer()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 14)

                Divider()
                    .overlay(Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.10))

                HStack(spacing: 10) {
                    Spacer()

                    Button("common.cancel".localized) {
                        dismiss()
                    }
                    .buttonStyle(.bordered)

                    Button {
                        print("🖱️ [macOS] Login button clicked! username='\(username)', password='\(password.isEmpty ? "(empty)" : password)'")
                        login()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("login.button".localized)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canLogin || isLoading)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
            }
            .frame(width: 700)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.10), lineWidth: 1)
                    )
            )
        }
        .alert("login.failed".localized, isPresented: $showError) {
            Button("common.ok".localized, role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("teaching_system.unavailable_title".localized, isPresented: $showSystemClosedAlert) {
            Button("common.ok".localized, role: .cancel) { }
        } message: {
            Text(monitor.unavailableReason)
        }
    }

    private var canLogin: Bool {
        !username.isEmpty && !password.isEmpty
    }

    private var inputBackgroundColor: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    private var inputBorderColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.20 : 0.12)
    }

    private func login() {
        guard canLogin else { return }

        print("🔓 [MacTeachingLoginModalView] login() called with username: \(username)")
        
        // 第一步：检查是否是测试账户
        if TestData.isTestAccount(username) {
            print("✅ [macOS] Detected as test account, calling handleTestAccountLogin()")
            handleTestAccountLogin()
            return
        }

        print("❌ [macOS] Not a test account, trying regular login")
        
        monitor.checkSystemStatus()
        if !monitor.isSystemAvailable {
            showSystemClosedAlert = true
            return
        }

        isLoading = true

        Task {
            do {
                settings.configureJwqywx(username: username, password: password)
                guard let app = settings.jwqywxApplication else {
                    throw CCZUError.unknown("Failed to configure application")
                }

                _ = try await app.login()
                let userInfoResponse = try await app.getStudentBasicInfo()
                let realName = userInfoResponse.message.first?.name

                await MainActor.run {
                    _ = AccountSyncManager.syncAccountToiCloud(username: username, password: password)
                    settings.isLoggedIn = true
                    settings.username = username
                    settings.userDisplayName = realName ?? username
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = friendlyErrorMessage(for: error)
                    showError = true
                }
            }
        }
    }
    
    /// 处理 macOS 测试账户登录
    private func handleTestAccountLogin() {
        isLoading = true
        
        Task {
            do {
                // 验证测试账户密码（可为空或为 "test"）
                guard TestDataManager.handleTestAccountLogin(input: username, password: password) else {
                    throw CCZUError.unknown("Invalid test account password")
                }
                
                // 获取测试账户的学生信息
                let testInfo = TestDataManager.getTestStudentInfo()
                
                await MainActor.run {
                    // 保存到 Keychain
                    AccountSyncManager.syncAccountToiCloud(
                        username: TestData.testUsername,
                        password: username
                    )
                    
                    settings.isLoggedIn = true
                    settings.username = TestData.testUsername
                    settings.userDisplayName = testInfo.name
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = friendlyErrorMessage(for: error)
                    showError = true
                }
            }
        }
    }

    private func friendlyErrorMessage(for error: Error) -> String {
        let desc = error.localizedDescription.lowercased()
        if desc.contains("authentication") || desc.contains("认证") ||
            desc.contains("401") || desc.contains("用户名") ||
            desc.contains("密码") || desc.contains("incorrect") {
            return "login.error.invalid_credentials".localized
        }
        if desc.contains("network") || desc.contains("网络") ||
            desc.contains("connection") || desc.contains("连接") {
            return "login.error.network".localized
        }
        if desc.contains("timeout") || desc.contains("超时") {
            return "login.error.timeout".localized
        }
        if desc.contains("server") || desc.contains("服务器") {
            return "login.error.server".localized
        }
        return "login.error.unknown".localized(with: error.localizedDescription)
    }
}
#endif
