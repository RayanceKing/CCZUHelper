//
//  AppQuickActionManager.swift
//  CCZUHelper
//
//  Created by Codex on 2026/03/02.
//

import Foundation
#if os(iOS)
import UIKit
#endif

extension Notification.Name {
    static let appQuickActionRouteReceived = Notification.Name("AppQuickActionRouteReceived")
}

enum AppQuickActionRoute: String {
    case schedule
    case grades
    case teahouse
}

enum AppQuickActionManager {
    private static let pendingRouteKey = "quickaction.pending.route"

    #if os(iOS)
    private static var typePrefix: String {
        "\(Bundle.main.bundleIdentifier ?? "com.stuwang.edupal").quickaction."
    }
    #endif

    static func savePending(route: AppQuickActionRoute) {
        UserDefaults.standard.set(route.rawValue, forKey: pendingRouteKey)
    }

    static func consumePendingRoute() -> AppQuickActionRoute? {
        guard let raw = UserDefaults.standard.string(forKey: pendingRouteKey),
              let route = AppQuickActionRoute(rawValue: raw) else {
            return nil
        }
        UserDefaults.standard.removeObject(forKey: pendingRouteKey)
        return route
    }

    static func dispatch(route: AppQuickActionRoute) {
        NotificationCenter.default.post(name: .appQuickActionRouteReceived, object: route.rawValue)
    }

    #if os(iOS)
    @discardableResult
    static func handle(shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard let route = route(from: shortcutItem) else { return false }
        savePending(route: route)
        dispatch(route: route)
        return true
    }

    static func configureShortcutItems() {
        UIApplication.shared.shortcutItems = [
            UIApplicationShortcutItem(
                type: typePrefix + AppQuickActionRoute.schedule.rawValue,
                localizedTitle: "tab.schedule".localized,
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(type: .date),
                userInfo: nil
            ),
            UIApplicationShortcutItem(
                type: typePrefix + AppQuickActionRoute.grades.rawValue,
                localizedTitle: "intent.open_grades.title".localized,
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(type: .task),
                userInfo: nil
            ),
            UIApplicationShortcutItem(
                type: typePrefix + AppQuickActionRoute.teahouse.rawValue,
                localizedTitle: "tab.teahouse".localized,
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(type: .message),
                userInfo: nil
            ),
        ]
    }

    static func route(from shortcutItem: UIApplicationShortcutItem) -> AppQuickActionRoute? {
        let type = shortcutItem.type

        if type.hasPrefix(typePrefix) {
            let raw = String(type.dropFirst(typePrefix.count))
            if let route = AppQuickActionRoute(rawValue: raw) {
                return route
            }
        }

        if let lastDot = type.lastIndex(of: ".") {
            let suffix = String(type[type.index(after: lastDot)...])
            if let route = AppQuickActionRoute(rawValue: suffix) {
                return route
            }
        }

        return AppQuickActionRoute(rawValue: type)
    }
    #endif
}
