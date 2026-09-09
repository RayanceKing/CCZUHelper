//
//  TrainingPlan.swift
//  CCZUKit
//
//  Created by rayanceking on 2025/12/12.
//

import Foundation

/// 培养方案课程条目（来自接口原始字段）
public struct RawTrainingPlanItem: Codable {
    public let nj: Int?            // 年级
    public let zydm: String?       // 专业代码
    public let xz: String?         // 学制（年）
    public let xq: Int             // 学期
    public let kcdm: String        // 课程代码
    public let kcmc: String        // 课程名称（含空格填充）
    public let lbdh: String        // 类别代号（A1/B1/B2/C1/C3/S等）
    public let xf: Double          // 学分
    public let lbmc: String        // 类别名称（中文）
    public let xh: String?         // 学号
    public let kscj: Double?       // 成绩
    public let lb: String?         // 类别（必修/专业任选/实践环节）
    public let zymc: String?       // 专业名称
}

/// 课程类型归类（UI视图需要的三类 + 实践）
public enum PlanCourseType: String, Codable {
    case required    // 必修（对应 A1/B1/C1）
    case elective    // 选修（对应 C3 及其他任选）
    case practice    // 实践（对应 S）
}

/// 计划课程（用于App展示）
public struct PlanCourse: Codable, Identifiable {
    public let id: String
    public let name: String
    public let code: String
    public let credits: Double
    public let type: PlanCourseType
    public let teacher: String?
}

/// 培养方案聚合模型
public struct TrainingPlan: Codable {
    public let majorName: String
    public let degree: String
    public let durationYears: Int
    public let totalCredits: Double
    public let requiredCredits: Double
    public let electiveCredits: Double
    public let practiceCredits: Double
    public let objectives: String?
    public let coursesBySemester: [Int: [PlanCourse]]
}

/// 培养方案解析器
public enum TrainingPlanParser {
    /// 从接口原始 JSON 解析并聚合为 TrainingPlan
    /// - Parameter data: 原始响应数据（包含 `{"status":0,"message":[...]}`）
    /// - Returns: 聚合后的培养方案
    public static func parse(from data: Data, basicInfo: StudentBasicInfo? = nil) throws -> TrainingPlan {
        // 1) 如果返回的是错误消息（字符串）
        struct ErrorRoot: Codable { let status: Int; let message: String }
        if let errorRoot = try? JSONDecoder().decode(ErrorRoot.self, from: data) {
            if errorRoot.status != 0 { throw CCZUError.unknown(errorRoot.message) }
        }

        // 2) 优先尝试标准结构：message 为数组
        struct RootArray: Codable { let status: Int; let message: [RawTrainingPlanItem] }
        if let root = try? JSONDecoder().decode(RootArray.self, from: data) {
            return aggregate(items: root.message, basicInfo: basicInfo)
        }

        // 3) 宽解析：message 为对象或数组但字段名/类型不完全匹配
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        if let dict = json as? [String: Any] {
            let status = dict["status"] as? Int ?? 0
            if status != 0, let msg = dict["message"] as? String {
                throw CCZUError.unknown(msg)
            }
            if let arr = dict["message"] as? [Any] {
                var items: [RawTrainingPlanItem] = []
                for el in arr {
                    if let e = el as? [String: Any] {
                        let nj = e["nj"] as? Int
                        let zydm = e["zydm"] as? String
                        let xzStr = e["xz"] as? String
                        let xq = (e["xq"] as? Int) ?? Int((e["xq"] as? String) ?? "0") ?? 0
                        let kcdm = (e["kcdm"] as? String) ?? ""
                        let kcmc = (e["kcmc"] as? String) ?? ""
                        let lbdh = (e["lbdh"] as? String) ?? (e["lb"] as? String) ?? ""
                        let xf = (e["xf"] as? Double) ?? Double((e["xf"] as? String) ?? "0") ?? 0
                        let lbmc = (e["lbmc"] as? String) ?? (e["lb"] as? String) ?? ""
                        let xh = e["xh"] as? String
                        let kscj = e["kscj"] as? Double
                        let lb = e["lb"] as? String
                        let zymc = e["zymc"] as? String

                        let item = RawTrainingPlanItem(
                            nj: nj,
                            zydm: zydm,
                            xz: xzStr,
                            xq: xq,
                            kcdm: kcdm,
                            kcmc: kcmc,
                            lbdh: lbdh,
                            xf: xf,
                            lbmc: lbmc,
                            xh: xh,
                            kscj: kscj,
                            lb: lb,
                            zymc: zymc
                        )
                        items.append(item)
                    }
                }
                return aggregate(items: items, basicInfo: basicInfo)
            }
        }

        // 4) 回退：顶层为数组
        if let arr = json as? [[String: Any]] {
            var items: [RawTrainingPlanItem] = []
            for e in arr {
                let xq = (e["xq"] as? Int) ?? Int((e["xq"] as? String) ?? "0") ?? 0
                let kcdm = (e["kcdm"] as? String) ?? ""
                let kcmc = (e["kcmc"] as? String) ?? ""
                let lbdh = (e["lbdh"] as? String) ?? (e["lb"] as? String) ?? ""
                let xf = (e["xf"] as? Double) ?? Double((e["xf"] as? String) ?? "0") ?? 0
                let lbmc = (e["lbmc"] as? String) ?? (e["lb"] as? String) ?? ""
                let zymc = e["zymc"] as? String
                let item = RawTrainingPlanItem(nj: e["nj"] as? Int, zydm: e["zydm"] as? String, xz: e["xz"] as? String, xq: xq, kcdm: kcdm, kcmc: kcmc, lbdh: lbdh, xf: xf, lbmc: lbmc, xh: e["xh"] as? String, kscj: e["kscj"] as? Double, lb: e["lb"] as? String, zymc: zymc)
                items.append(item)
            }
            return aggregate(items: items, basicInfo: basicInfo)
        }

        throw CCZUError.unknown("Unexpected training plan response format")
    }

    private static func aggregate(items: [RawTrainingPlanItem], basicInfo: StudentBasicInfo?) -> TrainingPlan {
        let majorName = basicInfo?.major.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? items.first?.zymc?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""
        let durationYears = Int(basicInfo?.studyLength ?? items.first?.xz ?? "0") ?? 0

        var coursesBySemester: [Int: [PlanCourse]] = [:]
        var requiredCredits = 0.0
        var electiveCredits = 0.0
        var practiceCredits = 0.0
        var totalCredits = 0.0

        for item in items {
            let code = item.kcdm
            let name = item.kcmc.trimmingCharacters(in: .whitespacesAndNewlines)
            let credits = item.xf
            let semester = item.xq
            totalCredits += credits

            let type: PlanCourseType
            switch item.lbdh.trimmingCharacters(in: .whitespaces) {
            case "A1", "B1", "C1":
                type = .required
                requiredCredits += credits
            case let s where s.uppercased().hasPrefix("S"):
                type = .practice
                practiceCredits += credits
            default:
                type = .elective
                electiveCredits += credits
            }

            let course = PlanCourse(
                id: code,
                name: name,
                code: code,
                credits: credits,
                type: type,
                teacher: nil
            )
            coursesBySemester[semester, default: []].append(course)
        }

        return TrainingPlan(
            majorName: majorName,
            degree: "",
            durationYears: durationYears,
            totalCredits: totalCredits,
            requiredCredits: requiredCredits,
            electiveCredits: electiveCredits,
            practiceCredits: practiceCredits,
            objectives: nil,
            coursesBySemester: coursesBySemester
        )
    }
}
