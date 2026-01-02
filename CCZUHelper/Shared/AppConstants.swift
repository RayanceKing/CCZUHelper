//
//  AppConstants.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/24.
//

import Foundation

/// 应用常量配置
/// 统一管理所有硬编码的 URL、密钥和服务标识符，便于维护和修改

// MARK: - Supabase 配置
struct SupabaseConstants {
    /// Supabase 项目 URL
    static let projectURL = "https://udrykrwyvnvmavbrdnnm.supabase.co"

    /// Supabase 匿名密钥
    static let anonKey = "sb_publishable_5mGAY5LN0WGnIIGwG30dxQ_mY7TuV_4"
}

// MARK: - 网站 URL
struct WebsiteURLs {
    /// 用户协议 URL
    static let termsOfService = "https://www.czumc.cn/terms"

    /// 隐私政策 URL
    static let privacyPolicy = "https://www.czumc.cn/privacy"
}

// MARK: - Keychain 服务标识符
struct KeychainServices {
    /// iCloud Keychain 服务标识符
    static let iCloudKeychain = "com.stuwang.edupal.icloud"

    /// 本地 Keychain 服务标识符（用于教务系统密码）
    static let localKeychain = "com.stuwang.edupal"
    
    /// 测试 Keychain 服务标识符
    static let testKeychain = "com.stuwang.edupal.test"
    
    /// 茶馆系统 Keychain 服务标识符
    static let teahouseKeychain = "com.stuwang.edupal.teahouse"
}

// MARK: - App Group 标识符
struct AppGroupIdentifiers {
    /// 主 App Group（用于共享数据）
    static let main = "group.com.stuwang.edupal"

    /// Watch App Group
    static let watch = "group.com.stuwang.edupal"
}

// MARK: - Bundle 标识符
struct BundleIdentifiers {
    /// 主应用 Bundle ID
    static let main = "com.stuwang.edupal"

    /// Widget Bundle ID
    static let widget = "com.stuwang.edupal.Widget"

    /// Watch App Bundle ID
    static let watchApp = "com.stuwang.edupal.watchkitapp"
}

// MARK: - 其他常量
struct AppConstants {
    /// 应用显示名称
    static let displayName = "龙城学伴"

    /// 应用版本（可通过 Info.plist 获取）
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    /// 应用构建版本
    static var buildVersion: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

