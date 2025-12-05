//
//  AccountSyncManager.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/05.
//

import Foundation
import CCZUKit

/// 账号同步管理器 - 使用iCloud Keychain进行跨设备同步
enum AccountSyncManager {
    // MARK: - 常量
    private static let iCloudKeychainService = "com.cczu.helper.icloud"
    private static let localKeychainService = "com.cczu.helper"
    
    // MARK: - 同步账号信息到iCloud Keychain
    /// 将账号信息同步到iCloud Keychain（所有设备可访问）
    /// - Parameters:
    ///   - username: 用户名
    ///   - password: 密码
    /// - Returns: 是否同步成功
    @discardableResult
    static func syncAccountToiCloud(username: String, password: String) -> Bool {
        // 同时保存到iCloud Keychain和本地Keychain
        let iCloudSaved = KeychainHelper.save(
            service: iCloudKeychainService,
            account: username,
            password: password,
            synchronizable: true
        )
        
        let localSaved = KeychainHelper.save(
            service: localKeychainService,
            account: username,
            password: password,
            synchronizable: false
        )
        
        let success = iCloudSaved && localSaved
        print("📱 Account sync to iCloud: \(success ? "✅" : "❌")")
        return success
    }
    
    // MARK: - 从iCloud Keychain恢复账号信息
    /// 尝试从iCloud Keychain恢复账号信息
    /// - Returns: 恢复的账号信息元组 (username, password)
    static func retrieveAccountFromiCloud() -> (username: String, password: String)? {
        // 首先尝试从iCloud Keychain读取
        if let keychainAccounts = KeychainHelper.readAllAccounts(service: iCloudKeychainService) {
            // 返回第一个找到的账号
            for (username, password) in keychainAccounts {
                print("📱 Retrieved account from iCloud: \(username)")
                return (username, password)
            }
        }
        
        // 如果iCloud Keychain中没有，再尝试本地Keychain
        if let keychainAccounts = KeychainHelper.readAllAccounts(service: localKeychainService) {
            for (username, password) in keychainAccounts {
                print("💾 Retrieved account from local Keychain: \(username)")
                return (username, password)
            }
        }
        
        print("❌ No account found in Keychain")
        return nil
    }
    
    // MARK: - 删除iCloud同步的账号
    /// 删除iCloud Keychain中的账号信息
    /// - Parameter username: 用户名
    /// - Returns: 是否删除成功
    @discardableResult
    static func removeAccountFromiCloud(username: String) -> Bool {
        let iCloudRemoved = KeychainHelper.delete(
            service: iCloudKeychainService,
            account: username
        )
        
        let localRemoved = KeychainHelper.delete(
            service: localKeychainService,
            account: username
        )
        
        let success = iCloudRemoved && localRemoved
        print("🗑️ Remove account from iCloud: \(success ? "✅" : "❌")")
        return success
    }
    
    // MARK: - 自动同步账号到应用设置
    /// 自动从Keychain恢复账号并更新AppSettings
    /// - Parameter settings: 应用设置
    /// - Returns: 是否成功恢复并设置
    @discardableResult
    static func autoRestoreAccountIfAvailable(settings: AppSettings) -> Bool {
        if let (username, password) = retrieveAccountFromiCloud() {
            // 验证密码有效性并获取用户姓名
            Task {
                do {
                    let client = DefaultHTTPClient(username: username, password: password)
                    _ = try await client.ssoUniversalLogin()
                    
                    // 获取用户真实姓名
                    let app = JwqywxApplication(client: client)
                    _ = try await app.login()
                    let userInfoResponse = try await app.getStudentBasicInfo()
                    let realName = userInfoResponse.message.first?.name
                    
                    await MainActor.run {
                        settings.isLoggedIn = true
                        settings.username = username
                        settings.userDisplayName = realName ?? username
                        print("✅ Auto-restored account: \(realName ?? username)")
                    }
                } catch {
                    print("⚠️ Account credentials invalid, skipping auto-login: \(error)")
                    // 凭证无效，删除缓存
                    removeAccountFromiCloud(username: username)
                    await MainActor.run {
                        settings.isLoggedIn = false
                    }
                }
            }
            return true
        }
        return false
    }
    
    // MARK: - 检查iCloud Keychain可用性
    /// 检查设备是否启用了iCloud Keychain
    /// - Returns: iCloud Keychain是否可用
    static func isICloudKeychainAvailable() -> Bool {
        // 简单检查：尝试写入一个测试项
        let testService = "com.cczu.helper.test"
        let testAccount = "test_icloud_availability"
        let testPassword = "test_\(UUID().uuidString)"
        
        let saved = KeychainHelper.save(
            service: testService,
            account: testAccount,
            password: testPassword,
            synchronizable: true
        )
        
        if saved {
            // 清理测试项
            KeychainHelper.delete(service: testService, account: testAccount)
        }
        
        return saved
    }
}
