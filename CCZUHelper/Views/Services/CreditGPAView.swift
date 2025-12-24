//
//  CreditGPAView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/1.
//

import SwiftUI
import CCZUKit

#if canImport(UIKit)
import UIKit
#endif

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
                    ProgressView("loading".localized)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    ContentUnavailableView {
                        Label("gpa.loading_failed".localized, systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("retry".localized) {
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
                        Label("gpa.no_data".localized, systemImage: "chart.bar")
                    } description: {
                        Text("gpa.no_info".localized)
                    }
                }
            }
            .navigationTitle("gpa.title".localized)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("close".localized) { dismiss() }
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
                    errorMessage = settings.isLoggedIn ? "gpa.error.user_info_missing".localized : "gpa.error.please_login".localized
                }
                isLoading = false
            }
            return
        }
        
        do {
            // 使用15秒超时来获取学分绩点
            let pointsResponse = try await withTimeout(seconds: 15.0) {
                // 从 Keychain 读取密码
                guard let password = await KeychainHelper.read(service: KeychainServices.localKeychain, account: username) else {
                    throw NetworkError.credentialsMissing
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
                    errorMessage = "gpa.error.no_info".localized
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                // 仅当没有缓存数据时，才将网络错误显示为页面错误
                if studentPoint == nil {
                    // 触发错误震动
                    triggerErrorHaptic()
                    
                    let errorDesc = error.localizedDescription.lowercased()
                    if errorDesc.contains("authentication") || errorDesc.contains("认证") {
                        errorMessage = "error.authentication_failed".localized
                    } else if errorDesc.contains("network") || errorDesc.contains("网络") {
                        errorMessage = "error.network_failed".localized
                    } else if errorDesc.contains("timeout") || errorDesc.contains("超时") {
                        errorMessage = "error.timeout".localized
                    } else {
                        errorMessage = "gpa.error.fetch_failed".localized(with: error.localizedDescription)
                    }
                }
                // 如果有缓存数据，则静默失败，用户将继续看到旧数据
            }
        }
    }
    
    /// 触发错误震动反馈
    private func triggerErrorHaptic() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        #endif
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
            Text("gpa.average".localized)
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
                .fill(.background)
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
        if gpa >= 4.0 { return "gpa.level.excellent".localized }
        if gpa >= 3.5 { return "gpa.level.good".localized }
        if gpa >= 3.0 { return "gpa.level.average".localized }
        if gpa >= 2.5 { return "gpa.level.pass".localized }
        if gpa >= 2.0 { return "gpa.level.qualified".localized }
        return "gpa.level.need_effort".localized
    }
}

/// 学生信息卡片视图
struct StudentInfoCard: View {
    let point: StudentPointItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("gpa.student_info".localized)
                .font(.headline)
            
            VStack(spacing: 12) {
                InfoRow(label: "gpa.name".localized, value: point.studentName)
                Divider()
                InfoRow(label: "gpa.student_id".localized, value: point.studentId)
                Divider()
                InfoRow(label: "gpa.class".localized, value: point.className)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.background)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
}

/// 信息行视图
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack { // Changed from ZStack to HStack
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading) // Retain leading alignment for label
            
            Spacer() // This spacer pushes the value to the right
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing) // Align value to the trailing edge
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    CreditGPAView()
        .environment(AppSettings())
}

