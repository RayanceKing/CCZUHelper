//
//  OnDeviceSummaryAvailabilityCache.swift
//  CCZUHelper
//
//  Created by Codex on 2026/2/22.
//

import Foundation

enum OnDeviceSummaryAvailabilityCache {
    private static let knownKey = "summary.foundation_models.known"
    private static let availableKey = "summary.foundation_models.available"
    private static let checkedAtKey = "summary.foundation_models.checked_at"

    // Re-check at most once every 12 hours.
    private static let refreshInterval: TimeInterval = 12 * 60 * 60

    static func cachedAvailability() -> Bool? {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: knownKey) else { return nil }
        return defaults.bool(forKey: availableKey)
    }

    static func shouldRefresh() -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: knownKey) else { return true }

        let checkedAt = defaults.double(forKey: checkedAtKey)
        guard checkedAt > 0 else { return true }

        return Date().timeIntervalSince1970 - checkedAt > refreshInterval
    }

    static func save(_ available: Bool) {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: knownKey)
        defaults.set(available, forKey: availableKey)
        defaults.set(Date().timeIntervalSince1970, forKey: checkedAtKey)
    }
}

