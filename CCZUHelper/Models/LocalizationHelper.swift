//
//  LocalizationHelper.swift
//  CCZUHelper
//
//  Created for internationalization support
//

import Foundation
import SwiftUI

/// Extension to simplify localization usage
extension String {
    /// Returns the localized string for the current key
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    /// Returns a localized string with formatted arguments
    func localized(with arguments: CVarArg...) -> String {
        return String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
    }
}

/// Localization helper for common strings
struct LocalizedStrings {
    // MARK: - Common
    static let ok = "ok".localized
    static let cancel = "cancel".localized
    static let close = "close".localized
    static let done = "done".localized
    static let retry = "retry".localized
    static let loading = "loading".localized
    static let refresh = "refresh".localized
    static let all = "all".localized
    static let search = "search".localized
    static let delete = "delete".localized
    static let confirm = "confirm".localized
    
    // MARK: - App
    static let appName = "app.name".localized
    static let appSubtitle = "app.subtitle".localized
    
    // MARK: - Tab Bar
    static let tabSchedule = "tab.schedule".localized
    static let tabServices = "tab.services".localized
    static let tabTeahouse = "tab.teahouse".localized
    
    // MARK: - Login
    static let loginTitle = "login.title".localized
    static let loginUsernamePlaceholder = "login.username.placeholder".localized
    static let loginPasswordPlaceholder = "login.password.placeholder".localized
    static let loginButton = "login.button".localized
    static let loginHint = "login.hint".localized
    static let loginFailed = "login.failed".localized
    
    // MARK: - Schedule
    static let scheduleToday = "schedule.today".localized
    
    // MARK: - Services
    static let servicesTitle = "services.title".localized
    
    // MARK: - Settings
    static let settingsTitle = "settings.title".localized
}
