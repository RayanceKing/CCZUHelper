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
    @State private var showSystemClosedAlert = false
    
    let monitor = TeachingSystemMonitor.shared
    
    var body: some View {
        #if os(macOS)
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 10) {
                    Image("AppIcon-iOS-Default-128x128")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 88, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Text("app.name".localized)
                        .font(.system(size: 46, weight: .bold))

                    Text("app.subtitle".localized)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 12) {
                    TextField("login.username.placeholder".localized, text: $username)
                        .textContentType(.username)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isLoading)
                        .accessibilityLabel("login.username.accessibility".localized)

                    SecureField("login.password.placeholder".localized, text: $password)
                        .textContentType(.password)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.go)
                        .disabled(isLoading)
                        .accessibilityLabel("login.password.accessibility".localized)
                        .onSubmit { login() }
                }

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
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .buttonBorderShape(.automatic)
                .disabled(!canLogin || isLoading)

                Text("login.hint".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 24)
            .safeAreaInset(edge: .top) {
                TeachingSystemStatusBanner()
            }
            .navigationTitle("login.title".localized)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if #available(iOS 26.0, macOS 26.0, visionOS 2, *) {
                        Button(role: .cancel) {
                            dismiss()
                        }
                    } else {
                        Button("common.cancel".localized) {
                            dismiss()
                        }
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                if showError { TeachingErrorBanner(message: errorMessage) }
                if showSystemClosedAlert { TeachingErrorBanner(message: monitor.unavailableReason) }
            }
            .onAppear {
                print("✅ LoginView appeared on macOS")
            }
        }
        #else
        NavigationStack {
            Form {
                Section { 
                    VStack() {
                        Image("AppIcon-iOS-Default-128x128")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                        
                        Text("app.name".localized)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("app.subtitle".localized)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .listRowBackground(Color.clear)

                Section {
                    TextField("login.username.placeholder".localized, text: $username)
                        .textContentType(.username)
                        #if os(iOS)
                        .keyboardType(.default)
                        #endif
                        .disabled(isLoading)
                        .accessibilityLabel("login.username.accessibility".localized)
                    
                    SecureField("login.password.placeholder".localized, text: $password)
                        .textContentType(.password)
                        .submitLabel(.go)
                        .disabled(isLoading)
                        .accessibilityLabel("login.password.accessibility".localized)
                        .onSubmit {
                            login()
                        }
                }
                
                Section {
                    VStack(spacing: 10) {
                        if #available(iOS 26.0, macOS 26.0, *) {
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
                            }
                            .disabled(!canLogin || isLoading)
                            #if os(visionOS)
                            .buttonStyle(.borderedProminent)
                            #else
                            .buttonStyle(.glassProminent)
                            #endif
                            .controlSize(.large)
                            .buttonBorderShape(.automatic)
                        } else {
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
                            }
                            .disabled(!canLogin || isLoading)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .buttonBorderShape(.automatic)
                        }
                        
                        VStack(alignment: .center, spacing: 0) {
                            Text("login.hint".localized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        
                    }
                  
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("login.title".localized)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .safeAreaInset(edge: .top) {
                TeachingSystemStatusBanner()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                if showError { TeachingErrorBanner(message: errorMessage) }
                if showSystemClosedAlert { TeachingErrorBanner(message: monitor.unavailableReason) }
            }
            .onAppear {
                print("✅ LoginView appeared on iOS")
            }
        }
        #endif
    }
    
    private var canLogin: Bool {
        !username.isEmpty && !password.isEmpty
    }
    
    private func login() {
        guard canLogin, !isLoading else { return }
        showError = false
        showSystemClosedAlert = false
        
        // 第一步：检查是否是测试账户
        if TestData.isTestAccount(username) {
            handleTestAccountLogin()
            return
        }
        
        // 检查教务系统状态
        monitor.checkSystemStatus()
        if !monitor.isSystemAvailable {
            showSystemClosedAlert = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                // 使用 CCZUKit 进行登录（移除SSO方式）
                // Keep the current session until these credentials are verified.
                let client = DefaultHTTPClient(username: username, password: password)
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
                    
                    settings.acceptTeachingLogin(app, username: username)
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
                    
                    errorMessage = TeachingErrorPresentation.message(for: error) ?? ""
                    showError = !errorMessage.isEmpty
                }
            }
        }
    }
    
    /// 处理测试账户登录
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
                    
                    settings.teachingAccountError = nil
                    settings.isLoggedIn = true
                    settings.username = TestData.testUsername
                    settings.userDisplayName = testInfo.name
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    triggerErrorHaptic()
                    errorMessage = "test.account.login.failed".localized
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
