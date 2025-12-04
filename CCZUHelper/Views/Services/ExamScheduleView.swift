//
//  ExamScheduleView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/1.
//

import SwiftUI
import CCZUKit

/// 考试安排视图
struct ExamScheduleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    
    @State private var allExams: [ExamItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showScheduledOnly = false
    
    /// 根据当前用户生成特定的缓存键
    private var cacheKey: String {
        "cachedExams_\(settings.username ?? "anonymous")"
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    ProgressView("loading".localized)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    ContentUnavailableView {
                        Label("exam.loading_failed".localized, systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("retry".localized) {
                            loadExams()
                        }
                    }
                } else {
                    examListView
                }
            }
            .navigationTitle("exam.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("close".localized) { dismiss() }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await refreshData()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
            .onAppear {
                if allExams.isEmpty {
                    loadExams()
                }
            }
        }
    }
    
    private var examListView: some View {
        List {
            // 筛选器部分
            Section {
                Toggle("exam.show_scheduled_only".localized, isOn: $showScheduledOnly)
            }
            
            // 统计信息
            Section {
                HStack {
                    Label("exam.total_count".localized, systemImage: "doc.text")
                    Spacer()
                    Text("\(allExams.count)")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Label("exam.scheduled_count".localized, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Spacer()
                    Text("\(scheduledExams.count)")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Label("exam.unscheduled_count".localized, systemImage: "clock")
                        .foregroundStyle(.orange)
                    Spacer()
                    Text("\(unscheduledExams.count)")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("exam.statistics".localized)
            }
            
            // 考试列表
            Section {
                if filteredExams.isEmpty {
                    // 当筛选后没有数据时，保持页面结构，仅在列表内提示
                    HStack {
                        Spacer()
                        Text(showScheduledOnly ? "exam.no_scheduled".localized : "exam.no_exams".localized)
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                        Spacer()
                    }
                } else {
                    ForEach(filteredExams) { exam in
                        ExamRow(exam: exam)
                    }
                }
            } header: {
                Text("exam.list".localized)
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private var filteredExams: [ExamItem] {
        if showScheduledOnly {
            return scheduledExams
        }
        return allExams
    }
    
    private var scheduledExams: [ExamItem] {
        allExams.filter { $0.isScheduled }
    }
    
    private var unscheduledExams: [ExamItem] {
        allExams.filter { !$0.isScheduled }
    }
    
    private func loadExams() {
        errorMessage = nil
        
        // 1. 优先从缓存加载数据并显示
        if let cachedExams = loadFromCache() {
            self.allExams = cachedExams
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
                if self.allExams.isEmpty {
                    errorMessage = settings.isLoggedIn ? "exam.error.user_info_missing".localized : "exam.error.please_login".localized
                }
                isLoading = false
            }
            return
        }
        
        do {
            // 使用15秒超时来获取考试安排
            let examArrangements = try await withTimeout(seconds: 15.0) {
                // 从 Keychain 读取密码
                guard let password = await KeychainHelper.read(service: "com.cczu.helper", account: username) else {
                    throw NetworkError.credentialsMissing
                }
                
                let client = DefaultHTTPClient(username: username, password: password)
                _ = try await client.ssoUniversalLogin()
                
                let app = JwqywxApplication(client: client)
                _ = try await app.login()
                
                // 获取考试安排数据
                return try await app.getExamArrangements()
            }
            
            await MainActor.run {
                // 转换为本地数据模型
                let newExams = examArrangements.map { arrangement in
                    ExamItem(
                        courseName: arrangement.courseName,
                        examTime: arrangement.examTime,
                        examLocation: arrangement.examLocation,
                        examType: arrangement.examType,
                        studyType: arrangement.studyType,
                        className: arrangement.className,
                        week: arrangement.week,
                        startSlot: arrangement.startSlot,
                        endSlot: arrangement.endSlot,
                        campus: arrangement.campus,
                        remark: arrangement.remark
                    )
                }
                
                self.allExams = newExams
                saveToCache(exams: newExams) // 更新缓存
                
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                // 仅当没有缓存数据时，才将网络错误显示为页面错误
                if self.allExams.isEmpty {
                    errorMessage = "exam.error.fetch_failed".localized(with: error.localizedDescription)
                }
                // 如果有缓存数据，则静默失败，用户将继续看到旧数据
            }
        }
    }
    
    // MARK: - Caching
    
    private func saveToCache(exams: [ExamItem]) {
        if let encoded = try? JSONEncoder().encode(exams) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
        }
    }
    
    private func loadFromCache() -> [ExamItem]? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let decoded = try? JSONDecoder().decode([ExamItem].self, from: data) else {
            return nil
        }
        return decoded
    }
}

/// 考试项模型 - 遵循 Codable 以便缓存
struct ExamItem: Identifiable, Codable {
    let id: UUID
    let courseName: String
    let examTime: String?
    let examLocation: String?
    let examType: String
    let studyType: String
    let className: String
    let week: Int?
    let startSlot: Int?
    let endSlot: Int?
    let campus: String
    let remark: String?
    
    var isScheduled: Bool {
        examTime != nil && examLocation != nil
    }
    
    // 自定义 Codable 实现，id 在解码时生成新值
    enum CodingKeys: String, CodingKey {
        case courseName, examTime, examLocation, examType, studyType
        case className, week, startSlot, endSlot, campus, remark
    }
    
    init(courseName: String, examTime: String?, examLocation: String?, 
         examType: String, studyType: String, className: String,
         week: Int?, startSlot: Int?, endSlot: Int?, campus: String, remark: String?) {
        self.id = UUID()
        self.courseName = courseName
        self.examTime = examTime
        self.examLocation = examLocation
        self.examType = examType
        self.studyType = studyType
        self.className = className
        self.week = week
        self.startSlot = startSlot
        self.endSlot = endSlot
        self.campus = campus
        self.remark = remark
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.courseName = try container.decode(String.self, forKey: .courseName)
        self.examTime = try container.decodeIfPresent(String.self, forKey: .examTime)
        self.examLocation = try container.decodeIfPresent(String.self, forKey: .examLocation)
        self.examType = try container.decode(String.self, forKey: .examType)
        self.studyType = try container.decode(String.self, forKey: .studyType)
        self.className = try container.decode(String.self, forKey: .className)
        self.week = try container.decodeIfPresent(Int.self, forKey: .week)
        self.startSlot = try container.decodeIfPresent(Int.self, forKey: .startSlot)
        self.endSlot = try container.decodeIfPresent(Int.self, forKey: .endSlot)
        self.campus = try container.decode(String.self, forKey: .campus)
        self.remark = try container.decodeIfPresent(String.self, forKey: .remark)
    }
}

/// 考试行视图
struct ExamRow: View {
    let exam: ExamItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 课程名称和状态
            HStack {
                Text(exam.courseName)
                    .font(.headline)
                
                Spacer()
                
                if exam.isScheduled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(.orange)
                }
            }
            
            // 考试信息
            if let examTime = exam.examTime {
                Label(examTime, systemImage: "calendar.badge.clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            if let examLocation = exam.examLocation {
                Label(examLocation, systemImage: "mappin.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // 其他信息
            HStack(spacing: 16) {
                if let week = exam.week, let startSlot = exam.startSlot, let endSlot = exam.endSlot {
                    Text("exam.week.format".localized(with: week, startSlot, endSlot))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text(exam.examType)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .cornerRadius(4)
            }
            
            // 班级和校区
            HStack {
                Text(exam.className.trimmingCharacters(in: .whitespaces))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(exam.campus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    ExamScheduleView()
        .environment(AppSettings())
}
