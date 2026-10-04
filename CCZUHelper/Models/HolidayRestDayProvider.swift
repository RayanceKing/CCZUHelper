//
//  HolidayRestDayProvider.swift
//  CCZUHelper
//

import Foundation

enum HolidayRestDayProvider {
    private static let calendarURL = URL(string: "https://p48-calendars.icloud.com/holidays/cn_zh.ics")!
    // v2：v1 的解析规则有 bug（只读 DTSTART、漏掉带参数的 SUMMARY），换 key 丢弃旧缓存
    private static let cacheKeyDates = "holiday_rest_day_cache_dates_v2"
    private static let cacheKeyTimestamp = "holiday_rest_day_cache_timestamp_v2"
    private static let cacheTTL: TimeInterval = 24 * 60 * 60
    /// 防御用的上限：单个休息日事件最多展开这么多天
    private static let maxSpanDays = 120

    static func loadRestDayKeys(calendar: Calendar = .current) async -> Set<Int> {
        let now = Date()
        if let (cachedKeys, fetchedAt) = loadCache(), now.timeIntervalSince(fetchedAt) < cacheTTL {
            return cachedKeys
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: calendarURL)
            let keys = parseRestDayKeys(from: data, calendar: calendar)
            // 解析结果为空通常是格式变了而不是真的没有假期，此时保留上一次的有效缓存
            guard !keys.isEmpty else {
                return loadCache()?.0 ?? []
            }
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
        var startDate: Date?
        var endDate: Date?

        for line in lines {
            if line == "BEGIN:VEVENT" {
                inEvent = true
                summary = nil
                startDate = nil
                endDate = nil
                continue
            }
            if line == "END:VEVENT" {
                // 「休」为法定休息日；调休上班日标记是「（班）」，两者都含节假日名，靠括号区分
                if inEvent,
                   let summary, summary.contains("休"), !summary.contains("班"),
                   let start = startDate {
                    result.formUnion(dayKeys(from: start, toExclusive: endDate, calendar: calendar))
                }
                inEvent = false
                continue
            }
            guard inEvent else { continue }

            if let value = icsValue(line, for: "SUMMARY") {
                summary = value
            } else if let value = icsValue(line, for: "DTSTART") {
                startDate = icsDate(value, calendar: calendar)
            } else if let value = icsValue(line, for: "DTEND") {
                endDate = icsDate(value, calendar: calendar)
            }
        }
        return result
    }

    /// 取 `SUMMARY;LANGUAGE=zh_CN:国庆节（休）` 里的值，兼容 `SUMMARY:xxx` 的无参数写法。
    private static func icsValue(_ line: String, for property: String) -> String? {
        guard let colon = line.firstIndex(of: ":") else { return nil }
        let propertyPart = String(line[line.startIndex..<colon])
        guard propertyPart.components(separatedBy: ";").first == property else { return nil }
        return String(line[line.index(after: colon)...])
    }

    private static func icsDate(_ token: String, calendar: Calendar) -> Date? {
        guard token.count >= 8 else { return nil }
        let text = String(token.prefix(8))
        guard text.allSatisfy({ $0.isNumber }) else { return nil }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyyMMdd"
        return formatter.date(from: text)
    }

    /// 休息日在日历里是跨天事件（`DTSTART=10/01` + `DTEND=10/08`），DTEND 是排他的，要展开成 10/01–10/07 每一天。
    private static func dayKeys(from startDate: Date, toExclusive endDate: Date?, calendar: Calendar) -> Set<Int> {
        guard let end = endDate ?? calendar.date(byAdding: .day, value: 1, to: startDate) else { return [] }

        var keys: Set<Int> = []
        var current = startDate
        while current < end, keys.count < maxSpanDays {
            let comps = calendar.dateComponents([.year, .month, .day], from: current)
            if let y = comps.year, let m = comps.month, let d = comps.day {
                keys.insert(y * 10_000 + m * 100 + d)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return keys
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
