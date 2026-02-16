//
//  PasswordStrengthEvaluator.swift
//  CCZUHelper
//
//  Created by Codex on 2026/2/16.
//

import Foundation

enum PasswordStrengthLevel {
    case weak
    case medium
    case strong
}

enum PasswordStrengthEvaluator {
    static func score(for password: String) -> Int {
        var score = 0
        if password.count >= 8 { score += 1 }
        if password.range(of: "[A-Z]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[a-z]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[0-9]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[!@#$%^&*()_+=-]", options: .regularExpression) != nil { score += 1 }
        return score
    }

    static func level(for password: String) -> PasswordStrengthLevel {
        let currentScore = score(for: password)
        switch currentScore {
        case 0...2:
            return .weak
        case 3...4:
            return .medium
        default:
            return .strong
        }
    }

    static func isAtLeastMedium(_ password: String) -> Bool {
        score(for: password) >= 3
    }
}
