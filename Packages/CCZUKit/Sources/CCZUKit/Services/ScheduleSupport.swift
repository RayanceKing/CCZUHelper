// MARK: - 课表行数据

struct CourseScheduleRow: Decodable, Sendable {
    let fields: [String: AnyCodable]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dict = try container.decode([String: AnyCodable].self)
        self.fields = dict
    }

    func toCourses(fallbackTeachersByCourseName: [String: String] = [:]) -> [RawCourse] {
        var courses: [String] = []
        var teachers: [String: String] = [:]

        // 提取课程信息 (kc1-kc7)
        for index in 1...7 {
            let key = "kc\(index)"
            if let courseValue = fields[key], let course = courseValue.stringValue {
                courses.append(course)
            } else {
                courses.append("")
            }
        }

        // 提取教师信息 (kcmc1-kcmc20 和 skjs1-skjs20)
        for index in 1...20 {
            let nameKey = "kcmc\(index)"
            let teacherKey = "skjs\(index)"

            if let nameValue = fields[nameKey], let name = nameValue.stringValue,
               let teacherValue = fields[teacherKey], let teacher = teacherValue.stringValue {
                teachers[name] = teacher
            }
        }

        // 组合课程和教师信息
        return courses.map { course in
            let courseParts = course.split(separator: "/")
            let teacherParts = courseParts.map { part -> String in
                let partText = part.trimmingCharacters(in: .whitespacesAndNewlines)
                let matchedName = matchedCourseName(for: partText, from: teachers.keys)
                if let matchedName, let teacher = teachers[matchedName], !teacher.isEmpty {
                    return teacher
                }
                if let matchedName,
                   let teacher = fallbackTeachersByCourseName[matchedName],
                   !teacher.isEmpty {
                    return teacher
                }
                let normalizedPartText = normalizedCourseName(partText)
                let matchedNormalizedName = matchedCourseName(for: normalizedPartText, from: fallbackTeachersByCourseName.keys)
                if let matchedNormalizedName {
                    return fallbackTeachersByCourseName[matchedNormalizedName] ?? ""
                }
                return ""
            }

            // 保留空字符串占位，确保与课程分段索引对齐，避免后续解析时教师错位
            let teacher = teacherParts.joined(separator: ",/")
            return RawCourse(course: course, teacher: teacher)
        }
    }

    private func normalizedCourseName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "（", with: "(")
            .replacingOccurrences(of: "）", with: ")")
    }

    private func matchedCourseName(for part: String, from names: Dictionary<String, String>.Keys) -> String? {
        let normalizedPart = normalizedCourseName(part)
        return names
            .filter { !($0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            .sorted { $0.count > $1.count }
            .first { candidate in
                let normalizedCandidate = normalizedCourseName(candidate)
                return normalizedPart.hasPrefix(normalizedCandidate)
            }
    }
}

struct CourseTeacherSupplementItem: Decodable, Sendable {
    let courseName: String
    let teacherName: String

    enum CodingKeys: String, CodingKey {
        case courseName = "kcmc"
        case teacherName = "jsmc"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        courseName = try c.decode(String.self, forKey: .courseName).trimmingCharacters(in: .whitespacesAndNewlines)
        teacherName = try c.decode(String.self, forKey: .teacherName).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - AnyCodable辅助类型

enum AnyCodableValue: Sendable {
    case int(Int)
    case double(Double)
    case string(String)
    case bool(Bool)
    case null
}

struct AnyCodable: Decodable, Sendable {
    let value: AnyCodableValue

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            value = .int(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            value = .double(doubleValue)
        } else if let stringValue = try? container.decode(String.self) {
            value = .string(stringValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            value = .bool(boolValue)
        } else if container.decodeNil() {
            value = .null
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }

    var stringValue: String? {
        if case .string(let str) = value {
            return str
        }
        return nil
    }
}
