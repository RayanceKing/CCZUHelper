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
    
    private let terms = ["全部", "2024-2025学年第一学期", "2023-2024学年第二学期", "2023-2024学年第一学期"]
    
    var body: some View {
        NavigationStack {
            VStack {
                // 学期选择器
                Picker("学期", selection: $selectedTerm) {
                    ForEach(terms, id: \.self) { term in
                        Text(term).tag(term)
                    }
                }
                .pickerStyle(.menu)
                .padding()
                
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
                        ForEach(grades) { grade in
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
    
    private func loadGrades() {
        guard settings.isLoggedIn else {
            errorMessage = "请先登录"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // TODO: 使用CCZUKit获取真实成绩
                // 暂时使用模拟数据
                try await Task.sleep(nanoseconds: 1_000_000_000)
                
                await MainActor.run {
                    grades = [
                        GradeItem(courseName: "高等数学A(1)", credit: 5.0, score: "92", gradePoint: 4.2, courseType: "必修"),
                        GradeItem(courseName: "大学英语(1)", credit: 3.0, score: "85", gradePoint: 3.5, courseType: "必修"),
                        GradeItem(courseName: "程序设计基础", credit: 4.0, score: "88", gradePoint: 3.8, courseType: "必修"),
                        GradeItem(courseName: "线性代数", credit: 3.0, score: "90", gradePoint: 4.0, courseType: "必修"),
                        GradeItem(courseName: "大学物理", credit: 4.0, score: "78", gradePoint: 2.8, courseType: "必修"),
                    ]
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
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
