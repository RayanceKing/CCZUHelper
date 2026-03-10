//
//  DeviceInfoSyncManager.swift
//  CCZUHelper
//
//  Created by RayanceKing on 2026/03/01.
//

import Foundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
import Supabase

/// 设备信息同步管理器
/// 用于跟踪设备的应用版本、设备类型等信息到 Supabase
enum DeviceInfoSyncManager {
    
    private struct DeviceInfoPayload: Encodable {
        let deviceId: String
        let appVersion: String
        let deviceType: String
        let lastSeen: String
        let userId: String?
        
        enum CodingKeys: String, CodingKey {
            case deviceId = "device_id"
            case appVersion = "app_version"
            case deviceType = "device_type"
            case lastSeen = "last_seen"
            case userId = "user_id"
        }
    }
    
    /// 同步设备信息到 Supabase user_devices 表
    /// 支持已登录用户（关联 user_id）和未登录用户（匿名追踪）
    nonisolated static func syncDevice() {
        Task { @MainActor in
            #if canImport(UIKit)
            let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
            let deviceType = UIDevice.current.model
            #else
            let deviceID = "unknown"
            let deviceType = "macOS"
            #endif
            
            let shortVersion = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let buildVersion = (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let version: String
            if let shortVersion, !shortVersion.isEmpty {
                version = shortVersion
            } else if let buildVersion, !buildVersion.isEmpty {
                version = buildVersion
            } else {
                version = "unknown"
            }

            let payload = DeviceInfoPayload(
                deviceId: deviceID,
                appVersion: version,
                deviceType: deviceType,
                lastSeen: ISO8601DateFormatter().string(from: Date()),
                userId: supabase.auth.currentUser?.id.uuidString
            )

            do {
                try await supabase
                    .from("user_devices")
                    .upsert(payload, onConflict: "device_id")
                    .execute()
                print("✅ 设备信息同步成功: \(deviceID)")
            } catch {
                print("⚠️ 设备信息同步失败: \(error.localizedDescription)")
            }
        }
    }
}
