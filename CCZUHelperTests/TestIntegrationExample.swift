//
//  TestIntegrationExample.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/04.
//
//  这个文件展示了如何在应用中集成测试功能
//  仅供参考，实际开发中请根据需要集成

import SwiftUI

// MARK: - 示例 1: 在 App 启动时运行测试

/*
@main
struct CCZUHelperApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    #if DEBUG
                    // 在调试模式下自动运行快速测试
                    QuickTest.start()
                    #endif
                }
        }
    }
}
*/

// MARK: - 示例 2: 添加调试菜单

struct DebugMenuView: View {
    @State private var showTestResults = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("应用信息") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("调试工具") {
                    Button(action: {
                        QuickTest.start()
                        showTestResults = true
                    }) {
                        Label("运行课程解析测试", systemImage: "play.fill")
                    }
                    
                    NavigationLink(destination: CourseTimeCalculatorPreview()) {
                        Label("详细测试报告", systemImage: "doc.text")
                    }
                }
            }
            .navigationTitle("调试菜单")
        }
    }
}

// MARK: - 示例 3: 在设置页面中添加测试选项

struct SettingsWithDebugView: View {
    @State private var showDebugSection = false
    
    var body: some View {
        List {
            Section("基本设置") {
                // ... 其他设置项
            }
            
            #if DEBUG
            Section("调试选项") {
                Toggle("显示调试工具", isOn: $showDebugSection)
                
                if showDebugSection {
                    Button(action: {
                        print("\n开始运行课程解析测试...\n")
                        CourseTimeCalculatorTests.runAllTests()
                    }) {
                        Label("运行完整测试", systemImage: "play.circle")
                    }
                    
                    Button(action: {
                        print("\n打印课程时间表...\n")
                        CourseTimeCalculatorTests.printClassTimeTable()
                    }) {
                        Label("打印时间表", systemImage: "clock")
                    }
                    
                    Button(action: {
                        print("\n测试时间计算...\n")
                        CourseTimeCalculatorTests.testTimeCalculation()
                    }) {
                        Label("测试时间计算", systemImage: "timer")
                    }
                    
                    Button(action: {
                        print("\n测试课程转换...\n")
                        CourseTimeCalculatorTests.testCourseConversion()
                    }) {
                        Label("测试课程转换", systemImage: "arrow.left.arrow.right")
                    }
                }
            }
            #endif
        }
    }
}

// MARK: - 示例 4: 在 ManageSchedulesView 中集成测试

/*
在 ManageSchedulesView.swift 中的某个适当位置添加：

struct ManageSchedulesView: View {
    // ... 现有代码
    
    #if DEBUG
    @State private var showTestOutput = false
    #endif
    
    var body: some View {
        NavigationStack {
            List {
                // ... 现有列表内容
                
                #if DEBUG
                Section("调试") {
                    Button("测试课程导入") {
                        QuickTest.start()
                        showTestOutput = true
                    }
                    
                    NavigationLink(destination: CourseTimeCalculatorPreview()) {
                        Text("查看完整报告")
                    }
                }
                #endif
            }
        }
    }
}
*/

// MARK: - 示例 5: 单元测试

/*
创建单元测试文件来验证核心功能（如果使用 XCTest）：

import XCTest
@testable import CCZUHelper

class CourseTimeCalculatorTests_XCTest: XCTestCase {
    
    func testTimeHelperInitialization() {
        let helper = CalendarTimeHelper()
        let classTime = helper.getClassTime(for: 3)
        XCTAssertNotNil(classTime)
        XCTAssertEqual(classTime?.slotNumber, 3)
    }
    
    func testCourseGeneration() {
        let calculator = CourseTimeCalculator()
        let mockCourses = CourseTimeCalculatorTests.mockParsedCourses
        let courses = calculator.generateCourses(
            from: mockCourses,
            scheduleId: "test"
        )
        XCTAssertEqual(courses.count, mockCourses.count)
    }
    
    func testTimeRangeCalculation() {
        let calculator = CourseTimeCalculator()
        let range = calculator.getTimeRange(for: 3)
        XCTAssertNotNil(range)
        XCTAssertEqual(range?.start, "09:45")
        XCTAssertEqual(range?.end, "10:25")
    }
}
*/

// MARK: - 示例 6: 在 preview 中显示测试数据

#Preview("调试菜单") {
    DebugMenuView()
}

#Preview("设置页面（带调试选项）") {
    SettingsWithDebugView()
}

#Preview("课程转换测试") {
    CourseTimeCalculatorPreview()
        .environment(AppSettings())
}

// MARK: - 辅助文档

/*
## 如何使用这些测试

### 快速开始
1. 在 Xcode 中打开此文件
2. 取消注释相关示例代码
3. 根据需要集成到你的视图中

### 推荐集成方式
1. 在调试菜单中添加测试按钮
2. 使用 `#if DEBUG` 确保测试代码仅在调试版本中运行
3. 定期运行测试以验证功能

### 查看输出
1. 打开 Xcode 的 Debug Area（View → Debug Area → Show Debug Area）
2. 选择标准输出视图
3. 运行测试并查看输出

### 生产环境
确保在打包发布版本时移除或禁用所有测试代码
*/
