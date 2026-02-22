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
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                }
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
        #endif
    }
    
    private var canLogin: Bool {
        !username.isEmpty && !password.isEmpty
    }
    
    private func login() {
        guard canLogin else { return }
        
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
                // 配置教务应用实例（必须先配置，确保使用同一个实例）
                settings.configureJwqywx(username: username, password: password)
                
                guard let app = settings.jwqywxApplication else {
                    throw CCZUError.unknown("Failed to configure application")
                }
                
                // 获取用户真实姓名并自动预取培养方案
                _ = try await app.login()  // 登录成功后会自动预取培养方案
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
                        errorMessage = "login.error.invalid_credentials".localized
                    } else if errorDesc.contains("network") || errorDesc.contains("网络") || 
                              errorDesc.contains("connection") || errorDesc.contains("连接") {
                        errorMessage = "login.error.network".localized
                    } else if errorDesc.contains("timeout") || errorDesc.contains("超时") {
                        errorMessage = "login.error.timeout".localized
                    } else if errorDesc.contains("server") || errorDesc.contains("服务器") {
                        errorMessage = "login.error.server".localized
                    } else {
                        errorMessage = "login.error.unknown".localized(with: error.localizedDescription)
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
