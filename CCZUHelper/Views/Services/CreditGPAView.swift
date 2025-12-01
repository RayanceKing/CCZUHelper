//
//  CreditGPAView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/1.
//

import SwiftUI
import CCZUKit

/// 学分绩点视图
struct CreditGPAView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    
    @State private var studentPoint: StudentPointItem?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            VStack {
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
                            loadCreditGPA()
                        }
                    }
                } else if let point = studentPoint {
                    ScrollView {
                        VStack(spacing: 24) {
                            // 绩点卡片
                            GPACard(gpa: point.gradePoints)
                            
                            // 学生信息卡片
                            StudentInfoCard(point: point)
                        }
                        .padding()
                    }
                } else {
                    ContentUnavailableView {
                        Label("暂无数据", systemImage: "chart.bar")
                    } description: {
                        Text("无法获取学分绩点信息")
                    }
                }
            }
            .navigationTitle("学分绩点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear {
                if studentPoint == nil {
                    loadCreditGPA()
                }
            }
        }
    }
    
    private func loadCreditGPA() {
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
                // 使用CCZUKit获取真实学分绩点
                let client = DefaultHTTPClient(username: username, password: "")
                _ = try await client.ssoUniversalLogin()
                
                let app = JwqywxApplication(client: client)
                _ = try await app.login()
                
                // 获取学分绩点数据
                let pointsResponse = try await app.getCreditsAndRank()
                
                await MainActor.run {
                    if let point = pointsResponse.message.first {
                        studentPoint = StudentPointItem(
                            className: point.className,
                            studentId: point.studentId,
                            studentName: point.studentName,
                            gradePoints: point.gradePoints
                        )
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "获取学分绩点失败: \(error.localizedDescription)"
                }
            }
        }
    }
}

/// 学生绩点信息模型
struct StudentPointItem {
    let className: String
    let studentId: String
    let studentName: String
    let gradePoints: Double
}

/// 绩点卡片视图
struct GPACard: View {
    let gpa: Double
    
    var body: some View {
        VStack(spacing: 12) {
            Text("平均学分绩点")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text(String(format: "%.2f", gpa))
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundStyle(gpaColor)
            
            Text(gpaLevel)
                .font(.headline)
                .foregroundStyle(gpaColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(gpaColor.opacity(0.1))
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
    
    private var gpaColor: Color {
        if gpa >= 4.0 { return .purple }
        if gpa >= 3.5 { return .green }
        if gpa >= 3.0 { return .blue }
        if gpa >= 2.5 { return .orange }
        if gpa >= 2.0 { return .yellow }
        return .red
    }
    
    private var gpaLevel: String {
        if gpa >= 4.0 { return "优秀" }
        if gpa >= 3.5 { return "良好" }
        if gpa >= 3.0 { return "中等" }
        if gpa >= 2.5 { return "及格" }
        if gpa >= 2.0 { return "合格" }
        return "需努力"
    }
}

/// 学生信息卡片视图
struct StudentInfoCard: View {
    let point: StudentPointItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("学生信息")
                .font(.headline)
            
            VStack(spacing: 12) {
                InfoRow(label: "姓名", value: point.studentName)
                Divider()
                InfoRow(label: "学号", value: point.studentId)
                Divider()
                InfoRow(label: "班级", value: point.className)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
}

/// 信息行视图
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    CreditGPAView()
        .environment(AppSettings())
}
