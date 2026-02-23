//
//  SiriAuthorizationManager.swift
//  CCZUHelper
//
//  Created by Codex on 2026/2/23.
//

#if canImport(Intents) && !os(macOS)
import Intents

enum SiriAuthorizationManager {
    static func requestIfNeeded() {
        guard INPreferences.siriAuthorizationStatus() == .notDetermined else { return }
        INPreferences.requestSiriAuthorization { _ in }
    }
}
#endif

