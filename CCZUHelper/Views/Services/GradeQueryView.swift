//
//  GradeQueryView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/1.
//

import SwiftUI
import CCZUKit

#if canImport(UIKit)
import UIKit
#endif


/// 成绩查询视图
struct GradeQueryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    
    @State private var allGrades: [GradeItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedTerm: String = ""
    @State private var availableTerms: [String] = []
    
    /// 根据当前用户生成特定的缓存键
    private var cacheKey: String {
        "cachedGrades_\(settings.username ?? "anonymous")"
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // 学期选择器
                if availableTerms.count > 1 {
                    Picker("grade.term".localized, selection: $selectedTerm) {
                        ForEach(availableTerms, id: \.self) { term in
                            Text(term).tag(term)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal)
                    .padding(.top)
                }
                
                if isLoading {
                    ProgressView("loading".localized)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    ContentUnavailableView {
                        Label("grade.loading_failed".localized, systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("retry".localized) {
                            loadGrades()
                        }
                    }
                } else if filteredGrades.isEmpty {
                    let allTermKey = availableTerms.first ?? ""
                    ContentUnavailableView {
                        Label("grade.no_grades".localized, systemImage: "doc.text")
                    } description: {
                        Text(selectedTerm == allTermKey ? "grade.no_grades_all".localized : "grade.no_grades_term".localized)
                    }
                } else {
                    List {
                        ForEach(filteredGrades) { grade in
                            GradeRow(grade: grade)
                        }
                    }
                    #if os(macOS)
                    .listStyle(.inset)
                    #else
                    .listStyle(.insetGrouped)
                    #endif
                }
            }
            .navigationTitle("grade.title".localized)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("close".localized) { dismiss() }
                }
            }
            .onAppear {
                if allGrades.isEmpty {
                    loadGrades()
                }
            }
        }
    }
    
    private var filteredGrades: [GradeItem] {
        // Use the first item in availableTerms (which is the "All" term) for comparison
        let allTermKey = availableTerms.first ?? ""
        if selectedTerm == allTermKey {
            return allGrades
        }
        return allGrades.filter { $0.term == selectedTerm }
    }
    
    private func loadGrades() {
        errorMessage = nil
        
        // 1. 优先从缓存加载数据并显示
        if let cachedGrades = loadFromCache() {
            self.allGrades = cachedGrades
            updateAvailableTerms(from: cachedGrades)
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
                if self.allGrades.isEmpty { // 仅在无缓存数据时显示错误
                    errorMessage = settings.isLoggedIn ? "grade.error.user_info_missing".localized : "grade.error.please_login".localized
                }
                isLoading = false
            }
            return
        }
        
        do {
            // 使用15秒超时来获取成绩
            let gradesResponse = try await withTimeout(seconds: 15.0) {
                // 从 Keychain 读取密码
                guard let password = await KeychainHelper.read(service: "com.cczu.helper", account: username) else {
                    throw NetworkError.credentialsMissing
                }
                
                let client = DefaultHTTPClient(username: username, password: password)
                _ = try await client.ssoUniversalLogin()
                
                let app = JwqywxApplication(client: client)
                _ = try await app.login()
                
                // 获取成绩数据
                return try await app.getGrades()
            }
            
            await MainActor.run {
                // 转换为本地数据模型
                let newGrades = gradesResponse.message.map { courseGrade in
                    GradeItem(
                        courseName: courseGrade.courseName,
                        credit: courseGrade.courseCredits,
                        score: String(format: "%.0f", courseGrade.grade),
                        gradePoint: courseGrade.gradePoints,
                        courseType: courseGrade.courseTypeName,
                        term: "\(courseGrade.term)"
                    )
                }
                
                self.allGrades = newGrades
                updateAvailableTerms(from: newGrades)
                saveToCache(grades: newGrades) // 更新缓存
                
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                // 仅当没有缓存数据时，才将网络错误显示为页面错误
                if self.allGrades.isEmpty {
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
                        errorMessage = "grade.error.fetch_failed".localized(with: error.localizedDescription)
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
    
    private func updateAvailableTerms(from grades: [GradeItem]) {
        let termSet = Set(grades.map { $0.term })
        let allTerm = "all".localized
        self.availableTerms = [allTerm] + Array(termSet).sorted(by: >)
        // Set initial selection if not set
        if selectedTerm.isEmpty {
            selectedTerm = allTerm
        }
    }
    
    // MARK: - Caching
    
    private func saveToCache(grades: [GradeItem]) {
        if let encoded = try? JSONEncoder().encode(grades) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
        }
    }
    
    private func loadFromCache() -> [GradeItem]? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let decoded = try? JSONDecoder().decode([GradeItem].self, from: data) else {
            return nil
        }
        return decoded
    }
}

/// 成绩项模型 - 遵循 Codable 以便缓存
struct GradeItem: Identifiable, Codable {
    let id: UUID
    let courseName: String
    let credit: Double
    let score: String
    let gradePoint: Double
    let courseType: String
    var term: String = ""

    // 自定义 Codable 实现，以确保 id 在解码时生成新的值
    // 这样可以避免 id 持久化带来的潜在问题
    enum CodingKeys: String, CodingKey {
        case courseName, credit, score, gradePoint, courseType, term
    }
    
    init(id: UUID = UUID(), courseName: String, credit: Double, score: String, gradePoint: Double, courseType: String, term: String) {
        self.id = id
        self.courseName = courseName
        self.credit = credit
        self.score = score
        self.gradePoint = gradePoint
        self.courseType = courseType
        self.term = term
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID() // 解码时总是创建一个新的 UUID
        self.courseName = try container.decode(String.self, forKey: .courseName)
        self.credit = try container.decode(Double.self, forKey: .credit)
        self.score = try container.decode(String.self, forKey: .score)
        self.gradePoint = try container.decode(Double.self, forKey: .gradePoint)
        self.courseType = try container.decode(String.self, forKey: .courseType)
        self.term = try container.decode(String.self, forKey: .term)
    }
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
                Label("grade.credit".localized(with: grade.credit), systemImage: "book")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("grade.score".localized(with: grade.score))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(scoreColor(for: grade.score))
                
                Text("grade.gpa".localized(with: grade.gradePoint))
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
        // 对于非数字成绩（如“优秀”、“良好”）返回主色
        return .primary
    }
}

#Preview {
    GradeQueryView()
        .environment(AppSettings())
}
