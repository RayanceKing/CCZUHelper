//
//  CourseSelectionView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/6.
//

import SwiftUI
import CCZUKit

// 文件级帮助函数：判断通识课是否有剩余名额，供本文件内多个视图使用
fileprivate func isGeneralCourseAvailable(_ c: GeneralElectiveCourse) -> Bool {
    return c.availableCount > 0 || c.selectedCount < c.capacity
}

/// 选课系统视图
struct CourseSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    
    // 选修课相关
    @State private var availableCourses: [CourseSelectionItem] = []
    @State private var selectedCourseIds: Set<Int> = []
    @State private var isLoading = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var searchText: String = ""
    @State private var selectedCategory: String = "全部"
    @State private var showDropAllConfirm = false
    @State private var showDropGeneralConfirm = false
    
    // 通识课相关
    @State private var availableGeneralCourses: [GeneralElectiveCourseItem] = []
    @State private var selectedGeneralCourseIds: Set<Int> = []
    @State private var selectedGeneralLearnMode: LearnMode? = nil
    @State private var selectedGeneralCategory: String = ""
    @State private var generalErrorMessage: String?
    @State private var isGeneralLoading = false
    @State private var selectedGeneralFilter: GeneralFilter = .all
    @State private var hasEnteredGeneralOnce = false
    @State private var currentMode: CourseSelectionMode = .elective
    
    enum CourseSelectionMode: String, CaseIterable {
        case elective = "选修课"
        case general = "通识课"
    }
    
    enum LearnMode: String, CaseIterable {
        case online = "线上"
        case offline = "线下"
    }

    enum GeneralFilter: String {
        case all = "全部"
        case available = "可选"
        case selected = "已选"
    }
    
    private var courseCategoryNames: [String] { ["全部", "必修课", "选修课", "通识课", "专业课"] }
    
    // MARK: - Computed Properties
    
    private var filteredCourses: [CourseSelectionItem] {
        var courses = availableCourses

        if selectedCategory != "全部" {
            courses = courses.filter { categoryName(for: $0) == selectedCategory }
        }

        if !searchText.isEmpty {
            courses = courses.filter {
                $0.raw.courseName.localizedCaseInsensitiveContains(searchText) ||
                $0.raw.teacherName.localizedCaseInsensitiveContains(searchText) ||
                $0.raw.courseCode.localizedCaseInsensitiveContains(searchText) ||
                $0.raw.categoryCode.localizedCaseInsensitiveContains(searchText) ||
                $0.raw.courseAttrCode.localizedCaseInsensitiveContains(searchText) ||
                $0.raw.studyType.localizedCaseInsensitiveContains(searchText)
            }
        }

        return courses
    }
    
    // 通识课筛选
    private var filteredGeneralCourses: [GeneralElectiveCourseItem] {
        var courses = availableGeneralCourses
        
        if let mode = selectedGeneralLearnMode {
            courses = courses.filter { $0.learnMode == mode }
        }
        
        if !selectedGeneralCategory.isEmpty {
            courses = courses.filter { $0.raw.categoryName == selectedGeneralCategory }
        }
        
        switch selectedGeneralFilter {
        case .all:
            break
        case .available:
            courses = courses.filter { isGeneralCourseAvailable($0.raw) }
        case .selected:
            courses = courses.filter { selectedGeneralCourseIds.contains($0.courseSerial) }
        }

        if !searchText.isEmpty {
            courses = courses.filter {
                $0.raw.courseName.localizedCaseInsensitiveContains(searchText) ||
                $0.raw.teacherName.localizedCaseInsensitiveContains(searchText) ||
                $0.raw.categoryName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return courses
    }
    
    private var generalCourseCategories: [String] {
        let categories = Set(availableGeneralCourses.map { $0.raw.categoryName })
        return Array(categories).sorted()
    }
    
    private var totalCredits: Double {
        selectedCourseItems.reduce(0) { $0 + $1.raw.credits }
    }

    private var selectedCourseItems: [CourseSelectionItem] {
        availableCourses.filter { selectedCourseIds.contains($0.idn) }
    }

    private var remoteSelectedIds: Set<Int> {
        Set(availableCourses.filter { $0.isRemoteSelected }.map { $0.idn })
    }

    private var hasPendingChanges: Bool {
        remoteSelectedIds != selectedCourseIds
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 模式切换器
                Picker(selection: $currentMode) {
                    ForEach(CourseSelectionMode.allCases, id: \.self) { mode in
                        Text(LocalizedStringKey(mode.rawValue)).tag(mode)
                    }
                } label: {
                    Text("course_selection.mode_picker")
                }
                .pickerStyle(.segmented)
                .padding()
                
                if currentMode == .elective {
                    electiveCourseView()
                } else {
                    generalCourseView()
                }
            }
            .navigationTitle("选课系统")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                // 筛选菜单（全部 / 可选 / 已选） — 放在多功能菜单之前
                ToolbarItem(placement: .navigationBarTrailing) {
                    if currentMode == .general {
                        Menu {
                            Button(action: { selectedGeneralFilter = .all }) {
                                if selectedGeneralFilter == .all {
                                    Label("全部", systemImage: "checkmark")
                                } else {
                                    Text("全部")
                                }
                            }
                            Button(action: { selectedGeneralFilter = .available }) {
                                if selectedGeneralFilter == .available {
                                    Label("可选", systemImage: "checkmark")
                                } else {
                                    Text("可选")
                                }
                            }
                            Button(action: { selectedGeneralFilter = .selected }) {
                                if selectedGeneralFilter == .selected {
                                    Label("已选", systemImage: "checkmark")
                                } else {
                                    Text("已选")
                                }
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease")
                        }
                    }
                }
                // 多功能菜单（刷新/提交/退选等）
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if currentMode == .elective {
                            electiveMenu()
                        } else {
                            generalMenu()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                // 仅在选修模式下显示提交中的进度指示，通识模式不在右上角显示加载状态
                ToolbarItem(placement: .navigationBarTrailing) {
                    if currentMode == .elective && isSubmitting {
                        ProgressView()
                    }
                }
            }
            .alert(Text("course_selection.drop_all_confirm_title"), isPresented: $showDropAllConfirm) {
                Button(role: .destructive) {
                    Task { await dropAllSelectedCourses() }
                } label: {
                    Text("course_selection.drop")
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("course_selection.drop_all_confirm_message")
            }

            .alert(Text("course_selection.general_drop_confirm_title"), isPresented: $showDropGeneralConfirm) {
                Button(role: .destructive) {
                    Task { await dropSelectedGeneralCourses() }
                } label: {
                    Text("course_selection.drop")
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("course_selection.general_drop_confirm_message")
            }
        }
        .onAppear {
            Task {
                if currentMode == .elective && availableCourses.isEmpty {
                    await loadCourses()
                }
                // 如果初次进入通识模式则触发刷新（不依赖右上角进度指示）
                if currentMode == .general && !hasEnteredGeneralOnce {
                    hasEnteredGeneralOnce = true
                    await loadGeneralCourses()
                }
            }
        }
        .onChange(of: currentMode) { _, newMode in
            if newMode == .general && !hasEnteredGeneralOnce {
                hasEnteredGeneralOnce = true
                Task { await loadGeneralCourses() }
            }
        }
    }
    
    // MARK: - View Builders
    
    @ViewBuilder
    private func electiveCourseView() -> some View {
        if isLoading {
            ProgressView {
                Text("common.loading")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = errorMessage {
            ContentUnavailableView {
                Label {
                    Text("course_selection.load_failed")
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
            } description: {
                Text(error)
            } actions: {
                Button {
                    Task {
                        await loadCourses()
                    }
                } label: {
                    Text("common.retry")
                }
            }
        } else {
            VStack(spacing: 0) {
                // 课程列表
                List {
                    if filteredCourses.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else {
                        Section {
                            ForEach(filteredCourses) { course in
                                CourseSelectionRow(
                                    course: course,
                                    isSelected: selectedCourseIds.contains(course.idn),
                                    isRemoteSelected: course.isRemoteSelected,
                                    onToggle: {
                                        toggleCourseSelection(course)
                                    }
                                )
                            }
                        }
                    }
                }
                .refreshable {
                    await loadCourses()
                }
                .searchable(text: $searchText, prompt: Text("course_selection.search_prompt"))
                .disabled(isSubmitting)
            }
        }
    }
    
    @ViewBuilder
    private func generalCourseView() -> some View {
        if isGeneralLoading {
            ProgressView {
                Text("common.loading")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = generalErrorMessage {
            ContentUnavailableView {
                Label {
                    Text("course_selection.general_load_failed")
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
            } description: {
                Text(error)
            } actions: {
                Button {
                    Task {
                        await loadGeneralCourses()
                    }
                } label: {
                    Text("common.retry")
                }
            }
        } else {
            VStack(spacing: 0) {
                // 筛选器
                VStack(spacing: 12) {
                    // 线上/线下筛选
                    VStack(alignment: .leading, spacing: 8) {
                        Text("course_selection.learn_mode_label")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Picker(selection: $selectedGeneralLearnMode) {
                            Text("common.all").tag(Optional<LearnMode>.none)
                            ForEach(LearnMode.allCases, id: \.self) { mode in
                                Text(LocalizedStringKey(mode.rawValue)).tag(Optional(mode))
                            }
                        } label: {
                            Text("course_selection.learn_mode_picker")
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // 类别筛选
                    if !generalCourseCategories.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("course_selection.category_label")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    CategoryButton(
                                        title: NSLocalizedString("common.all", comment: "全部"),
                                        isSelected: selectedGeneralCategory.isEmpty
                                    ) {
                                        selectedGeneralCategory = ""
                                    }

                                    ForEach(generalCourseCategories, id: \.self) { category in
                                        CategoryButton(
                                            title: category,
                                            isSelected: selectedGeneralCategory == category
                                        ) {
                                            selectedGeneralCategory = category
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(uiColor: .systemGroupedBackground))
                
                // 课程列表
                List {
                    if filteredGeneralCourses.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else {
                        Section {
                            ForEach(filteredGeneralCourses) { course in
                                GeneralCourseSelectionRow(
                                    course: course,
                                    isSelected: selectedGeneralCourseIds.contains(course.courseSerial),
                                    isRemoteSelected: false,
                                    onToggle: {
                                        toggleGeneralCourseSelection(course)
                                    }
                                )
                            }
                        }
                    }
                }
                .refreshable {
                    await loadGeneralCourses()
                }
                .searchable(text: $searchText, prompt: Text("course_selection.search_prompt_general"))
                .disabled(isSubmitting)
            }
        }
    }
    
    @ViewBuilder
    private func electiveMenu() -> some View {
        Button(action: {
            Task {
                await loadCourses()
            }
        }) {
            Label {
                Text("common.refresh")
            } icon: {
                Image(systemName: "arrow.clockwise")
            }
        }
        
        Button(action: {
            Task {
                await submitSelection()
            }
        }) {
            Label {
                Text("course_selection.submit")
            } icon: {
                Image(systemName: "checkmark.circle")
            }
        }
        .disabled(!hasPendingChanges || isSubmitting)

        Button(action: {
            selectAll()
        }) {
            Label {
                Text("common.select_all")
            } icon: {
                Image(systemName: "checkmark.circle.badge.plus")
            }
        }
        .disabled(isSubmitting)

        Button(role: .destructive) {
            showDropAllConfirm = true
        } label: {
            Label {
                Text("course_selection.drop_all")
            } icon: {
                Image(systemName: "trash")
            }
        }
        .disabled(remoteSelectedIds.isEmpty || isSubmitting)
    }
    
    @ViewBuilder
    private func generalMenu() -> some View {
        Button(action: {
            Task {
                await loadGeneralCourses()
            }
        }) {
            Label {
                Text("common.refresh")
            } icon: {
                Image(systemName: "arrow.clockwise")
            }
        }
        
        Button(action: {
            Task {
                await submitGeneralSelection()
            }
        }) {
            Label {
                Text("course_selection.submit")
            } icon: {
                Image(systemName: "checkmark.circle")
            }
        }
        .disabled(selectedGeneralCourseIds.isEmpty || isSubmitting)

        Button(role: .destructive) {
            showDropGeneralConfirm = true
        } label: {
            Label {
                Text("course_selection.general_drop")
            } icon: {
                Image(systemName: "trash")
            }
        }
        .disabled(isGeneralLoading || isSubmitting)
    }
    
    // MARK: - Private Methods
    
    private func loadCourses() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let app = try await settings.ensureJwqywxLoggedIn()
            let basicInfo = try await app.getStudentBasicInfo()
            guard let info = basicInfo.message.first else {
                throw CCZUError.missingData(NSLocalizedString("error.missing_student_info", comment: "无法获取学生基本信息"))
            }
            let classCode = info.classCode
            let grade = info.grade
            
            let courses = try await app.getCurrentSelectableCoursesWithPreflight(classCode: classCode, grade: grade)
            let items = courses.map { CourseSelectionItem(raw: $0) }

            await MainActor.run {
                availableCourses = items
                selectedCourseIds = Set(items.filter { $0.isRemoteSelected }.map { $0.idn })
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func loadGeneralCourses() async {
        await MainActor.run {
            isGeneralLoading = true
            generalErrorMessage = nil
        }

        do {
            let app = try await settings.ensureJwqywxLoggedIn()
            let basicInfo = try await app.getStudentBasicInfo()
            guard let info = basicInfo.message.first else {
                throw CCZUError.missingData("无法获取学生基本信息")
            }
            
            // 优先使用教务提供的通识选课批次（可能为预选/正式批次）以取得准确的学期
            var term: String
            if let batch = try await app.getGeneralElectiveSelectionBatch(grade: info.grade) {
                term = batch.term
            } else {
                let terms = try await app.getTerms()
                guard let t = terms.message.first?.term else { throw CCZUError.missingData("无法获取学期信息") }
                term = t
            }

            let courses = try await app.getGeneralElectiveCourses(
                term: term,
                classCode: info.classCode,
                grade: info.grade,
                campus: info.campus
            )

            let items = courses.map { GeneralElectiveCourseItem(raw: $0) }

            // 同步获取当前已选的通识类课程，以便 "已选" 筛选生效
            var selectedCourseSerials: Set<Int> = []
            do {
                let selected = try await app.getSelectedGeneralElectiveCourses(term: term)
                selectedCourseSerials = Set(selected.map { $0.courseSerial })
            } catch {
                // 忽略已选拉取错误，但记录日志
                if app.enableDebugLogging {
                    print("[WARN] 获取已选通识课程失败: \(error)")
                }
            }

            await MainActor.run {
                availableGeneralCourses = items
                selectedGeneralCourseIds = selectedCourseSerials
                isGeneralLoading = false
                // 打印调试信息：可用通识课程与已选信息
                print("[DEBUG] availableGeneralCourses count: \(items.count)")
                print("[DEBUG] selectedGeneralCourseIds: \(selectedCourseSerials)")
                let selectedDetails = items.filter { selectedCourseSerials.contains($0.courseSerial) }.map { "\($0.courseSerial): \($0.raw.courseName)" }
                print("[DEBUG] selected general courses: \(selectedDetails)")
            }
        } catch {
            await MainActor.run {
                isGeneralLoading = false
                generalErrorMessage = error.localizedDescription
            }
        }
    }

    private func toggleCourseSelection(_ course: CourseSelectionItem) {
        if selectedCourseIds.contains(course.idn) {
            selectedCourseIds.remove(course.idn)
        } else {
            selectedCourseIds.insert(course.idn)
        }

        #if !os(visionOS) && canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
    
    private func toggleGeneralCourseSelection(_ course: GeneralElectiveCourseItem) {
        if selectedGeneralCourseIds.contains(course.courseSerial) {
            selectedGeneralCourseIds.remove(course.courseSerial)
        } else {
                if selectedGeneralCourseIds.count < 2 {
                selectedGeneralCourseIds.insert(course.courseSerial)
            } else {
                generalErrorMessage = NSLocalizedString("general.max_two_error", comment: "通识课最多只能选择2门")
            }
        }

        #if !os(visionOS) && canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
    
    private func selectAll() {
        let allIds = Set(filteredCourses.map { $0.idn })
        selectedCourseIds.formUnion(allIds)
        #if !os(visionOS) && canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }

    private func submitSelection() async {
        guard !isSubmitting else { return }
        await MainActor.run { isSubmitting = true }
        defer { Task { @MainActor in isSubmitting = false } }

        do {
            let app = try await settings.ensureJwqywxLoggedIn()

            let toSelect = availableCourses.filter { selectedCourseIds.contains($0.idn) && !$0.isRemoteSelected }
            let toDropIds = availableCourses
                .filter { !selectedCourseIds.contains($0.idn) && $0.isRemoteSelected }
                .compactMap { $0.raw.selectedId > 0 ? $0.raw.selectedId : nil }

            if !toSelect.isEmpty {
                let term = toSelect.first?.raw.term ?? ""
                guard !term.isEmpty else {
                    throw CCZUError.missingData(NSLocalizedString("error.missing_term", comment: "无法获取选课学期"))
                }
                try await app.selectCourses(term: term, items: toSelect.map { $0.raw })
            }

            if !toDropIds.isEmpty {
                _ = try await app.dropCourses(selectedIds: toDropIds)
            }

            await loadCourses()

            #if !os(visionOS) && canImport(UIKit)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            #endif
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
            #if !os(visionOS) && canImport(UIKit)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            #endif
        }
    }
    
    private func submitGeneralSelection() async {
        guard !isSubmitting else { return }
        await MainActor.run { isSubmitting = true }
        defer { Task { @MainActor in isSubmitting = false } }

        do {
            let app = try await settings.ensureJwqywxLoggedIn()
            let basicInfo = try await app.getStudentBasicInfo()
            guard let info = basicInfo.message.first else { throw CCZUError.missingData("无法获取学生基本信息") }

            let coursesToSelect = availableGeneralCourses.filter { 
                selectedGeneralCourseIds.contains($0.courseSerial)
            }
            
            guard !coursesToSelect.isEmpty else {
                throw CCZUError.missingData(NSLocalizedString("course_selection.please_select", comment: "请先选择课程"))
            }
            
            // 提交时同样优先使用通识选课批次
            let term: String
            if let batch = try await app.getGeneralElectiveSelectionBatch(grade: info.grade) {
                term = batch.term
            } else {
                let terms = try await app.getTerms()
                guard let t = terms.message.first?.term else { throw CCZUError.missingData(NSLocalizedString("error.missing_term", comment: "无法获取选课学期")) }
                term = t
            }

            try await app.selectGeneralElectiveCourses(
                term: term,
                courses: coursesToSelect.map { $0.raw }
            )
            
            await loadGeneralCourses()

            #if !os(visionOS) && canImport(UIKit)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            #endif
        } catch {
            await MainActor.run {
                generalErrorMessage = error.localizedDescription
            }
            #if !os(visionOS) && canImport(UIKit)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            #endif
        }
    }

    private func dropAllSelectedCourses() async {
        guard !isSubmitting else { return }
        await MainActor.run { isSubmitting = true }
        defer { Task { @MainActor in isSubmitting = false } }

        do {
            let app = try await settings.ensureJwqywxLoggedIn()
            let ids = availableCourses
                .filter { $0.isRemoteSelected }
                .compactMap { $0.raw.selectedId > 0 ? $0.raw.selectedId : nil }
            guard !ids.isEmpty else { return }
            _ = try await app.dropCourses(selectedIds: ids)
            await loadCourses()
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func dropSelectedGeneralCourses() async {
        guard !isSubmitting else { return }
        await MainActor.run { isSubmitting = true }
        defer { Task { @MainActor in isSubmitting = false } }

        do {
            let app = try await settings.ensureJwqywxLoggedIn()
            let basicInfo = try await app.getStudentBasicInfo()
            guard let info = basicInfo.message.first else { throw CCZUError.missingData("无法获取学生基本信息") }

            // 优先使用通识选课批次以获取准确学期
            let term: String
            if let batch = try await app.getGeneralElectiveSelectionBatch(grade: info.grade) {
                term = batch.term
            } else {
                let terms = try await app.getTerms()
                guard let t = terms.message.first?.term else { throw CCZUError.missingData("无法获取学生学期信息") }
                term = t
            }

            // 获取当前已选的通识类课程
            let selected = try await app.getSelectedGeneralElectiveCourses(term: term)
            guard !selected.isEmpty else {
                await MainActor.run { generalErrorMessage = NSLocalizedString("course_selection.no_general_selected", comment: "未选通识课") }
                return
            }

            // 按序号逐条退选
            for item in selected {
                try await app.dropGeneralElectiveCourse(term: term, courseSerial: item.courseSerial)
            }

            await loadGeneralCourses()

            #if !os(visionOS) && canImport(UIKit)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            #endif
        } catch {
            await MainActor.run { generalErrorMessage = error.localizedDescription }
            #if !os(visionOS) && canImport(UIKit)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            #endif
        }
    }

    private func categoryName(for course: CourseSelectionItem) -> String {
        let code = course.raw.courseAttrCode.uppercased()
        if code.hasPrefix("A") { return "必修课" }
        if code.hasPrefix("B") { return "专业课" }
        if code.hasPrefix("G") { return "通识课" }
        return "选修课"
    }
}

/// 后端可选课程项包装
struct CourseSelectionItem: Identifiable, Equatable {
    let raw: SelectableCourse

    var id: Int { raw.idn }
    var idn: Int { raw.idn }
    var isRemoteSelected: Bool {
        !raw.selectionStatus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || raw.selectedId > 0
    }

    static func == (lhs: CourseSelectionItem, rhs: CourseSelectionItem) -> Bool {
        lhs.idn == rhs.idn
    }
}

/// 通识课项包装
struct GeneralElectiveCourseItem: Identifiable, Equatable {
    let raw: GeneralElectiveCourse
    let learnMode: CourseSelectionView.LearnMode
    
    var id: Int { raw.courseSerial }
    var courseSerial: Int { raw.courseSerial }
    
    init(raw: GeneralElectiveCourse) {
        self.raw = raw
        let description = raw.description ?? ""
        let isOnline = description.contains("在线学习") || 
                      description.contains("线上") || 
                      description.contains("智慧树")
        self.learnMode = isOnline ? .online : .offline
    }
    
    static func == (lhs: GeneralElectiveCourseItem, rhs: GeneralElectiveCourseItem) -> Bool {
        lhs.id == rhs.id
    }
}

/// 分类按钮
struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// 课程选择行视图（选修课）
struct CourseSelectionRow: View {
    let course: CourseSelectionItem
    let isSelected: Bool
    let isRemoteSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(course.raw.courseName)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    HStack(spacing: 12) {
                        Label(course.raw.teacherName, systemImage: "person")
                        Label("\(course.raw.credits, specifier: "%.1f") 学分", systemImage: "book")
                        Label(course.raw.examTypeName, systemImage: "list.bullet")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Text("\(course.raw.courseCode) · \(course.raw.courseSerial)")
                        Text("容量 \(course.raw.capacity)")
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }

                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? .blue : .secondary)
                        .font(.title2)

                    if isRemoteSelected {
                        Text("已选")
                            .font(.caption2)
                            .foregroundStyle(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

/// 通识课选择行视图
struct GeneralCourseSelectionRow: View {
    let course: GeneralElectiveCourseItem
    let isSelected: Bool
    let isRemoteSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(course.raw.courseName)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    HStack(spacing: 12) {
                        Label(course.raw.teacherName, systemImage: "person")
                        Label(course.raw.categoryName, systemImage: "tag")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        if let description = course.raw.description, !description.isEmpty {
                            Text(description)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(2)
                        }
                        
                        HStack(spacing: 8) {
                            Label(course.learnMode.rawValue, systemImage: course.learnMode == .online ? "wifi" : "building.2")
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(course.learnMode == .online ? Color.blue : Color.orange)
                                .clipShape(Capsule())
                            
                            Text("可选 \(course.raw.availableCount)/\(course.raw.capacity)")
                                .font(.caption2)
                                .foregroundStyle(isGeneralCourseAvailable(course.raw) ? .green : .red)
                        }
                    }

                    HStack(spacing: 8) {
                        Text("周次:\(course.raw.week)")
                        Text("节次:\(course.raw.startSlot)-\(course.raw.endSlot)")
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }

                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? .blue : .secondary)
                        .font(.title2)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

