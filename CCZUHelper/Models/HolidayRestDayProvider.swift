//
//  HolidayRestDayProvider.swift
//  CCZUHelper
//

import Foundation

enum HolidayRestDayProvider {
    private static let calendarURL = URL(string: "https://p48-calendars.icloud.com/holidays/cn_zh.ics")!
    private static let cacheKeyDates = "holiday_rest_day_cache_dates_v1"
    private static let cacheKeyTimestamp = "holiday_rest_day_cache_timestamp_v1"
    private static let cacheTTL: TimeInterval = 24 * 60 * 60

    static func loadRestDayKeys(calendar: Calendar = .current) async -> Set<Int> {
        let now = Date()
        if let (cachedKeys, fetchedAt) = loadCache(), now.timeIntervalSince(fetchedAt) < cacheTTL {
            return cachedKeys
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: calendarURL)
            let keys = parseRestDayKeys(from: data, calendar: calendar)
            saveCache(keys: keys, fetchedAt: now)
            return keys
        } catch {
            // 网络失败时回退到历史缓存，避免功能失效
            if let (cachedKeys, _) = loadCache() {
                return cachedKeys
            }
            return []
        }
    }

    private static func parseRestDayKeys(from data: Data, calendar: Calendar) -> Set<Int> {
        guard let raw = String(data: data, encoding: .utf8) else { return [] }
        let lines = unfoldICSLines(raw)
        var result: Set<Int> = []

        var inEvent = false
        var summary: String?
        var dateToken: String?

        for line in lines {
            if line == "BEGIN:VEVENT" {
                inEvent = true
                summary = nil
                dateToken = nil
                continue
            }
            if line == "END:VEVENT" {
                if inEvent, let summary, summary.contains("休"), let dateToken,
                   let dayKey = dayKey(fromDateToken: dateToken, calendar: calendar) {
                    result.insert(dayKey)
                }
                inEvent = false
                continue
            }
            guard inEvent else { continue }

            if line.hasPrefix("SUMMARY:") {
                summary = String(line.dropFirst("SUMMARY:".count))
            } else if line.hasPrefix("DTSTART") {
                // 兼容 DTSTART;VALUE=DATE:20260406 / DTSTART:20260406T000000Z
                if let idx = line.firstIndex(of: ":") {
                    let value = line[line.index(after: idx)...]
                    dateToken = String(value)
                }
            }
        }
        return result
    }

    private static func dayKey(fromDateToken token: String, calendar: Calendar) -> Int? {
        guard token.count >= 8 else { return nil }
        let digits = token.prefix(8)
        let text = String(digits)
        guard text.allSatisfy({ $0.isNumber }) else { return nil }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyyMMdd"
        guard let date = formatter.date(from: text) else { return nil }

        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        guard let y = comps.year, let m = comps.month, let d = comps.day else { return nil }
        return y * 10_000 + m * 100 + d
    }

    private static func unfoldICSLines(_ source: String) -> [String] {
        let normalized = source.replacingOccurrences(of: "\r\n", with: "\n")
        let chunks = normalized.components(separatedBy: "\n")
        var lines: [String] = []

        for chunk in chunks {
            if (chunk.hasPrefix(" ") || chunk.hasPrefix("\t")), !lines.isEmpty {
                let continued = String(chunk.dropFirst())
                lines[lines.count - 1].append(continued)
            } else {
                lines.append(chunk)
            }
        }
        return lines
    }

    private static func loadCache() -> (Set<Int>, Date)? {
        let defaults = UserDefaults.standard
        guard let numbers = defaults.array(forKey: cacheKeyDates) as? [Int],
              let fetchedAt = defaults.object(forKey: cacheKeyTimestamp) as? Double else {
            return nil
        }
        return (Set(numbers), Date(timeIntervalSince1970: fetchedAt))
    }

    private static func saveCache(keys: Set<Int>, fetchedAt: Date) {
        let defaults = UserDefaults.standard
        defaults.set(Array(keys), forKey: cacheKeyDates)
        defaults.set(fetchedAt.timeIntervalSince1970, forKey: cacheKeyTimestamp)
    }
}
