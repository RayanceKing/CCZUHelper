//
//  CourseTimeCalculatorPreview.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/04.
//

import SwiftUI

/// 课程时间计算器测试视图
struct CourseTimeCalculatorPreview: View {
    @State private var testOutput = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    Button(action: runTests) {
                        Label("运行测试", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)
                    
                    Button(action: clearOutput) {
                        Label("清空", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading)
                }
                .padding()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if testOutput.isEmpty {
                            VStack(alignment: .center, spacing: 8) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.secondary)
//                                Text("点击"运行测试"查看控制台输出")
//                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        } else {
                            Text(testOutput)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .padding()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
//                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
                .padding()
            }
            .navigationTitle("课程时间计算器测试")
        }
        .onAppear {
            // 自动运行测试
            runTests()
        }
    }
    
    private func runTests() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let output = captureTestOutput {
                CourseTimeCalculatorTests.runAllTests()
            }
            
            DispatchQueue.main.async {
                self.testOutput = output
                self.isLoading = false
            }
        }
    }
    
    private func clearOutput() {
        testOutput = ""
    }
    
    /// 捕获控制台输出
    private func captureTestOutput(block: () -> Void) -> String {
        let pipe = Pipe()
        let oldStdout = dup(STDOUT_FILENO)
        
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        fflush(stdout)
        
        block()
        
        fflush(stdout)
        dup2(oldStdout, STDOUT_FILENO)
        close(oldStdout)
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

#Preview {
    CourseTimeCalculatorPreview()
        .environment(AppSettings())
}
