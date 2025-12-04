//
//  CreditGPAView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/1.
//

import SwiftUI
import CCZUKit

/// 自定义错误类型，用于处理特定加载错误
private enum GPAError: Error, LocalizedError {
    case credentialsMissing
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .credentialsMissing:
            return "密码丢失，请重新登录"
        case .timeout:
            return "请求超时，教务系统可能无法访问"
        }
    }
}

/// 为异步操作添加超时功能的辅助函数
/// - Parameters:
///   - seconds: 超时秒数
///   - operation: 需要执行的异步操作
/// - Returns: 异步操作的结果
/// - Throws: 如果操作超时或失败，则抛出错误
private func withTimeout<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        // 添加主要任务
        group.addTask {
            return try await operation()
        }
        // 添加超时任务
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw GPAError.timeout
        }
        
        // 等待第一个完成的任务并获取结果
        let result = try await group.next()!
        
        // 取消所有其他任务
        group.cancelAll()
        
        return result
    }
}

/// 学分绩点视图
struct CreditGPAView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    
    @State private var studentPoint: StudentPointItem?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    /// 根据当前用户生成特定的缓存键
    private var cacheKey: String {
        "cachedStudentPoint_\(settings.username ?? "anonymous")"
    }
    
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
                loadCreditGPA()
            }
        }
    }
    
    private func loadCreditGPA() {
        errorMessage = nil
        
        // 1. 优先从缓存加载数据并显示
        if let cachedPoint = loadFromCache() {
            studentPoint = cachedPoint
        } else {
            // 如果没有缓存，则显示加载指示器
            isLoading = true
        }
        
        // 2. 异步从网络获取最新数据以更新
        Task {
            await refreshData()
        }
    }
    
    private func refreshData() async {
        guard settings.isLoggedIn, let username = settings.username else {
            await MainActor.run {
                if self.studentPoint == nil { // 仅在无缓存数据时显示错误
                    errorMessage = settings.isLoggedIn ? "用户信息丢失，请重新登录" : "请先登录"
                }
                isLoading = false
            }
            return
        }
        
        do {
            // 使用15秒超时来获取学分绩点
            let pointsResponse = try await withTimeout(seconds: 15.0) {
                // 从 Keychain 读取密码
                guard let password = await KeychainHelper.read(service: "com.cczu.helper", account: username) else {
                    throw GPAError.credentialsMissing
                }
                
                let client = DefaultHTTPClient(username: username, password: password)
                _ = try await client.ssoUniversalLogin()
                
                let app = JwqywxApplication(client: client)
                _ = try await app.login()
                
                // 获取学分绩点数据
                return try await app.getCreditsAndRank()
            }
            
            await MainActor.run {
                if let point = pointsResponse.message.first {
                    let newPoint = StudentPointItem(
                        className: point.className,
                        studentId: point.studentId,
                        studentName: point.studentName,
                        gradePoints: point.gradePoints
                    )
                    studentPoint = newPoint
                    saveToCache(point: newPoint) // 更新缓存
                } else if studentPoint == nil {
                    // 如果网络请求成功但没有数据，并且没有缓存，则显示提示
                    errorMessage = "未查询到学分绩点信息"
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                // 仅当没有缓存数据时，才将网络错误显示为页面错误
                if studentPoint == nil {
                    errorMessage = "获取学分绩点失败: \(error.localizedDescription)"
                }
                // 如果有缓存数据，则静默失败，用户将继续看到旧数据
            }
        }
    }
    
    // MARK: - Caching
    
    private func saveToCache(point: StudentPointItem) {
        if let encoded = try? JSONEncoder().encode(point) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
        }
    }
    
    private func loadFromCache() -> StudentPointItem? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let decoded = try? JSONDecoder().decode(StudentPointItem.self, from: data) else {
            return nil
        }
        return decoded
    }
}

/// 学生绩点信息模型 - 遵循 Codable 以便缓存
struct StudentPointItem: Codable {
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
