//
//  TeahouseDecoding.swift
//  CCZUHelper
//
//  Created by rayanceking on 2026/3/14.
//

import Foundation

enum TeahouseDecoding {
    nonisolated static func makeJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(decodeFlexibleDate)
        return decoder
    }

    nonisolated static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try makeJSONDecoder().decode(type, from: data)
    }

    nonisolated static func parseDate(_ rawValue: String) -> Date? {
        if let date = fractionalISO8601Formatter.date(from: rawValue)
            ?? internetDateTimeFormatter.date(from: rawValue) {
            return date
        }

        guard let normalized = normalizedFractionalSecondsTimestamp(from: rawValue) else {
            return nil
        }

        return fractionalISO8601Formatter.date(from: normalized)
            ?? internetDateTimeFormatter.date(from: normalized)
    }

    private nonisolated static func decodeFlexibleDate(from decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()

        if let timestamp = try? container.decode(Double.self) {
            return dateFromTimestamp(timestamp)
        }

        if let timestamp = try? container.decode(Int.self) {
            return dateFromTimestamp(Double(timestamp))
        }

        let rawValue = try container.decode(String.self)
        if let date = parseDate(rawValue) {
            return date
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Unsupported date format: \(rawValue)"
        )
    }

    private nonisolated static func dateFromTimestamp(_ timestamp: Double) -> Date {
        let seconds = timestamp > 10_000_000_000 ? timestamp / 1_000 : timestamp
        return Date(timeIntervalSince1970: seconds)
    }

    private nonisolated static func normalizedFractionalSecondsTimestamp(from rawValue: String) -> String? {
        guard let dotIndex = rawValue.firstIndex(of: ".") else { return nil }

        let suffix = rawValue[rawValue.index(after: dotIndex)...]
        guard let timezoneStart = suffix.firstIndex(where: { $0 == "Z" || $0 == "+" || $0 == "-" }) else {
            return nil
        }

        let fractionalPart = suffix[..<timezoneStart]
        guard !fractionalPart.isEmpty else { return nil }

        let normalizedFractionalPart: String
        switch fractionalPart.count {
        case 1:
            normalizedFractionalPart = "\(fractionalPart)00"
        case 2:
            normalizedFractionalPart = "\(fractionalPart)0"
        case 3:
            return nil
        default:
            normalizedFractionalPart = String(fractionalPart.prefix(3))
        }

        let prefix = rawValue[..<dotIndex]
        let timezone = suffix[timezoneStart...]
        return "\(prefix).\(normalizedFractionalPart)\(timezone)"
    }

    private nonisolated(unsafe) static let internetDateTimeFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private nonisolated(unsafe) static let fractionalISO8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
