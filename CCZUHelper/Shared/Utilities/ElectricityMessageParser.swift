//
//  ElectricityMessageParser.swift
//  CCZUHelper
//
//  Created by Codex on 2026/2/16.
//

import Foundation

enum ElectricityMessageParser {
    private static let balanceRegex = try? NSRegularExpression(pattern: "[0-9]+\\.?[0-9]*")

    static func parseBalance(from message: String) -> Double? {
        guard let regex = balanceRegex,
              let match = regex.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)),
              let range = Range(match.range, in: message) else {
            return nil
        }
        return Double(message[range])
    }
}
