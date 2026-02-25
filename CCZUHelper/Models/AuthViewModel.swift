//
//  AuthViewModel.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/14.
//

import Foundation
import Supabase
import Combine

// MARK: - AuthViewModel
@MainActor
class AuthViewModel: ObservableObject {
    @Published var session: Session?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let keychainService = KeychainServices.teahouseKeychain
    private let emailKey = "teahouse.email"
    private var authStateTask: Task<Void, Never>?

    init() {
        self.session = supabase.auth.currentSession
        // 监听认证状态变化
        startAuthStateListener()
        // 如果没有当前会话，尝试从 Keychain 恢复
        if session == nil {
            Task {
                await restoreSession()
            }
        }
    }
    
    deinit {
        authStateTask?.cancel()
    }
    
    /// 监听 Supabase 认证状态变化
    private func startAuthStateListener() {
        authStateTask = Task {
            for await (_, session) in supabase.auth.authStateChanges {
                self.session = session
            }
        }
    }
    
    /// 从 Keychain 恢复会话
    private func restoreSession() async {
        guard let email = KeychainHelper.read(service: keychainService, account: emailKey),
              let password = KeychainHelper.read(service: keychainService, account: email) else {
            return
        }
        
        // 静默登录
        do {
            self.session = try await supabase.auth.signIn(
                email: email,
                password: password
            )
        } catch {
            // 静默失败，清除无效凭据
            clearCredentials()
        }
    }
    
    /// 清除保存的凭据
    private func clearCredentials() {
        if let email = KeychainHelper.read(service: keychainService, account: emailKey) {
            KeychainHelper.delete(service: keychainService, account: email)
        }
        KeychainHelper.delete(service: keychainService, account: emailKey)
    }

    func signUp(email: String, password: String, metadata: [String: AnyJSON]? = nil) async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await supabase.auth.signUp(
                email: email,
                password: password,
                data: metadata
            )
            self.session = response.session
            // 保存凭据
            saveCredentials(email: email, password: password)
        } catch {
            let errDesc = error.localizedDescription.lowercased()
            if errDesc.contains("403") || errDesc.contains("forbidden") {
                errorMessage = "确保教务系统登录"
            } else {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            self.session = try await supabase.auth.signIn(
                email: email,
                password: password
            )
            // 保存凭据
            saveCredentials(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
    
    /// 保存登录凭据到 Keychain
    private func saveCredentials(email: String, password: String) {
        KeychainHelper.save(service: keychainService, account: emailKey, password: email, synchronizable: true)
        KeychainHelper.save(service: keychainService, account: email, password: password, synchronizable: true)
    }

    func signOut() async {
        try? await supabase.auth.signOut()
        session = nil
        clearCredentials()
    }
    
    func deleteAccount(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 先重新认证以确认身份
            _ = try await supabase.auth.signIn(
                email: email,
                password: password
            )
            
            // 调用 Supabase RPC 函数删除账户
            try await supabase.rpc("delete_user").execute()
            
            // 清除本地会话和凭据
            session = nil
            clearCredentials()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func resetPassword(email: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabase.auth.resetPasswordForEmail(email, redirectTo: URL(string: "edupal://reset-password"))
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
        /// 使用RPC调用注册学生资料
    /// - Parameters:
    ///   - realName: 真实姓名
    ///   - studentID: 学号
    ///   - className: 班级
    ///   - grade: 年级
    ///   - collegeName: 学院
    ///   - username: 用户名
    ///   - avatarUrl: 头像URL
    func registerStudentProfileWithRPC(
        realName: String,
        studentID: String,
        className: String,
        grade: Int,
        collegeName: String,
        username: String? = nil,
        avatarUrl: String? = nil
    ) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 构建 AnyJSON 参数字典
            var parameters: [String: AnyJSON] = [:]
            parameters["p_real_name"] = AnyJSON(stringLiteral: realName)
            parameters["p_student_id"] = AnyJSON(stringLiteral: studentID)
            parameters["p_class_name"] = AnyJSON(stringLiteral: className)
            parameters["p_grade"] = AnyJSON(integerLiteral: grade)
            parameters["p_college_name"] = AnyJSON(stringLiteral: collegeName)
            
            // 添加 username 和 avatar_url 参数（如果提供）
            if let username = username {
                parameters["p_username"] = AnyJSON(stringLiteral: username)
            }
            if let avatarUrl = avatarUrl {
                parameters["p_avatar_url"] = AnyJSON(stringLiteral: avatarUrl)
            }
            
            try await supabase.rpc("register_student_profile", params: parameters).execute()
            print("✅ 通过RPC成功注册学生资料")
        } catch {
            let errDesc = error.localizedDescription.lowercased()
            if errDesc.contains("duplicate") {
                errorMessage = "error.duplicate_account".localized
            } else {
                errorMessage = error.localizedDescription
            }
        }
        
        isLoading = false
    }
    
    var isAuthenticated: Bool {
        session != nil
    }
}
