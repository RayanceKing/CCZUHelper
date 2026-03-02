//
//  DeviceTokenSyncManager.swift
//  CCZUHelper
//
//  Created by RayanceKing on 2026/03/01.
//

import Foundation
import Supabase

enum DeviceTokenSyncManager {
    static let apnsTokenKey = "apns_token"
    static let isCommentNotifyEnabledKey = "isCommentNotifyEnabled"
    static let isBannerNotifyEnabledKey = "isBannerNotifyEnabled"

    private struct UserDevicePayload: Encodable {
        let userId: String
        let deviceToken: String
        let provider: String
        let isCommentNotifyEnabled: Bool
        let isBannerNotifyEnabled: Bool
        let lastSeen: String

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case deviceToken = "device_token"
            case provider
            case isCommentNotifyEnabled = "is_comment_notify_enabled"
            case isBannerNotifyEnabled = "is_banner_notify_enabled"
            case lastSeen = "last_seen"
        }
    }

    static var isCommentNotifyEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: isCommentNotifyEnabledKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: isCommentNotifyEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: isCommentNotifyEnabledKey)
        }
    }

    static var isBannerNotifyEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: isBannerNotifyEnabledKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: isBannerNotifyEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: isBannerNotifyEnabledKey)
        }
    }

    static func storeToken(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        guard !token.isEmpty else { return }
        UserDefaults.standard.set(token, forKey: apnsTokenKey)
    }

    static func syncDeviceTokenIfPossible() async {
        guard let token = UserDefaults.standard.string(forKey: apnsTokenKey), !token.isEmpty else {
            return
        }
        guard let userId = supabase.auth.currentSession?.user.id.uuidString else {
            return
        }

        let payload = UserDevicePayload(
            userId: userId,
            deviceToken: token,
            provider: "apns",
            isCommentNotifyEnabled: isCommentNotifyEnabled,
            isBannerNotifyEnabled: isBannerNotifyEnabled,
            lastSeen: ISO8601DateFormatter().string(from: Date())
        )

        do {
            _ = try await supabase
                .from("user_devices")
                .upsert(payload, onConflict: "user_id,device_token")
                .execute()
        } catch {
            print("⚠️ 同步设备 Token 失败: \(error.localizedDescription)")
        }
    }

    static func updateCommentNotifyEnabled(_ enabled: Bool) async {
        isCommentNotifyEnabled = enabled
        await syncDeviceTokenIfPossible()
    }

    static func updateBannerNotifyEnabledForHideBanners(_ hideBanners: Bool) async {
        isBannerNotifyEnabled = !hideBanners
        await syncDeviceTokenIfPossible()
    }
}
