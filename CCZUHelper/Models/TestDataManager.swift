//
//  TestDataManager.swift
//  CCZUHelper
//
//  Created by rayanceking on 2026/02/25.
//

import Foundation

/// 测试账户数据管理器
class TestDataManager {
    /// 检查并处理测试账户登陆
    /// - Parameters:
    ///   - input: 登陆邮箱或学号
    ///   - password: 登陆密码（测试账户可为空或为"test"）
    /// - Returns: 如果是测试账户返回 true，否则返回 false
    static func handleTestAccountLogin(input: String, password: String) -> Bool {
        print("🔐 TestDataManager.handleTestAccountLogin called:")
        print("  Input: \(input)")
        print("  Password: \(password.isEmpty ? "(empty)" : password)")
        
        guard TestData.isTestAccount(input) else { 
            print("  ❌ Not a test account")
            return false 
        }
        
        print("  ✅ Is test account")
        
        // 测试账户：密码可为空，直接本地登陆
        if password.isEmpty || password.lowercased() == "test" {
            print("  ✅ Password valid")
            // 保存测试账户信息到 Keychain
            saveTestAccountToKeychain()
            return true
        }
        
        print("  ❌ Invalid password: \(password)")
        return false
    }
    
    /// 保存测试账户到 Keychain
    private static func saveTestAccountToKeychain() {
        let keychain = KeychainServices.localKeychain
        KeychainHelper.save(
            service: keychain,
            account: TestData.testUsername,
            password: TestData.testEmail,
            synchronizable: true
        )
    }
    
    /// 获取测试账户的学生信息
    static func getTestStudentInfo() -> UserBasicInfo {
        return TestData.sampleStudentInfo
    }
    
    /// 获取测试账户的课程数据
    static func getTestCourses() -> [String: [[String: Any]]] {
        return TestData.sampleCourses
    }
    
    /// 检查当前账户是否为测试账户
    static func isCurrentUserTestAccount(username: String) -> Bool {
        return username == TestData.testUsername
    }
}

