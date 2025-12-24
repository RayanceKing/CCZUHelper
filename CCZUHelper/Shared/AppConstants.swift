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
    static let iCloudKeychain = "cn.czumc.edupal.icloud"

    /// 本地 Keychain 服务标识符（用于教务系统密码）
    static let localKeychain = "cn.czumc.edupal"
    
    /// 测试 Keychain 服务标识符
    static let testKeychain = "cn.czumc.edupal.test"
    
    /// 茶馆系统 Keychain 服务标识符
    static let teahouseKeychain = "cn.czumc.edupal.teahouse"
}

// MARK: - App Group 标识符
struct AppGroupIdentifiers {
    /// 主 App Group（用于共享数据）
    static let main = "group.cn.czumc.edupal.edu"

    /// Watch App Group
    static let watch = "group.cn.czumc.edupal"
}

// MARK: - Bundle 标识符
struct BundleIdentifiers {
    /// 主应用 Bundle ID
    static let main = "cn.czumc.edupal"

    /// Widget Bundle ID
    static let widget = "cn.czumc.edupaledu.Widget"

    /// Watch App Bundle ID
    static let watchApp = "cn.czumc.edupaledu.watchkitapp"
}

// MARK: - AltStore 配置（仅用于发布）
struct AltStoreConstants {
    /// AltStore 图标 URL
    static let iconURL = "https://i.imgur.com/pb35BCW.png"

    /// AltStore 网站 URL
    static let websiteURL = "https://gitcode.com/StuWang/CCZUHelper"

    /// AltStore 赞助 URL
    static let patreonURL = "https://afdian.com/a/rayanceking/plan"

    /// AltStore 截图 URLs
    static let screenshotURLs = [
        "https://i.imgur.com/xz3PWpW.jpeg",
        "https://i.imgur.com/bOFP5hi.png"
    ]

    /// AltStore 特色图片 URL
    static let featureImageURL = "https://i.imgur.com/qhtQzKs.png"

    /// AltStore 下载 URL
    static let downloadURL = "https://atomgit.com/StuWang/CCZUHelper/releases/download/0.1.0/CCZUHelper.ipa"
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

