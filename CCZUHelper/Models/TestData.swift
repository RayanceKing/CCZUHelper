//
//  TestData.swift
//  CCZUHelper
//
//  Created by rayanceking on 2026/02/25.
//

import Foundation

/// 测试数据常量和配置
enum TestData {
    // MARK: - 测试账户配置
    /// 测试账户邮箱
    static let testEmail = "test@edupal.czumc.cn"
    
    /// 测试账户用户名
    static let testUsername = "test_user"
    
    // MARK: - 样例学生信息
    static let sampleStudentInfo = UserBasicInfo(
        name: "测试用户",
        studentNumber: "2022001001",
        gender: "男",
        birthday: "2003-01-15",
        collegeName: "计算机学院",
        major: "计算机科学与技术",
        className: "计科2201",
        grade: 2022,
        studyLength: "4",
        studentStatus: "在校",
        campus: "主校区",
        phone: "15912345678",
        dormitoryNumber: "A3-520",
        majorCode: "080901",
        classCode: "CS220001",
        studentId: "0001",
        genderCode: "M"
    )
    
    // MARK: - 样例课程数据
    static let sampleCourses: [String: [[String: Any]]] = [
        "2024-2025-1": [
            // 周一
            [
                "id": "001",
                "name": "数据结构",
                "teacher": "王教授",
                "location": "计算机楼506",
                "timeSlot": 2,
                "duration": 2,
                "dayOfWeek": 1,
                "color": "#FF6B6B"
            ],
            [
                "id": "002",
                "name": "线性代数",
                "teacher": "李老师",
                "location": "理科楼208",
                "timeSlot": 4,
                "duration": 2,
                "dayOfWeek": 1,
                "color": "#4ECDC4"
            ],
            // 周二
            [
                "id": "003",
                "name": "数据库原理",
                "teacher": "张教授",
                "location": "计算机楼602",
                "timeSlot": 1,
                "duration": 2,
                "dayOfWeek": 2,
                "color": "#45B7D1"
            ],
            [
                "id": "004",
                "name": "Web开发",
                "teacher": "陈老师",
                "location": "计算机楼508",
                "timeSlot": 3,
                "duration": 2,
                "dayOfWeek": 2,
                "color": "#FFA07A"
            ],
            // 周三
            [
                "id": "005",
                "name": "人工智能基础",
                "teacher": "刘教授",
                "location": "计算机楼701",
                "timeSlot": 5,
                "duration": 2,
                "dayOfWeek": 3,
                "color": "#98D8C8"
            ],
            // 周四
            [
                "id": "006",
                "name": "操作系统",
                "teacher": "吴老师",
                "location": "计算机楼405",
                "timeSlot": 2,
                "duration": 2,
                "dayOfWeek": 4,
                "color": "#F7DC6F"
            ],
            [
                "id": "007",
                "name": "计算机网络",
                "teacher": "郑教授",
                "location": "计算机楼604",
                "timeSlot": 4,
                "duration": 2,
                "dayOfWeek": 4,
                "color": "#BB8FCE"
            ],
            // 周五
            [
                "id": "008",
                "name": "Java开发",
                "teacher": "孙老师",
                "location": "计算机楼503",
                "timeSlot": 1,
                "duration": 2,
                "dayOfWeek": 5,
                "color": "#85C1E2"
            ],
            [
                "id": "009",
                "name": "算法设计",
                "teacher": "何教授",
                "location": "计算机楼607",
                "timeSlot": 3,
                "duration": 2,
                "dayOfWeek": 5,
                "color": "#F8B195"
            ]
        ]
    ]
    
    /// 检查是否是测试账户（支持邮箱或学号）
    static func isTestAccount(_ input: String) -> Bool {
        let normalizedInput = input.lowercased().trimmingCharacters(in: .whitespaces)
        let isEmail = normalizedInput == testEmail.lowercased()
        let isStudentNumber = normalizedInput == sampleStudentInfo.studentNumber
        
        print("🔍 TestAccount Check:")
        print("  Input: \(input)")
        print("  Normalized: \(normalizedInput)")
        print("  Expected Email: \(testEmail.lowercased())")
        print("  Expected StudentNumber: \(sampleStudentInfo.studentNumber)")
        print("  Is Email Match: \(isEmail)")
        print("  Is Student Number Match: \(isStudentNumber)")
        
        return isEmail || isStudentNumber
    }
}
