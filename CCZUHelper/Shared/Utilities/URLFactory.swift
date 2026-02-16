//
//  URLFactory.swift
//  CCZUHelper
//
//  Created by Codex on 2026/2/16.
//

import Foundation

enum URLFactory {
    static func makeURL(_ rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }
}
