//
//  CourseEvaluationView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/6.
//

import SwiftUI
import CCZUKit

/// 课程评价视图
struct CourseEvaluationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    
    @State private var evaluatableClasses: [EvaluatableClass] = []
    @State private var evaluatedCourseIds: Set<String> = []  // 已评价的课程集合
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedClass: EvaluatableClass?
    @State private var showEvaluationForm = false
    @State private var showSuccessAnimation = false
    @State private var showSystemClosedAlert = false
    
    let monitor = TeachingSystemMonitor.shared
    
    /// 根据当前用户生成特定的缓存键
    private var cacheKey: String {
        "cachedEvaluatableClasses_\(settings.username ?? "anonymous")"
    }
    
    /// 根据当前用户生成已评价课程缓存键
    private var evaluatedCacheKey: String {
        "cachedEvaluatedCourses_\(settings.username ?? "anonymous")"
    }
    
    /// 待评价课程列表
    private var pendingCourses: [EvaluatableClass] {
        evaluatableClasses.filter { course in
            let identifier = "\(course.courseCode)_\(course.teacherCode)"
            return !evaluatedCourseIds.contains(identifier)
        }
    }
    
    /// 已评价课程列表
    private var evaluatedCourses: [EvaluatableClass] {
        evaluatableClasses.filter { course in
            let identifier = "\(course.courseCode)_\(course.teacherCode)"
            return evaluatedCourseIds.contains(identifier)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    ProgressView("loading".localized)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    ContentUnavailableView {
                        Label("evaluation.loading_failed".localized, systemImage: "exclamationmark.triangle.fill")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("retry".localized) {
                            Task {
                                await refreshDataFromNetwork(showLoadingIndicator: true)
                            }
                        }
                    }
                } else if evaluatableClasses.isEmpty {
                    // 真的没有任何课程数据
                    ContentUnavailableView {
                        Label("evaluation.no_courses".localized, systemImage: "list.bullet.clipboard")
                    } description: {
                        Text("evaluation.no_courses_desc".localized)
                    }
                } else if pendingCourses.isEmpty && !evaluatedCourses.isEmpty {
                    // 所有课程都已评价，显示已评价列表
                    List {
                        Section {
                            ForEach(evaluatedCourses.indices, id: \.self) { index in
                                let courseClass = evaluatedCourses[index]
                                EvaluationCourseRow(
                                    courseClass: courseClass,
                                    isEvaluated: true,
                                    onSelect: {
                                        selectedClass = courseClass
                                        showEvaluationForm = true
                                    }
                                )
                            }
                        } header: {
                            HStack {
                                Text("evaluation.evaluated_courses".localized)
                                Spacer()
                                Text("\(evaluatedCourses.count)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                } else {
                    // 有待评价或混合状态
                    List {
                        // 待评价课程列表
                        if !pendingCourses.isEmpty {
                            Section {
                                ForEach(pendingCourses.indices, id: \.self) { index in
                                    let courseClass = pendingCourses[index]
                                    EvaluationCourseRow(
                                        courseClass: courseClass,
                                        isEvaluated: false,
                                        onSelect: {
                                            selectedClass = courseClass
                                            showEvaluationForm = true
                                        }
                                    )
                                }
                            } header: {
                                HStack {
                                    Text("evaluation.pending_courses".localized)
                                    Spacer()
                                    Text("\(pendingCourses.count)")
                                        .foregroundStyle(.orange)
                                        .fontWeight(.semibold)
                                }
                            }
                            
                            // 已评价课程列表
                            if !evaluatedCourses.isEmpty {
                                Section {
                                    ForEach(evaluatedCourses.indices, id: \.self) { index in
                                        let courseClass = evaluatedCourses[index]
                                        EvaluationCourseRow(
                                            courseClass: courseClass,
                                            isEvaluated: true,
                                            onSelect: {
                                                selectedClass = courseClass
                                                showEvaluationForm = true
                                            }
                                        )
                                    }
                                } header: {
                                    HStack {
                                        Text("evaluation.evaluated_courses".localized)
                                        Spacer()
                                        Text("\(evaluatedCourses.count)")
                                            .foregroundStyle(.green)
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("evaluation.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) {
                TeachingSystemStatusBanner()
            }
            .overlay {
                if showSuccessAnimation {
                    SuccessCheckmarkView()
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .alert("teaching_system.unavailable_title".localized, isPresented: $showSystemClosedAlert) {
                Button("ok".localized, role: .cancel) { }
            } message: {
                Text(monitor.unavailableReason)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("close".localized) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            Task {
                                await refreshDataFromNetwork(showLoadingIndicator: true)
                            }
                        }) {
                            Label("evaluation.refresh".localized, systemImage: "arrow.clockwise")
                        }
                        Button(action: {
                            Task {
                                await evaluateAll()
                            }
                        }) {
                            Label("evaluation.evaluate_all".localized, systemImage: "checkmark.circle")
                        }
                        .disabled(pendingCourses.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showEvaluationForm) {
                if let selectedClass = selectedClass {
                    EvaluationFormView(
                        courseClass: selectedClass,
                        settings: settings,
                        onComplete: {
                            showEvaluationForm = false
                            
                            // 立即将该课程标记为已评价
                            let identifier = "\(selectedClass.courseCode)_\(selectedClass.teacherCode)"
                            evaluatedCourseIds.insert(identifier)
                            saveEvaluatedToCache(ids: evaluatedCourseIds)
                            
                            Task {
                                // 静默刷新，不显示加载指示器
                                await refreshDataFromNetwork(showLoadingIndicator: false)
                            }
                        }
                    )
                }
            }
        }
        .onAppear {
            // 1. 尝试立即从缓存加载
            if let cachedClasses = loadFromCache() {
                self.evaluatableClasses = cachedClasses
            }
            if let cachedEvaluatedIds = loadEvaluatedFromCache() {
                self.evaluatedCourseIds = cachedEvaluatedIds
            }
            
            // 2. 确定是否需要初始加载指示器
            let shouldShowLoadingUI = self.evaluatableClasses.isEmpty
            
            // 3. 静默启动网络刷新（或如果缓存为空，则带UI）
            Task {
                await refreshDataFromNetwork(showLoadingIndicator: shouldShowLoadingUI)
            }
        }
    }
    
    // MARK: - 私有方法
    
    private func refreshDataFromNetwork(showLoadingIndicator: Bool) async {
        // 检查教务系统状态
        monitor.checkSystemStatus()
        if !monitor.isSystemAvailable {
            await MainActor.run {
                showSystemClosedAlert = true
                isLoading = false
            }
            return
        }
        
        if showLoadingIndicator {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let fetchedClasses = try await fetchEvaluatableClasses()
            let evaluatedIds = try await fetchEvaluatedCourseIds()
            
            // 调试信息：检查数据重复
            print("\n=== 课程评价数据调试信息 ===")
            print("获取到的课程数量: \(fetchedClasses.count)")
            
            // 检查课程ID重复
            let classIds = fetchedClasses.map { $0.classId }
            let uniqueClassIds = Set(classIds)
            print("课程ID总数: \(classIds.count), 去重后: \(uniqueClassIds.count)")
            if classIds.count != uniqueClassIds.count {
                print("⚠️ 发现课程ID重复！")
                let duplicates = Dictionary(grouping: classIds, by: { $0 }).filter { $0.value.count > 1 }
                for (id, occurrences) in duplicates {
                    print("  ID '\(id)' 出现 \(occurrences.count) 次")
                }
            }
            
            // 检查课程代码+教师代码组合重复
            let courseTeacherPairs = fetchedClasses.map { "\($0.courseCode)_\($0.teacherCode)" }
            let uniquePairs = Set(courseTeacherPairs)
            print("课程+教师组合总数: \(courseTeacherPairs.count), 去重后: \(uniquePairs.count)")
            if courseTeacherPairs.count != uniquePairs.count {
                print("⚠️ 发现课程+教师组合重复！")
                let duplicates = Dictionary(grouping: courseTeacherPairs, by: { $0 }).filter { $0.value.count > 1 }
                for (pair, occurrences) in duplicates {
                    print("  组合 '\(pair)' 出现 \(occurrences.count) 次")
                    // 打印重复课程的详细信息
                    let duplicateCourses = fetchedClasses.filter { "\($0.courseCode)_\($0.teacherCode)" == pair }
                    for (index, course) in duplicateCourses.enumerated() {
                        print("    [\(index + 1)] ID:\(course.classId), 名称:\(course.courseName), 教师:\(course.teacherName), 评价ID:\(course.evaluationId)")
                    }
                }
            }
            
            print("已评价课程ID数量: \(evaluatedIds.count)")
            
            // 打印所有课程的详细信息
            print("\n--- 所有课程详细信息 ---")
            for (index, course) in fetchedClasses.enumerated() {
                print("[\(index + 1)] \(course.courseName) - \(course.teacherName)")
                print("    课程ID: \(course.classId)")
                print("    课程代码: \(course.courseCode)")
                print("    教师代码: \(course.teacherCode)")
                print("    课程序号: \(course.courseSerial)")
                print("    类别代号: \(course.categoryCode)")
                print("    评价ID: \(course.evaluationId)")
                print("    教师ID: \(course.teacherId)")
                print("    评价状态: \(course.evaluationStatus ?? "nil")")
                print("    唯一标识: \(course.courseCode)_\(course.teacherCode)")
                print("")
            }
            
            // 去重处理：使用课程代码+教师代码作为唯一标识
            // 保持原始顺序，使用 reduce 而不是 Dictionary(grouping:)
            var seenIdentifiers = Set<String>()
            let deduplicatedClasses = fetchedClasses.filter { evalClass in
                let identifier = "\(evalClass.courseCode)_\(evalClass.teacherCode)"
                if seenIdentifiers.contains(identifier) {
                    return false
                } else {
                    seenIdentifiers.insert(identifier)
                    return true
                }
            }
            
            if fetchedClasses.count != deduplicatedClasses.count {
                print("⚠️ 已进行去重处理")
                print("去重前数量: \(fetchedClasses.count), 去重后数量: \(deduplicatedClasses.count)")
            }
            
            print("=== 调试信息结束 ===\n")
            
            await MainActor.run {
                // 智能更新逻辑：
                // 1. 如果获取到新数据（即使为空），更新 evaluatableClasses
                // 2. 如果获取到的数据为空，但本地有数据，保留本地数据以显示已评价列表
                if !deduplicatedClasses.isEmpty || self.evaluatableClasses.isEmpty {
                    // 有新数据或本地也没数据，直接更新
                    self.evaluatableClasses = deduplicatedClasses
                } else {
                    // 新数据为空但本地有数据，保留本地数据
                    print("⚠️ 后端返回空列表，保留本地数据以显示已评价课程")
                }
                
                // 总是更新已评价ID列表
                self.evaluatedCourseIds = evaluatedIds
                
                // 保存到缓存
                if !deduplicatedClasses.isEmpty {
                    saveToCache(classes: deduplicatedClasses)
                }
                saveEvaluatedToCache(ids: evaluatedIds)
                
                self.errorMessage = nil // Clear any previous error on successful refresh
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                if self.evaluatableClasses.isEmpty { // Only show error if no data (cached or fresh) is available
                    if let ccError = error as? CCZUError {
                        switch ccError {
                        case .notLoggedIn:
                            self.errorMessage = "evaluation.error.please_login".localized
                        case .invalidCredentials:
                            self.errorMessage = "evaluation.error.credentials_missing".localized
                        default:
                            self.errorMessage = "evaluation.error.fetch_failed".localized(with: error.localizedDescription)
                        }
                    } else {
                        self.errorMessage = error.localizedDescription
                    }
                } else {
                    // If we have cached data, don't show a full-screen error for silent refresh, just log.
                    print("Silent refresh failed: \(error.localizedDescription)")
                    // Optionally, you could set a small, unobtrusive banner error here.
                }
                self.isLoading = false
            }
        }
    }
    
    private func fetchEvaluatableClasses() async throws -> [EvaluatableClass] {
        guard let username = settings.username else {
            throw NSError(domain: "EduPal", code: -1, userInfo: [NSLocalizedDescriptionKey: "evaluation.error.please_login".localized])
        }
        
        guard let password = KeychainHelper.read(service: "cn.czumc.edu", account: username) else {
            throw NSError(domain: "EduPal", code: -1, userInfo: [NSLocalizedDescriptionKey: "evaluation.error.credentials_missing".localized])
        }
        
        let client = DefaultHTTPClient(username: username, password: password)
        _ = try await client.ssoUniversalLogin()
        
        let app = JwqywxApplication(client: client)
        _ = try await app.login()
        
        return try await app.getCurrentEvaluatableClasses()
    }
    
    /// 获取已提交评价的课程ID集合
    private func fetchEvaluatedCourseIds() async throws -> Set<String> {
        guard let username = settings.username else {
            throw NSError(domain: "EduPal", code: -1, userInfo: [NSLocalizedDescriptionKey: "evaluation.error.please_login".localized])
        }
        
        guard let password = KeychainHelper.read(service: KeychainServices.localKeychain, account: username) else {
            throw NSError(domain: "EduPal", code: -1, userInfo: [NSLocalizedDescriptionKey: "evaluation.error.credentials_missing".localized])
        }
        
        let client = DefaultHTTPClient(username: username, password: password)
        _ = try await client.ssoUniversalLogin()
        
        let app = JwqywxApplication(client: client)
        _ = try await app.login()
        
        // 获取已提交的评价列表
        do {
            let submittedEvaluations = try await app.getCurrentSubmittedEvaluations()
            
            // 调试信息：检查已提交评价数据
            print("\n=== 已提交评价数据调试信息 ===")
            print("已提交评价数量: \(submittedEvaluations.count)")
            
            // 检查已提交评价的重复
            let submittedPairs = submittedEvaluations.map { "\($0.courseCode)_\($0.teacherCode)" }
            let uniqueSubmittedPairs = Set(submittedPairs)
            print("已提交评价组合总数: \(submittedPairs.count), 去重后: \(uniqueSubmittedPairs.count)")
            
            if submittedPairs.count != uniqueSubmittedPairs.count {
                print("⚠️ 发现已提交评价重复！")
                let duplicates = Dictionary(grouping: submittedPairs, by: { $0 }).filter { $0.value.count > 1 }
                for (pair, occurrences) in duplicates {
                    print("  组合 '\(pair)' 出现 \(occurrences.count) 次")
                }
            }
            
            // 打印已提交评价列表
            for (index, evaluation) in submittedEvaluations.enumerated() {
                print("[\(index + 1)] \(evaluation.courseName) - \(evaluation.teacherName) (\(evaluation.courseCode)_\(evaluation.teacherCode))")
            }
            print("=== 已提交评价调试信息结束 ===\n")
            
            // 构建已评价课程代码的集合（使用课程代码唯一标识）
            // 如果需要更精确的标识，可以组合 courseCode 和 teacherCode
            return Set(submittedEvaluations.map { "\($0.courseCode)_\($0.teacherCode)" })
        } catch {
            // 如果获取已提交评价失败，返回空集合，继续显示可评价课程
            print("Failed to fetch submitted evaluations: \(error)")
            return Set()
        }
    }
    
    private func evaluateAll() async {
        isLoading = true
        errorMessage = nil // Clear error before starting new action
        
        do {
            guard let username = settings.username else {
                throw NSError(domain: "EduPal", code: -1, userInfo: [NSLocalizedDescriptionKey: "evaluation.error.please_login".localized])
            }
            
            guard let password = KeychainHelper.read(service: KeychainServices.localKeychain, account: username) else {
                throw NSError(domain: "EduPal", code: -1, userInfo: [NSLocalizedDescriptionKey: "evaluation.error.credentials_missing".localized])
            }
            
            let client = DefaultHTTPClient(username: username, password: password)
            _ = try await client.ssoUniversalLogin()
            
            let app = JwqywxApplication(client: client)
            _ = try await app.login()
            
            let terms = try await app.getTerms()
            guard let currentTerm = terms.message.first?.term else {
                throw NSError(domain: "EduPal", code: -1, userInfo: [NSLocalizedDescriptionKey: "evaluation.error.fetch_failed".localized(with: "No term found")])
            }
            
            // 使用默认评分: 总分90，各项分数 [100,80,100,80,100,80]
            // 只评价待评价的课程
            for courseClass in pendingCourses {
                try await app.submitTeacherEvaluation(
                    term: currentTerm,
                    evaluatableClass: courseClass,
                    overallScore: 90,
                    scores: [100, 80, 100, 80, 100, 80],
                    comments: "evaluation.default_comment".localized
                )
                
                // 立即将该课程标记为已评价
                await MainActor.run {
                    let identifier = "\(courseClass.courseCode)_\(courseClass.teacherCode)"
                    self.evaluatedCourseIds.insert(identifier)
                }
            }
            
            await MainActor.run {
                // 保存更新后的已评价课程ID
                saveEvaluatedToCache(ids: self.evaluatedCourseIds)
                
                self.isLoading = false
                
                // 显示成功动画和震动反馈
                #if os(iOS) // Changed from canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                #endif
                
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    self.showSuccessAnimation = true
                }
                
                // 2秒后隐藏动画并静默刷新数据（不显示加载指示器）
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    await MainActor.run {
                        withAnimation {
                            self.showSuccessAnimation = false
                        }
                    }
                    // 静默刷新，保留现有数据，只更新已评价状态
                    await refreshDataFromNetwork(showLoadingIndicator: false)
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func saveToCache(classes: [EvaluatableClass]) {
        // 将 EvaluatableClass 转换为可缓存的模型
        let cacheItems = classes.map { course in
            CachedEvaluatableClass(from: course)
        }
        
        do {
            let encoded = try JSONEncoder().encode(cacheItems)
            UserDefaults.standard.set(encoded, forKey: cacheKey)
        } catch {
            print("Failed to cache evaluatable classes: \(error)")
        }
    }
    
    private func loadFromCache() -> [EvaluatableClass]? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else {
            return nil
        }
        
        do {
            let cacheItems = try JSONDecoder().decode([CachedEvaluatableClass].self, from: data)
            // 直接转换缓存模型到 EvaluatableClass
            return cacheItems.compactMap { item in
                // 重新构建原始格式以匹配 EvaluatableClass 的 CodingKeys
                let jsonDict = item.toDictionary()
                
                if let jsonData = try? JSONSerialization.data(withJSONObject: jsonDict),
                   let decoded = try? JSONDecoder().decode(EvaluatableClass.self, from: jsonData) {
                    return decoded
                }
                
                return nil
            }
        } catch {
            print("Failed to load cache: \(error)")
            return nil
        }
    }
    
    /// 保存已评价课程ID集合到缓存
    private func saveEvaluatedToCache(ids: Set<String>) {
        do {
            let encoded = try JSONEncoder().encode(Array(ids))
            UserDefaults.standard.set(encoded, forKey: evaluatedCacheKey)
        } catch {
            print("Failed to cache evaluated courses: \(error)")
        }
    }
    
    /// 从缓存加载已评价课程ID集合
    private func loadEvaluatedFromCache() -> Set<String>? {
        guard let data = UserDefaults.standard.data(forKey: evaluatedCacheKey) else {
            return nil
        }
        
        do {
            let ids = try JSONDecoder().decode([String].self, from: data)
            return Set(ids)
        } catch {
            print("Failed to load evaluated courses cache: \(error)")
            return nil
        }
    }
}

/// 课程评价表单视图
struct EvaluationFormView: View {
    @Environment(\.dismiss) private var dismiss
    let courseClass: EvaluatableClass
    let settings: AppSettings
    let onComplete: () -> Void
    
    @State private var overallScore: Double = 90
    @State private var teaching: Double = 100
    @State private var attitude: Double = 80
    @State private var content: Double = 100
    @State private var materials: Double = 80
    @State private var interaction: Double = 100
    @State private var feedback: Double = 80
    @State private var comments = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(courseClass.courseName)
                        .font(.headline)
                    Text(courseClass.teacherName)
                        .foregroundStyle(.secondary)
                }
                
                Section("evaluation.overall_score".localized) {
                    HStack {
                        Text("\(Int(overallScore))")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Slider(value: $overallScore, in: 0...100, step: 1)
                    }
                }
                
                Section("evaluation.scoring_items".localized) {
                    EvaluationScoreRow(label: "evaluation.teaching".localized, value: $teaching)
                    EvaluationScoreRow(label: "evaluation.attitude".localized, value: $attitude)
                    EvaluationScoreRow(label: "evaluation.content".localized, value: $content)
                    EvaluationScoreRow(label: "evaluation.materials".localized, value: $materials)
                    EvaluationScoreRow(label: "evaluation.interaction".localized, value: $interaction)
                    EvaluationScoreRow(label: "evaluation.feedback".localized, value: $feedback)
                }
                
                Section("evaluation.comments".localized) {
                    TextEditor(text: $comments)
                        .frame(height: 100)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
                
                Section {
                    Button(action: {
                        Task {
                            await submitEvaluation()
                        }
                    }) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                            }
                            Text("evaluation.submit".localized)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.white)
                    }
                    .disabled(isSubmitting)
                    .listRowBackground(Color.blue)
                }
            }
            .navigationTitle("evaluation.form_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }
            }
        }
    }
    
    private func submitEvaluation() async {
        isSubmitting = true
        errorMessage = nil
        
        do {
            guard let username = settings.username else {
                throw NSError(domain: "EduPal", code: -1, userInfo: [NSLocalizedDescriptionKey: "evaluation.error.please_login".localized])
            }
            
            guard let password = KeychainHelper.read(service: KeychainServices.localKeychain, account: username) else {
                throw NSError(domain: "EduPal", code: -1, userInfo: [NSLocalizedDescriptionKey: "evaluation.error.credentials_missing".localized])
            }
            
            let client = DefaultHTTPClient(username: username, password: password)
            _ = try await client.ssoUniversalLogin()
            
            let app = JwqywxApplication(client: client)
            _ = try await app.login()
            
            let terms = try await app.getTerms()
            guard let currentTerm = terms.message.first?.term else {
                throw NSError(domain: "EduPal", code: -1, userInfo: [NSLocalizedDescriptionKey: "evaluation.error.fetch_failed".localized(with: "No term found")])
            }
            
            let scores = [
                Int(teaching),
                Int(attitude),
                Int(content),
                Int(materials),
                Int(interaction),
                Int(feedback)
            ]
            
            try await app.submitTeacherEvaluation(
                term: currentTerm,
                evaluatableClass: courseClass,
                overallScore: Int(overallScore),
                scores: scores,
                comments: comments.isEmpty ? "evaluation.default_comment".localized : comments
            )
            
            await MainActor.run {
                isSubmitting = false
                onComplete()
                dismiss()
            }
        } catch {
            await MainActor.run {
                if let ccError = error as? CCZUError {
                    switch ccError {
                    case .notLoggedIn:
                        errorMessage = "evaluation.error.please_login".localized
                    case .invalidCredentials:
                        errorMessage = "evaluation.error.credentials_missing".localized
                    default:
                        errorMessage = "evaluation.error.submit_failed".localized(with: error.localizedDescription)
                    }
                } else {
                    errorMessage = error.localizedDescription
                }
                isSubmitting = false
            }
        }
    }
}

/// 评分项行视图
struct EvaluationScoreRow: View {
    let label: String
    @Binding var value: Double
    
    var body: some View {
        HStack {
            Text(label)
                .frame(width: 80, alignment: .leading)
            Text("\(Int(value))")
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(width: 30, alignment: .center)
            Slider(value: $value, in: 0...100, step: 1)
        }
    }
}

// MARK: - Custom Vertical Alignment for Icon Centering

extension VerticalAlignment {
    private enum IconCenterAlignment: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            // Default to center if no specific alignment guide is provided
            context[VerticalAlignment.center]
        }
    }
    static let iconCenter = VerticalAlignment(IconCenterAlignment.self)
}

/// 课程行视图
struct EvaluationCourseRow: View {
    let courseClass: EvaluatableClass
    let isEvaluated: Bool  // 是否已评价
    let onSelect: (() -> Void)?  // 可选的选择回调
    
    var statusColor: Color {
        isEvaluated ? .green : .orange
    }
    
    var statusIcon: String {
        isEvaluated ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
    }
    
    var statusText: String {
        isEvaluated ? "已评价" : "待评价"
    }
    
    var body: some View {
        Group {
            if let onSelect = onSelect {
                Button(action: onSelect) {
                    rowContent
                }
                .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
    }
    
    @ViewBuilder
    private var rowContent: some View {
        HStack(alignment: .iconCenter) {
            VStack(alignment: .leading, spacing: 4) {
                Text(courseClass.courseName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(courseClass.teacherName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .alignmentGuide(.iconCenter) { d in d[VerticalAlignment.center] }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                    .alignmentGuide(.iconCenter) { d in d[VerticalAlignment.center] }
                
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }
        }
        .padding(.vertical, 8)
    }
}

/// 可缓存的课程评价信息模型 - 用于本地缓存存储
struct CachedEvaluatableClass: Codable {
    let classId: String
    let courseCode: String
    let courseName: String
    let courseSerial: String
    let categoryCode: String
    let teacherCode: String
    let teacherName: String
    let evaluationStatus: String?
    let evaluationId: Int
    let teacherId: String
    
    /// 从 EvaluatableClass 创建缓存模型
    init(from evaluatableClass: EvaluatableClass) {
        self.classId = evaluatableClass.classId
        self.courseCode = evaluatableClass.courseCode
        self.courseName = evaluatableClass.courseName
        self.courseSerial = evaluatableClass.courseSerial
        self.categoryCode = evaluatableClass.categoryCode
        self.teacherCode = evaluatableClass.teacherCode
        self.teacherName = evaluatableClass.teacherName
        self.evaluationStatus = evaluatableClass.evaluationStatus
        self.evaluationId = evaluatableClass.evaluationId
        self.teacherId = evaluatableClass.teacherId
    }
    
    /// 初始化器（用于 Codable）
    init(
        classId: String,
        courseCode: String,
        courseName: String,
        courseSerial: String,
        categoryCode: String,
        teacherCode: String,
        teacherName: String,
        evaluationStatus: String?,
        evaluationId: Int,
        teacherId: String
    ) {
        self.classId = classId
        self.courseCode = courseCode
        self.courseName = courseName
        self.courseSerial = courseSerial
        self.categoryCode = categoryCode
        self.teacherCode = teacherCode
        self.teacherName = teacherName
        self.evaluationStatus = evaluationStatus
        self.evaluationId = evaluationId
        self.teacherId = teacherId
    }
    
    /// 转换为 EvaluatableClass 格式的字典（用于 JSON 解码）
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "bh": classId,
            "kcdm": courseCode,
            "kcmc": courseName,
            "kch": courseSerial,
            "lbdh": categoryCode,
            "jsdm": teacherCode,
            "jsmc": teacherName,
            "pjid": evaluationId,
            "jsid": teacherId
        ]
        if let status = evaluationStatus {
            dict["pjqk"] = status
        }
        return dict
    }
}

/// 成功打勾动画视图
struct SuccessCheckmarkView: View {
    @State private var animateCheckmark = false
    
    var body: some View {
        VStack(spacing: 20) {
            // 圆形背景
            ZStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 100, height: 100)
                    .scaleEffect(animateCheckmark ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: animateCheckmark)
                
                // 打勾图标
                Image(systemName: "checkmark")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundStyle(.white)
                    .scaleEffect(animateCheckmark ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1), value: animateCheckmark)
            }
            
            // 成功文字
            Text("evaluation.success".localized)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .opacity(animateCheckmark ? 1 : 0)
                .animation(.easeIn(duration: 0.3).delay(0.2), value: animateCheckmark)
        }
        .onAppear {
            animateCheckmark = true
        }
    }
}

#Preview {
    CourseEvaluationView()
        .environment(AppSettings())
}

