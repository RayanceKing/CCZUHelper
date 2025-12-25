//
//  CourseSelectionView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/6.
//

import SwiftUI
import CCZUKit

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
    @State private var selectedCategory: CourseCategory = .all
    @State private var showDropAllConfirm = false
    @State private var showDropGeneralConfirm = false
    
    // 通识课相关
    @State private var availableGeneralCourses: [GeneralElectiveCourseItem] = []
    @State private var selectedGeneralCourseIds: Set<Int> = []
    @State private var selectedGeneralLearnMode: LearnMode? = nil
    @State private var selectedGeneralCategory: String = ""
    @State private var generalErrorMessage: String?
    @State private var isGeneralLoading = false
    @State private var currentMode: CourseSelectionMode = .elective
    
    enum CourseSelectionMode: String, CaseIterable {
        case elective = "选修课"
        case general = "通识课"
    }
    
    enum LearnMode: String, CaseIterable {
        case online = "线上"
        case offline = "线下"
    }
    
    enum CourseCategory: String, CaseIterable, Codable {
        case all = "全部"
        case required = "必修课"
        case elective = "选修课"
        case general = "通识课"
        case professional = "专业课"
    }
    
    // MARK: - Computed Properties
    
    private var filteredCourses: [CourseSelectionItem] {
        var courses = availableCourses

        if selectedCategory != .all {
            courses = courses.filter { category(for: $0) == selectedCategory }
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    if currentMode == .elective && isSubmitting {
                        ProgressView()
                    } else if currentMode == .general && isGeneralLoading {
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
                } else if currentMode == .general && availableGeneralCourses.isEmpty {
                    await loadGeneralCourses()
                }
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
                // 分类选择器
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(CourseCategory.allCases, id: \.self) { category in
                            CategoryButton(
                                title: category.rawValue,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(uiColor: .systemGroupedBackground))
                
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
            
            let term = "25-26-2"
            let courses = try await app.getGeneralElectiveCourses(
                term: term,
                classCode: info.classCode,
                grade: info.grade,
                campus: info.campus
            )
            
            let items = courses.map { GeneralElectiveCourseItem(raw: $0) }

            await MainActor.run {
                availableGeneralCourses = items
                isGeneralLoading = false
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
            
            let coursesToSelect = availableGeneralCourses.filter { 
                selectedGeneralCourseIds.contains($0.courseSerial)
            }
            
            guard !coursesToSelect.isEmpty else {
                throw CCZUError.missingData(NSLocalizedString("course_selection.please_select", comment: "请先选择课程"))
            }
            
            let term = "25-26-2"
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
            let term = "25-26-2"

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

    private func category(for course: CourseSelectionItem) -> CourseCategory {
        let code = course.raw.courseAttrCode.uppercased()
        if code.hasPrefix("A") { return .required }
        if code.hasPrefix("B") { return .professional }
        if code.hasPrefix("G") { return .general }
        return .elective
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
                                .foregroundStyle(course.raw.availableCount > 0 ? .green : .red)
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
