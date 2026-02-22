//
//  KeychainHelper.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/02.
//

import Foundation
import Security

/// Keychain 封装，用于安全存储/读取用户密码，支持iCloud同步
enum KeychainHelper {
    private static let synchronizableAny = kSecAttrSynchronizableAny

    private static func makeBaseQuery(service: String, account: String? = nil) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        if let account {
            query[kSecAttrAccount as String] = account
        }
        return query
    }

    // MARK: - 保存密码
    /// 保存密码到Keychain
    /// - Parameters:
    ///   - service: 服务标识符
    ///   - account: 账户名称
    ///   - password: 密码
    ///   - synchronizable: 是否同步到iCloud Keychain
    @discardableResult
    static func save(
        service: String,
        account: String,
        password: String,
        synchronizable: Bool = false
    ) -> Bool {
        guard let data = password.data(using: .utf8) else { return false }
        // 先删除旧的（同时覆盖本地与 iCloud 同步项，避免重复项导致保存失败）
        _ = delete(service: service, account: account)
        
        var query = makeBaseQuery(service: service, account: account)
        query.merge([
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]) { _, new in new }
        
        // 如果需要同步到iCloud，添加同步标志
        if synchronizable {
            query[kSecAttrSynchronizable as String] = kCFBooleanTrue
        }
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // MARK: - 读取密码
    /// 从Keychain读取密码
    static func read(service: String, account: String) -> String? {
        var query = makeBaseQuery(service: service, account: account)
        query.merge([
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]) { _, new in new }
        // 支持读取本地与 iCloud Keychain 同步项
        query[kSecAttrSynchronizable as String] = synchronizableAny
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    // MARK: - 删除密码
    /// 从Keychain删除密码
    @discardableResult
    static func delete(service: String, account: String) -> Bool {
        var query = makeBaseQuery(service: service, account: account)
        // 同时删除本地和 iCloud 同步项
        query[kSecAttrSynchronizable as String] = synchronizableAny
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - 读取所有账户
    /// 读取特定服务下的所有账户和密码
    /// - Parameter service: 服务标识符
    /// - Returns: [(username, password)] 元组数组
    static func readAllAccounts(service: String) -> [(username: String, password: String)]? {
        var query = makeBaseQuery(service: service)
        query.merge([
            kSecReturnData as String: true,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]) { _, new in new }
        query[kSecAttrSynchronizable as String] = synchronizableAny
        
        var items: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &items)
        
        guard status == errSecSuccess, let dictArray = items as? [[String: Any]] else {
            return nil
        }
        
        var results: [(username: String, password: String)] = []
        
        for dict in dictArray {
            if let data = dict[kSecValueData as String] as? Data,
               let password = String(data: data, encoding: .utf8),
               let account = dict[kSecAttrAccount as String] as? String {
                results.append((username: account, password: password))
            }
        }
        
        return results.isEmpty ? nil : results
    }
    
    // MARK: - 检查账户是否存在
    /// 检查特定账户是否存在于Keychain
    static func accountExists(service: String, account: String) -> Bool {
        var query = makeBaseQuery(service: service, account: account)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecAttrSynchronizable as String] = synchronizableAny
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        return status == errSecSuccess
    }
}
