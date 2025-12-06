//
//  UserBasicInfo.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/5.
//

import Foundation

/// 学生基本信息模型（对应CCZUKit的StudentBasicInfo）
struct UserBasicInfo: Codable {
    let name: String                    // 姓名
    let studentNumber: String           // 学号
    let gender: String                  // 性别
    let birthday: String                // 出生日期
    let collegeName: String             // 学院名称
    let major: String                   // 专业名称
    let className: String               // 班级
    let grade: Int                      // 年级
    let studyLength: String             // 学制
    let studentStatus: String           // 学籍情况
    let campus: String                  // 校区名称
    let phone: String                   // 手机号
    let dormitoryNumber: String         // 宿舍编号
    let majorCode: String               // 专业代码
    let classCode: String               // 班级号
    let studentId: String               // 学生ID
    let genderCode: String              // 性别代码
}
