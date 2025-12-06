//
//  CourseEvaluationDataTest.swift
//  CCZUHelperTests
//
//  Created by rayanceking on 2025/12/6.
//

import XCTest
@testable import CCZUHelper
import CCZUKit

/// 测试课程评价数据获取和重复问题
final class CourseEvaluationDataTest: XCTestCase {
    
    /// 测试从API获取可评价课程数据
    func testFetchEvaluatableClasses() async throws {
        // 注意：需要设置真实的测试账号才能运行此测试
        let username = ProcessInfo.processInfo.environment["TEST_USERNAME"] ?? ""
        let password = ProcessInfo.processInfo.environment["TEST_PASSWORD"] ?? ""
        
        guard !username.isEmpty && !password.isEmpty else {
            throw XCTSkip("Skipping test: TEST_USERNAME and TEST_PASSWORD environment variables are required")
        }
        
        print("\n=== 开始测试课程评价数据获取 ===")
        print("用户名: \(username)")
        
        // 创建客户端并登录
        let client = DefaultHTTPClient(username: username, password: password)
        _ = try await client.ssoUniversalLogin()
        
        let app = JwqywxApplication(client: client)
        _ = try await app.login()
        
        // 获取可评价课程列表
        print("\n--- 获取可评价课程列表 ---")
        let evaluatableClasses = try await app.getCurrentEvaluatableClasses()
        
        print("总共获取到 \(evaluatableClasses.count) 条课程记录")
        
        // 检查数据重复问题
        print("\n--- 检查数据重复问题 ---")
        
        // 1. 按课程ID检查重复
        let classIds = evaluatableClasses.map { $0.classId }
        let uniqueClassIds = Set(classIds)
        print("课程ID (classId) 总数: \(classIds.count)")
        print("课程ID (classId) 去重后: \(uniqueClassIds.count)")
        
        if classIds.count != uniqueClassIds.count {
            print("⚠️ 发现课程ID重复！")
            let duplicateIds = Dictionary(grouping: classIds, by: { $0 })
                .filter { $0.value.count > 1 }
            print("重复的课程ID: \(duplicateIds.keys.joined(separator: ", "))")
        } else {
            print("✓ 课程ID无重复")
        }
        
        // 2. 按课程代码+教师代码检查重复
        let courseTeacherPairs = evaluatableClasses.map { "\($0.courseCode)_\($0.teacherCode)" }
        let uniqueCourseTeacherPairs = Set(courseTeacherPairs)
        print("\n课程代码+教师代码组合总数: \(courseTeacherPairs.count)")
        print("课程代码+教师代码组合去重后: \(uniqueCourseTeacherPairs.count)")
        
        if courseTeacherPairs.count != uniqueCourseTeacherPairs.count {
            print("⚠️ 发现课程代码+教师代码组合重复！")
            let duplicatePairs = Dictionary(grouping: courseTeacherPairs, by: { $0 })
                .filter { $0.value.count > 1 }
            print("重复的组合: \(duplicatePairs.keys.joined(separator: ", "))")
            
            // 打印重复课程的详细信息
            for pair in duplicatePairs.keys {
                let duplicateCourses = evaluatableClasses.filter {
                    "\($0.courseCode)_\($0.teacherCode)" == pair
                }
                print("\n重复课程详情 [\(pair)]:")
                for (index, course) in duplicateCourses.enumerated() {
                    print("  第\(index + 1)条:")
                    print("    课程ID: \(course.classId)")
                    print("    课程名称: \(course.courseName)")
                    print("    教师姓名: \(course.teacherName)")
                    print("    课程序号: \(course.courseSerial)")
                    print("    类别代号: \(course.categoryCode)")
                    print("    评价ID: \(course.evaluationId)")
                    print("    评价状态: \(course.evaluationStatus ?? "nil")")
                }
            }
        } else {
            print("✓ 课程代码+教师代码组合无重复")
        }
        
        // 3. 按课程名称+教师名称检查重复
        let courseNameTeacherPairs = evaluatableClasses.map { "\($0.courseName)_\($0.teacherName)" }
        let uniqueCourseNameTeacherPairs = Set(courseNameTeacherPairs)
        print("\n课程名称+教师名称组合总数: \(courseNameTeacherPairs.count)")
        print("课程名称+教师名称组合去重后: \(uniqueCourseNameTeacherPairs.count)")
        
        if courseNameTeacherPairs.count != uniqueCourseNameTeacherPairs.count {
            print("⚠️ 发现课程名称+教师名称组合重复！")
            let duplicatePairs = Dictionary(grouping: courseNameTeacherPairs, by: { $0 })
                .filter { $0.value.count > 1 }
            print("重复的组合: \(duplicatePairs.keys.joined(separator: ", "))")
        } else {
            print("✓ 课程名称+教师名称组合无重复")
        }
        
        // 4. 打印所有课程的基本信息
        print("\n--- 所有课程列表 ---")
        for (index, course) in evaluatableClasses.enumerated() {
            print("\n第\(index + 1)条:")
            print("  课程ID: \(course.classId)")
            print("  课程代码: \(course.courseCode)")
            print("  课程名称: \(course.courseName)")
            print("  教师代码: \(course.teacherCode)")
            print("  教师姓名: \(course.teacherName)")
            print("  课程序号: \(course.courseSerial)")
            print("  类别代号: \(course.categoryCode)")
            print("  评价ID: \(course.evaluationId)")
            print("  教师ID: \(course.teacherId)")
            print("  评价状态: \(course.evaluationStatus ?? "nil")")
        }
        
        // 5. 获取已提交的评价列表
        print("\n--- 获取已提交评价列表 ---")
        do {
            let submittedEvaluations = try await app.getCurrentSubmittedEvaluations()
            print("已提交评价数量: \(submittedEvaluations.count)")
            
            // 检查已提交评价的重复
            let submittedPairs = submittedEvaluations.map { "\($0.courseCode)_\($0.teacherCode)" }
            let uniqueSubmittedPairs = Set(submittedPairs)
            print("已提交评价组合总数: \(submittedPairs.count)")
            print("已提交评价组合去重后: \(uniqueSubmittedPairs.count)")
            
            if submittedPairs.count != uniqueSubmittedPairs.count {
                print("⚠️ 发现已提交评价重复！")
            } else {
                print("✓ 已提交评价无重复")
            }
            
            // 打印已提交评价的详细信息
            print("\n已提交评价列表:")
            for (index, evaluation) in submittedEvaluations.enumerated() {
                print("\n第\(index + 1)条:")
                print("  课程代码: \(evaluation.courseCode)")
                print("  课程名称: \(evaluation.courseName)")
                print("  教师代码: \(evaluation.teacherCode)")
                print("  教师姓名: \(evaluation.teacherName)")
            }
            
            // 检查可评价课程中有多少已经提交
            let alreadyEvaluatedCount = evaluatableClasses.filter { course in
                uniqueSubmittedPairs.contains("\(course.courseCode)_\(course.teacherCode)")
            }.count
            print("\n可评价课程中已提交评价的数量: \(alreadyEvaluatedCount)")
            print("应显示待评价的数量: \(evaluatableClasses.count - alreadyEvaluatedCount)")
            
        } catch {
            print("获取已提交评价失败: \(error)")
        }
        
        print("\n=== 测试完成 ===\n")
    }
    
    /// 测试缓存机制
    func testCacheMechanism() throws {
        print("\n=== 测试缓存机制 ===")
        
        // 创建测试数据
        let testClasses = [
            createTestClass(id: "1", courseCode: "CS101", courseName: "计算机科学", teacherCode: "T001", teacherName: "张老师"),
            createTestClass(id: "2", courseCode: "CS102", courseName: "数据结构", teacherCode: "T002", teacherName: "李老师"),
            createTestClass(id: "1", courseCode: "CS101", courseName: "计算机科学", teacherCode: "T001", teacherName: "张老师"), // 重复
        ]
        
        print("原始数据数量: \(testClasses.count)")
        
        // 测试缓存保存和加载
        let cacheKey = "test_evaluatable_classes"
        let cacheItems = testClasses.map { CachedEvaluatableClass(from: $0) }
        
        do {
            let encoded = try JSONEncoder().encode(cacheItems)
            UserDefaults.standard.set(encoded, forKey: cacheKey)
            print("缓存保存成功")
            
            // 从缓存加载
            if let data = UserDefaults.standard.data(forKey: cacheKey) {
                let loadedItems = try JSONDecoder().decode([CachedEvaluatableClass].self, from: data)
                print("从缓存加载数据数量: \(loadedItems.count)")
                
                // 检查是否有重复
                let classIds = loadedItems.map { $0.classId }
                let uniqueIds = Set(classIds)
                if classIds.count != uniqueIds.count {
                    print("⚠️ 缓存中存在重复数据！")
                } else {
                    print("✓ 缓存中无重复数据")
                }
            }
            
            // 清理测试缓存
            UserDefaults.standard.removeObject(forKey: cacheKey)
            
        } catch {
            XCTFail("缓存测试失败: \(error)")
        }
        
        print("=== 缓存测试完成 ===\n")
    }
    
    // 辅助方法：创建测试课程
    private func createTestClass(
        id: String,
        courseCode: String,
        courseName: String,
        teacherCode: String,
        teacherName: String
    ) -> EvaluatableClass {
        // 使用 JSON 方式创建 EvaluatableClass
        let jsonDict: [String: Any] = [
            "bh": id,
            "kcdm": courseCode,
            "kcmc": courseName,
            "kch": "\(courseCode)-01",
            "lbdh": "01",
            "jsdm": teacherCode,
            "jsmc": teacherName,
            "pjid": 1,
            "jsid": teacherCode
        ]
        
        let jsonData = try! JSONSerialization.data(withJSONObject: jsonDict)
        return try! JSONDecoder().decode(EvaluatableClass.self, from: jsonData)
    }
}
