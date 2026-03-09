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
    struct AutoRestoreAccountResult {
        let username: String
        let displayName: String
        let avatarPath: String?
    }

    enum AutoRestoreOutcome {
        case restored(AutoRestoreAccountResult)
        case invalidCredentials
        case unavailable
    }

    // MARK: - 常量
    private static let iCloudKeychainService = KeychainServices.iCloudKeychain
    private static let localKeychainService = KeychainServices.localKeychain
    
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
    
    // MARK: - 同步用户头像到iCloud
    /// 将用户头像同步到iCloud Drive
    /// - Parameter avatarPath: 本地头像文件路径
    /// - Returns: 是否同步成功
    @discardableResult
    static func syncAvatarToiCloud(avatarPath: String) -> Bool {
        guard let ubiquityURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") else {
            print("⚠️ iCloud Drive not available")
            return false
        }
        
        let sourceURL = URL(fileURLWithPath: avatarPath)
        let fileName = sourceURL.lastPathComponent.replacingOccurrences(of: "avatar_", with: "avatar_synced_")
        let destinationURL = ubiquityURL.appendingPathComponent(fileName)
        
        do {
            // 创建 iCloud Documents 目录（如果不存在）
            try FileManager.default.createDirectory(at: ubiquityURL, withIntermediateDirectories: true)
            
            // 删除旧的iCloud头像
            if let existingFiles = try? FileManager.default.contentsOfDirectory(at: ubiquityURL, includingPropertiesForKeys: nil) {
                for file in existingFiles where file.lastPathComponent.hasPrefix("avatar_synced_") {
                    try? FileManager.default.removeItem(at: file)
                }
            }
            
            // 复制到iCloud
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            print("📱 Avatar synced to iCloud: \(fileName)")
            return true
        } catch {
            print("❌ Failed to sync avatar to iCloud: \(error)")
            return false
        }
    }
    
    /// 从iCloud恢复用户头像
    /// - Returns: 本地头像文件路径
    static func retrieveAvatarFromiCloud() -> String? {
        guard let ubiquityURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") else {
            return nil
        }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: ubiquityURL, includingPropertiesForKeys: nil)
            if let avatarFile = files.first(where: { $0.lastPathComponent.hasPrefix("avatar_synced_") }) {
                // 复制到本地文档目录
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let localFileName = avatarFile.lastPathComponent.replacingOccurrences(of: "avatar_synced_", with: "avatar_")
                let localURL = documentsPath.appendingPathComponent(localFileName)
                
                // 删除本地旧头像
                if let existingFiles = try? FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil) {
                    for file in existingFiles where file.lastPathComponent.hasPrefix("avatar_") {
                        try? FileManager.default.removeItem(at: file)
                    }
                }
                
                try FileManager.default.copyItem(at: avatarFile, to: localURL)
                print("📱 Avatar retrieved from iCloud: \(localFileName)")
                return localURL.path
            }
        } catch {
            print("❌ Failed to retrieve avatar from iCloud: \(error)")
        }
        return nil
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
        
        // 同时删除iCloud上的头像
        if let ubiquityURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") {
            if let files = try? FileManager.default.contentsOfDirectory(at: ubiquityURL, includingPropertiesForKeys: nil) {
                for file in files where file.lastPathComponent.hasPrefix("avatar_synced_") {
                    try? FileManager.default.removeItem(at: file)
                    print("🗑️ Removed avatar from iCloud: \(file.lastPathComponent)")
                }
            }
        }
        
        return success
    }
    
    // MARK: - 自动恢复账号信息
    /// 从 Keychain 自动恢复账号并校验凭证。
    /// - Returns: 恢复结果，调用方决定如何更新 UI 层状态。
    static func autoRestoreAccountIfAvailable() async -> AutoRestoreOutcome {
        guard let (username, password) = retrieveAccountFromiCloud() else {
            return .unavailable
        }

        let avatarPath = retrieveAvatarFromiCloud()

        do {
            let client = DefaultHTTPClient(username: username, password: password)
            _ = try await client.ssoUniversalLogin()

            let app = JwqywxApplication(client: client)
            _ = try await app.login()
            let userInfoResponse = try await app.getStudentBasicInfo()
            let realName = userInfoResponse.message.first?.name ?? username

            return .restored(
                AutoRestoreAccountResult(
                    username: username,
                    displayName: realName,
                    avatarPath: avatarPath
                )
            )
        } catch {
            print("⚠️ Account credentials invalid, skipping auto-login: \(error)")
            removeAccountFromiCloud(username: username)
            return .invalidCredentials
        }
    }
    
    // MARK: - 检查iCloud Keychain可用性
    /// 检查设备是否启用了iCloud Keychain
    /// - Returns: iCloud Keychain是否可用
    static func isICloudKeychainAvailable() -> Bool {
        // 简单检查：尝试写入一个测试项
        let testService = KeychainServices.testKeychain
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
