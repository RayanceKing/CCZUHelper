//
//  PasskeyAuthService.swift
//  CCZUHelper
//
//  茶馆 Supabase 通行密钥（Passkey / WebAuthn）接入层。
//
//  ⚠️ Supabase 的通行密钥 API 目前处于 Experimental 阶段，必须在该文件里用
//  `@_spi(Experimental) import Supabase` 才能访问。为避免实验性类型泄漏到视图层，
//  对外只暴露 `TeahousePasskey` 这个轻量模型。
//
//  Created for CCZUHelper on 2026/10/06.
//

import Foundation
@_spi(Experimental) import Supabase
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif
#if canImport(UIKit)
import UIKit
import Combine
#endif
#if canImport(AppKit)
import AppKit
#endif

// MARK: - 展示给 UI 的通行密钥模型

/// 一个已注册的通行密钥（与 Supabase `PasskeyListItem` 一一对应，但不含实验性依赖）
struct TeahousePasskey: Identifiable, Hashable {
    let id: UUID
    var friendlyName: String?
    let createdAt: Date
    let lastUsedAt: Date?

    /// 展示名称：优先用户自定义名，其次认证器推断名
    var displayName: String {
        if let friendlyName, !friendlyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return friendlyName
        }
        return "passkey.unnamed".localized
    }
}

// MARK: - 可用性与展示锚点

enum PasskeySupport {
    /// 当前平台是否支持系统原生通行密钥 UI（iOS 16+ / macOS 13+ / visionOS 1+）
    static var isAvailable: Bool {
        #if canImport(AuthenticationServices) && !os(tvOS) && !os(watchOS)
        if #available(iOS 16.0, macOS 13.0, visionOS 1.0, *) {
            return true
        }
        #endif
        return false
    }

    /// 用于弹出系统通行密钥面板的窗口
    @MainActor
    static var presentationAnchor: ASPresentationAnchor? {
        #if canImport(UIKit) && !os(watchOS)
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        return windows.first { $0.isKeyWindow } ?? windows.first
        #elseif canImport(AppKit)
        return NSApp.keyWindow ?? NSApp.windows.first { $0.isVisible }
        #else
        return nil
        #endif
    }
}

// MARK: - 错误

enum PasskeyAuthError: LocalizedError {
    case unavailable
    case noPresentationAnchor
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "passkey.error.unavailable".localized
        case .noPresentationAnchor:
            return "passkey.error.no_anchor".localized
        case .notSignedIn:
            return "passkey.error.not_signed_in".localized
        }
    }
}

extension Error {
    /// 是否是用户在系统面板里主动取消（这类错误不应弹提示）
    var isPasskeyUserCancellation: Bool {
        #if canImport(AuthenticationServices)
        let nsError = self as NSError
        let domain = ASAuthorizationError.errorDomain
        let canceledCode = ASAuthorizationError.Code.canceled.rawValue
        if nsError.domain == domain, nsError.code == canceledCode { return true }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
           underlying.domain == domain,
           underlying.code == canceledCode {
            return true
        }
        #endif
        return false
    }
}

// MARK: - 通行密钥管理

/// 已登录用户的通行密钥增删查改
@MainActor
final class PasskeyManager: ObservableObject {
    @Published private(set) var passkeys: [TeahousePasskey] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    var isAvailable: Bool { PasskeySupport.isAvailable }

    /// 当前是否已有可用会话（用 currentSession 避免触发刷新）
    private var hasSession: Bool {
        supabase.auth.currentSession != nil
    }

    func refresh() async {
        guard PasskeySupport.isAvailable else { return }
        guard hasSession else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let items = try await supabase.auth.listPasskeys()
            passkeys = items
                .map { TeahousePasskey(id: $0.id, friendlyName: $0.friendlyName, createdAt: $0.createdAt, lastUsedAt: $0.lastUsedAt) }
                .sorted { $0.createdAt > $1.createdAt }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 为当前账号注册一个新的通行密钥（必须已登录）
    @discardableResult
    func register() async -> Bool {
        guard PasskeySupport.isAvailable else {
            errorMessage = PasskeyAuthError.unavailable.errorDescription
            return false
        }
        guard let anchor = PasskeySupport.presentationAnchor else {
            errorMessage = PasskeyAuthError.noPresentationAnchor.errorDescription
            return false
        }
        guard hasSession else {
            errorMessage = PasskeyAuthError.notSignedIn.errorDescription
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let created = try await supabase.auth.registerPasskey(presentationAnchor: anchor)
            passkeys.insert(
                TeahousePasskey(id: created.id, friendlyName: created.friendlyName, createdAt: created.createdAt, lastUsedAt: created.lastUsedAt),
                at: 0
            )
            return true
        } catch {
            guard !error.isPasskeyUserCancellation else { return false }
            errorMessage = error.localizedDescription
            return false
        }
    }

    func rename(id: UUID, to name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard trimmed.count <= 120 else {
            errorMessage = "passkey.error.name_too_long".localized
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let updated = try await supabase.auth.renamePasskey(id: id, friendlyName: trimmed)
            if let index = passkeys.firstIndex(where: { $0.id == updated.id }) {
                passkeys[index].friendlyName = updated.friendlyName
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(id: UUID) async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await supabase.auth.deletePasskey(id: id)
            passkeys.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - 登录

extension AuthViewModel {
    /// 使用通行密钥登录（无需输入邮箱/密码）。成功时会自动更新 `session`，
    /// 触发 `Supabase authStateChanges`，因此登录页原有的成功回调会照常执行。
    func signInWithPasskey() async {
        guard PasskeySupport.isAvailable else {
            errorMessage = PasskeyAuthError.unavailable.errorDescription
            return
        }
        guard let anchor = PasskeySupport.presentationAnchor else {
            errorMessage = PasskeyAuthError.noPresentationAnchor.errorDescription
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await supabase.auth.signInWithPasskey(presentationAnchor: anchor)
            if let session = response.session {
                self.session = session
                await DeviceTokenSyncManager.syncDeviceTokenIfPossible()
                DeviceInfoSyncManager.syncDevice()
            }
        } catch {
            // 用户取消属于正常流程，不提示
            guard !error.isPasskeyUserCancellation else { return }
            errorMessage = error.localizedDescription
        }
    }
}
