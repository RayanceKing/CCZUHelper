//
//  ExamScheduleView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/1.
//

import SwiftUI
import CCZUKit

#if canImport(UIKit)
import UIKit
#endif

/// 考试安排视图
struct ExamScheduleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    
    @State private var allExams: [ExamItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showScheduledOnly = false
    
    @State private var editingExam: ExamItem?
    @State private var isPresentingEditor = false
    
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
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
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
            .sheet(isPresented: $isPresentingEditor) {
                if let examToEdit = editingExam {
                    ExamEditView(
                        exam: examToEdit,
                        onSave: { updated in
                            // 更新列表中的该考试
                            if let idx = allExams.firstIndex(where: { $0.id == examToEdit.id }) {
                                allExams[idx] = updated
                                // 更新缓存
                                saveToCache(exams: allExams)
                                // 保存到 App Intents 缓存
                                if let username = settings.username {
                                    AppIntentsDataCache.shared.saveExams(allExams, for: username)
                                }
                                // 重新安排考试通知
                                Task {
                                    await NotificationHelper.scheduleAllExamNotifications(
                                        exams: allExams,
                                        settings: settings
                                    )
                                }
                            }
                            isPresentingEditor = false
                        },
                        onCancel: {
                            isPresentingEditor = false
                        }
                    )
                    .presentationDetents([.medium, .large])
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
                        Button {
                            editingExam = exam
                            isPresentingEditor = true
                        } label: {
                            ExamRow(exam: exam)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                Text("exam.list".localized)
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
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
            // 保存到 App Intents 缓存
            if let username = settings.username {
                AppIntentsDataCache.shared.saveExams(cachedExams, for: username)
            }
            // 为缓存的考试安排通知
            Task {
                await NotificationHelper.scheduleAllExamNotifications(
                    exams: cachedExams,
                    settings: settings
                )
            }
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
        await MainActor.run {
            // 点击右上角刷新按钮时，立刻进入加载状态，确保有明显的刷新反馈
            isLoading = true
            // 清除错误信息，避免加载成功后仍显示旧错误
            errorMessage = nil
        }
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
                guard let password = await KeychainHelper.read(service: KeychainServices.localKeychain, account: username) else {
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
                
                // 合并服务器数据与本地数据：本地被用户修改的优先保留
                let local = self.allExams
                func key(for item: ExamItem) -> String { "\(item.courseName)|\(item.className)|\(item.examType)" }
                let localDict = Dictionary(uniqueKeysWithValues: local.map { (key(for: $0), $0) })
                var merged: [ExamItem] = []
                for server in newExams {
                    let k = key(for: server)
                    if let localItem = localDict[k], localItem.isUserModified {
                        merged.append(localItem)
                    } else {
                        // 用服务器数据，保留本地的 isUserModified=false
                        var s = server
                        s.isUserModified = false
                        merged.append(s)
                    }
                }
                // 追加本地存在但服务器未返回的条目（例如已下架但用户修改过的）
                let serverKeys = Set(newExams.map { key(for: $0) })
                for localItem in local where !serverKeys.contains(key(for: localItem)) {
                    merged.append(localItem)
                }
                self.allExams = merged
                
                saveToCache(exams: self.allExams) // 更新缓存
                
                // 保存考试数据到 App Intents 缓存
                if let username = settings.username {
                    AppIntentsDataCache.shared.saveExams(self.allExams, for: username)
                }
                
                // 安排考试通知
                Task {
                    await NotificationHelper.scheduleAllExamNotifications(
                        exams: self.allExams,
                        settings: settings
                    )
                }
                
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                // 仅当没有缓存数据时，才将网络错误显示为页面错误
                if self.allExams.isEmpty {
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
                        errorMessage = "exam.error.fetch_failed".localized(with: error.localizedDescription)
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
    var id: UUID
    var courseName: String
    var examTime: String?
    var examLocation: String?
    var examType: String
    var studyType: String
    var className: String
    var week: Int?
    var startSlot: Int?
    var endSlot: Int?
    var campus: String
    var remark: String?
    var isUserModified: Bool
    
    var isScheduled: Bool {
        examTime != nil
    }
    
    // 自定义 Codable 实现，id 在解码时生成新值
    enum CodingKeys: String, CodingKey {
        case courseName, examTime, examLocation, examType, studyType
        case className, week, startSlot, endSlot, campus, remark, isUserModified
    }
    
    init(courseName: String, examTime: String?, examLocation: String?, 
         examType: String, studyType: String, className: String,
         week: Int?, startSlot: Int?, endSlot: Int?, campus: String, remark: String?, isUserModified: Bool = false) {
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
        self.isUserModified = isUserModified
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
        self.isUserModified = (try? container.decode(Bool.self, forKey: .isUserModified)) ?? false
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
//                if let week = exam.week, let startSlot = exam.startSlot, let endSlot = exam.endSlot {
//                    Text("exam.week.format".localized(with: week, startSlot, endSlot))
//                        .font(.caption)
//                        .foregroundStyle(.secondary)
//                }
                
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

struct ExamEditView: View {
    @State private var examDate: Date
    @State private var examLocation: String

    let original: ExamItem
    let onSave: (ExamItem) -> Void
    let onCancel: () -> Void

    init(exam: ExamItem, onSave: @escaping (ExamItem) -> Void, onCancel: @escaping () -> Void) {
        let parsed = ExamEditView.parseDate(from: exam.examTime)
        self._examDate = State(initialValue: parsed ?? Date())
        self._examLocation = State(initialValue: exam.examLocation ?? "")
        self.original = exam
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("exam.time".localized)) {
                    DatePicker(
                        "",
                        selection: $examDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                }
                Section(header: Text("exam.location".localized)) {
                    TextField("exam.location.placeholder".localized, text: $examLocation)
                        .textInputAutocapitalization(.words)
                        .font(.body)
                }
            }
            .navigationTitle("exam.edit.title".localized)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("save".localized) {
                        var updated = original
                        updated.examTime = ExamEditView.formatDate(examDate)
                        updated.examLocation = examLocation.isEmpty ? nil : examLocation
                        updated.isUserModified = true
                        onSave(updated)
                    }
                    .disabled(false)
                }
            }
        }
    }
    
    private static func parseDate(from timeString: String?) -> Date? {
        guard let s = timeString, !s.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        // 支持两种形式："yyyy年MM月dd日 HH:mm--HH:mm" 和 "yyyy年MM月dd日 HH:mm"
        if let datePart = s.split(separator: " ").first,
           let timePart = s.split(separator: " ").dropFirst().first {
            let startTime = timePart.split(separator: "--").first ?? Substring("")
            formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
            return formatter.date(from: "\(datePart) \(startTime)")
        }
        return nil
    }

    private static func formatDate(_ date: Date) -> String? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        return formatter.string(from: date)
    }
}


#Preview {
    ExamScheduleView()
        .environment(AppSettings())
}
