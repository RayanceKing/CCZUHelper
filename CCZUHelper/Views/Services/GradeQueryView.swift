//
//  GradeQueryView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/1.
//

import SwiftUI
import CCZUKit

/// 成绩查询视图
struct GradeQueryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    
    @State private var grades: [GradeItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedTerm: String = "全部"
    @State private var availableTerms: [String] = ["全部"]
    
    var body: some View {
        NavigationStack {
            VStack {
                // 学期选择器
                if availableTerms.count > 1 {
                    Picker("学期", selection: $selectedTerm) {
                        ForEach(availableTerms, id: \.self) { term in
                            Text(term).tag(term)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding()
                    .onChange(of: selectedTerm) { _, _ in
                        filterGrades()
                    }
                }
                
                if isLoading {
                    ProgressView("加载中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    ContentUnavailableView {
                        Label("加载失败", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("重试") {
                            loadGrades()
                        }
                    }
                } else if grades.isEmpty {
                    ContentUnavailableView {
                        Label("暂无成绩", systemImage: "doc.text")
                    } description: {
                        Text("当前学期还没有成绩记录")
                    }
                } else {
                    List {
                        ForEach(filteredGrades) { grade in
                            GradeRow(grade: grade)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("成绩查询")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear {
                if grades.isEmpty {
                    loadGrades()
                }
            }
        }
    }
    
    private var filteredGrades: [GradeItem] {
        if selectedTerm == "全部" {
            return grades
        }
        return grades.filter { $0.term == selectedTerm }
    }
    
    private func filterGrades() {
        // 触发视图更新
    }
    
    private func loadGrades() {
        guard settings.isLoggedIn else {
            errorMessage = "请先登录"
            return
        }
        
        guard let username = settings.username else {
            errorMessage = "用户信息丢失，请重新登录"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // 使用CCZUKit获取真实成绩
                // 注意: 密码应该安全存储在 Keychain 中
                let client = DefaultHTTPClient(username: username, password: "")
                _ = try await client.ssoUniversalLogin()
                
                let app = JwqywxApplication(client: client)
                _ = try await app.login()
                
                // 获取成绩数据
                let gradesResponse = try await app.getGrades()
                
                await MainActor.run {
                    // 转换为本地数据模型
                    var termSet = Set<String>()
                    grades = gradesResponse.message.map { courseGrade in
                        // 将学期代码转换为可读格式
                        let termCode = "\(courseGrade.term)"
                        termSet.insert(termCode)
                        
                        return GradeItem(
                            courseName: courseGrade.courseName,
                            credit: courseGrade.courseCredits,
                            score: String(format: "%.0f", courseGrade.grade),
                            gradePoint: courseGrade.gradePoints,
                            courseType: courseGrade.courseTypeName,
                            term: termCode
                        )
                    }
                    
                    // 更新可用学期列表
                    availableTerms = ["全部"] + Array(termSet).sorted(by: >)
                    
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "获取成绩失败: \(error.localizedDescription)"
                }
            }
        }
    }
}

/// 成绩项模型
struct GradeItem: Identifiable {
    let id = UUID()
    let courseName: String
    let credit: Double
    let score: String
    let gradePoint: Double
    let courseType: String
    var term: String = ""
}

/// 成绩行视图
struct GradeRow: View {
    let grade: GradeItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(grade.courseName)
                    .font(.headline)
                
                Spacer()
                
                Text(grade.courseType)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
            }
            
            HStack {
                Label("\(grade.credit, specifier: "%.1f")学分", systemImage: "book")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("成绩: \(grade.score)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(scoreColor(for: grade.score))
                
                Text("绩点: \(grade.gradePoint, specifier: "%.1f")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func scoreColor(for score: String) -> Color {
        if let numericScore = Double(score) {
            if numericScore >= 90 { return .green }
            if numericScore >= 80 { return .blue }
            if numericScore >= 70 { return .orange }
            if numericScore >= 60 { return .yellow }
            return .red
        }
        return .primary
    }
}

#Preview {
    GradeQueryView()
        .environment(AppSettings())
}
