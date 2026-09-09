import Foundation

/// 课程信息(已解析)
public struct ParsedCourse: Sendable {
    public let name: String
    public let teacher: String
    public let location: String
    public let weeks: [Int]
    public let dayOfWeek: Int
    public let timeSlot: Int

    public init(name: String, teacher: String, location: String, weeks: [Int], dayOfWeek: Int, timeSlot: Int) {
        self.name = name
        self.teacher = teacher
        self.location = location
        self.weeks = weeks
        self.dayOfWeek = dayOfWeek
        self.timeSlot = timeSlot
    }
}

/// 日历解析器
public struct CalendarParser {

    /// 解析周课表矩阵
    /// - Parameter matrix: 课表原始数据,格式为 [[RawCourse]]
    /// - Returns: 解析后的课程列表
    public static func parseWeekMatrix(_ matrix: [[RawCourse]]) -> [ParsedCourse] {
        var courses: [ParsedCourse] = []

        for (timeIndex, timeCourses) in matrix.enumerated() {
            for (dayIndex, rawCourse) in timeCourses.enumerated() {
                if rawCourse.course.isEmpty {
                    continue
                }

                // 解析课程字符串
                // 格式示例: "高等数学 1-16周 教学楼A101"
                let courseParts = rawCourse.course.split(separator: "/")

                let teacherParts = rawCourse.teacher.components(separatedBy: ",/")
                for (index, part) in courseParts.enumerated() {
                    let trimmed = part.trimmingCharacters(in: .whitespaces)
                    if trimmed.isEmpty { continue }

                    let components = trimmed.split(separator: " ").map(String.init)

                    if components.isEmpty { continue }

                    let name = components[0]
                    var location = ""
                    var weeks: [Int] = []

                    // 解析周次和地点
                    var locationParts: [String] = []
                    var weekComponents: [String] = []  // 收集所有周次相关的components

                    for component in components.dropFirst() {
                        let compTrimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
                        if compTrimmed.isEmpty { continue }

                        // 检查是否是周次相关component
                        // 1. 包含"周"字
                        // 2. 是"单"或"双"
                        // 3. 匹配周次格式: 纯数字和连字符、逗号组成
                        if compTrimmed.contains("周") ||
                           compTrimmed == "单" || compTrimmed == "双" ||
                           compTrimmed.range(of: "^[\\d,-]+[,，]?$", options: .regularExpression) != nil {
                            weekComponents.append(compTrimmed)
                            continue
                        }

                        // 非周次部分视为地点或附加信息，收集起来
                        let cleaned = compTrimmed.trimmingCharacters(in: CharacterSet(charactersIn: ",，;:。"))
                        if !cleaned.isEmpty {
                            locationParts.append(cleaned)
                        }
                    }

                    // 解析收集到的周次components
                    if !weekComponents.isEmpty {
                        weeks = parseWeeks(from: weekComponents.joined(separator: " "))
                    }

                    location = locationParts.joined(separator: " ")

                    // 按分段索引提取教师；不存在则留空，避免错误复用第一段教师
                    let teacherSource = index < teacherParts.count ? teacherParts[index] : ""
                    let teacher = teacherSource.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",，")))

                    let course = ParsedCourse(
                        name: name,
                        teacher: teacher,
                        location: location,
                        weeks: weeks,
                        dayOfWeek: dayIndex + 1,
                        timeSlot: timeIndex + 1
                    )

                    courses.append(course)
                }
            }
        }

        return courses
    }

    /// 解析周次字符串
    /// - Parameter weekString: 周次字符串,如 "1-16周"
    /// - Returns: 周次数组
    private static func parseWeeks(from weekString: String) -> [Int] {
        var weeks: [Int] = []
        // 规范化：去除“周”、中文标点与空白
        var cleaned = weekString.replacingOccurrences(of: "周", with: "")
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: ",，;:。"))

        // 处理单周/双周标识
        let isOdd = cleaned.contains("单")
        let isEven = cleaned.contains("双")
        cleaned = cleaned.replacingOccurrences(of: "单", with: "")
        cleaned = cleaned.replacingOccurrences(of: "双", with: "")
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // 提取仅含数字、连字符和逗号的部分
        let rangeStr = cleaned.replacingOccurrences(of: "[^0-9\\-,]", with: "", options: .regularExpression)

        if rangeStr.isEmpty {
            return []
        }

        // 处理逗号分隔的多段周次，如 "2-8,11-14" 或 "2-8,11-11"
        let segments = rangeStr.split(separator: ",").map(String.init)

        for segment in segments {
            if segment.contains("-") {
                let parts = segment.split(separator: "-").compactMap { Int($0) }
                if parts.count == 2 {
                    let start = parts[0]
                    let end = parts[1]
                    for week in start...end {
                        if isOdd && week % 2 == 1 {
                            if !weeks.contains(week) {
                                weeks.append(week)
                            }
                        } else if isEven && week % 2 == 0 {
                            if !weeks.contains(week) {
                                weeks.append(week)
                            }
                        } else if !isOdd && !isEven {
                            if !weeks.contains(week) {
                                weeks.append(week)
                            }
                        }
                    }
                }
            } else if let week = Int(segment) {
                // 单个周次
                if isOdd && week % 2 == 1 {
                    if !weeks.contains(week) {
                        weeks.append(week)
                    }
                } else if isEven && week % 2 == 0 {
                    if !weeks.contains(week) {
                        weeks.append(week)
                    }
                } else if !isOdd && !isEven {
                    if !weeks.contains(week) {
                        weeks.append(week)
                    }
                }
            }
        }

        return weeks.sorted()
    }
}
