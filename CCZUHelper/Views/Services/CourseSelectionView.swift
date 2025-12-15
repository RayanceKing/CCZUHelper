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
    
    @State private var availableCourses: [CourseSelectionItem] = []
    @State private var selectedCourseIds: Set<Int> = []
    @State private var isLoading = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var searchText: String = ""
    @State private var selectedCategory: CourseCategory = .all
    @State private var showDropAllConfirm = false
    
    enum CourseCategory: String, CaseIterable, Codable {
        case all = "全部"
        case required = "必修课"
        case elective = "选修课"
        case general = "通识课"
        case professional = "专业课"
    }
    
    var filteredCourses: [CourseSelectionItem] {
        var courses = availableCourses

        if selectedCategory != .all {
            courses = courses.filter { category(for: $0) == selectedCategory }
        }

        if !searchText.isEmpty {
            courses = courses.filter {
                $0.raw.courseName.localizedCaseInsensitiveContains(searchText) ||
                $0.raw.teacherName.localizedCaseInsensitiveContains(searchText) ||
                $0.raw.courseCode.localizedCaseInsensitiveContains(searchText)
            }
        }

        return courses
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView("loading".localized)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    ContentUnavailableView {
                        Label("course_selection.loading_failed".localized, systemImage: "exclamationmark.triangle.fill")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("retry".localized) {
                            Task {
                                await loadCourses()
                            }
                        }
                    }
                } else {
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
                    .searchable(text: $searchText, prompt: "course_selection.search_placeholder".localized)
                    .disabled(isSubmitting)
                }
            }
            .navigationTitle("course_selection.title".localized)
            .navigationBarTitleDisplayMode(.inline)
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
                                await loadCourses()
                            }
                        }) {
                            Label("refresh".localized, systemImage: "arrow.clockwise")
                        }
                        
                        Button(action: {
                            Task {
                                await submitSelection()
                            }
                        }) {
                            Label("course_selection.submit".localized, systemImage: "checkmark.circle")
                        }
                        .disabled(!hasPendingChanges || isSubmitting)

                        Button(action: {
                            selectAll()
                        }) {
                            Label("全选", systemImage: "checkmark.circle.badge.plus")
                        }
                        .disabled(isSubmitting)

                        Button(role: .destructive) {
                            showDropAllConfirm = true
                        } label: {
                            Label("course_selection.drop_all".localized(with: "一键退选"), systemImage: "trash")
                        }
                        .disabled(remoteSelectedIds.isEmpty || isSubmitting)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSubmitting {
                        ProgressView()
                    }
                }
            }
            .alert("确定退选全部已选课程？", isPresented: $showDropAllConfirm) {
                Button(role: .destructive) {
                    Task { await dropAllSelectedCourses() }
                } label: {
                    Text("退选")
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("此操作将退选所有已选课程，是否继续？")
            }
            .overlay {
                if isSubmitting {
                    ProgressView("course_selection.submitting".localized(with: "正在提交..."))
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .onAppear {
            if availableCourses.isEmpty {
                Task {
                    await loadCourses()
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
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
    
    // MARK: - Private Methods
    
    private func loadCourses() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let app = try await settings.ensureJwqywxLoggedIn()
            let courses = try await app.getCurrentSelectableCourses()
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
                var term = toSelect.first?.raw.term ?? ""
                if term.isEmpty {
                    let terms = try await app.getTerms()
                    term = terms.message.first?.term ?? ""
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

/// 课程选择行视图
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

//#Preview {
//    let sample = CourseSelectionItem(raw: SelectableCourse(
//        term: "25-26-2",
//        classCode: "CS2501",
//        className: "计科25-01班",
//        courseCode: "CS101",
//        courseName: "数据结构与算法",
//        courseSerial: "CS101-01",
//        categoryCode: "A1",
//        hours: 64,
//        credits: 4.0,
//        examTypeName: "考试",
//        capacity: 120,
//        courseAttrCode: "A1",
//        teacherCode: "T001",
//        teacherName: "张教授",
//        isExamType: 1,
//        examMode: 1,
//        idn: 123,
//        selectionStatus: "",
//        selectedId: 0,
//        studyType: "主修"
//    ))
//    CourseSelectionRow(course: sample, isSelected: true, isRemoteSelected: false, onToggle: {})
//}

