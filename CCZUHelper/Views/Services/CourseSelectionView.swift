//
//  CourseSelectionView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/6.
//

import SwiftUI

/// 选课系统视图
struct CourseSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    
    @State private var availableCourses: [SelectableCourse] = []
    @State private var selectedCourses: [SelectableCourse] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText: String = ""
    @State private var selectedCategory: CourseCategory = .all
    
    enum CourseCategory: String, CaseIterable, Codable {
        case all = "全部"
        case required = "必修课"
        case elective = "选修课"
        case general = "通识课"
        case professional = "专业课"
    }
    
    var filteredCourses: [SelectableCourse] {
        var courses = availableCourses
        
        // 分类筛选
        if selectedCategory != .all {
            courses = courses.filter { $0.category == selectedCategory }
        }
        
        // 搜索筛选
        if !searchText.isEmpty {
            courses = courses.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.teacher.localizedCaseInsensitiveContains(searchText) ||
                $0.code.localizedCaseInsensitiveContains(searchText)
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
                                        isSelected: selectedCourses.contains(where: { $0.id == course.id }),
                                        onToggle: {
                                            toggleCourseSelection(course)
                                        }
                                    )
                                }
                            }
                        }
                        
                        // 已选课程汇总
                        if !selectedCourses.isEmpty {
                            Section("course_selection.selected_courses".localized) {
                                ForEach(selectedCourses) { course in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(course.name)
                                                .font(.subheadline)
                                            Text("\(course.credits) 学分")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            toggleCourseSelection(course)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                
                                HStack {
                                    Text("course_selection.total_credits".localized)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text("\(totalCredits) 学分")
                                        .fontWeight(.bold)
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "course_selection.search_placeholder".localized)
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
                        .disabled(selectedCourses.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
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
        selectedCourses.reduce(0) { $0 + $1.credits }
    }
    
    // MARK: - Private Methods
    
    private func loadCourses() async {
        isLoading = true
        errorMessage = nil
        
        // 模拟加载延迟
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            // TODO: 实际从API加载课程
            // 临时使用示例数据
            self.availableCourses = [
                SelectableCourse(code: "CS101", name: "数据结构与算法", teacher: "张教授", credits: 4.0, category: .required, capacity: 120, enrolled: 95),
                SelectableCourse(code: "CS102", name: "计算机网络", teacher: "李教授", credits: 3.0, category: .required, capacity: 100, enrolled: 88),
                SelectableCourse(code: "ENG201", name: "学术英语写作", teacher: "王老师", credits: 2.0, category: .general, capacity: 60, enrolled: 45),
                SelectableCourse(code: "MATH301", name: "线性代数", teacher: "刘教授", credits: 4.0, category: .required, capacity: 80, enrolled: 72),
                SelectableCourse(code: "PE101", name: "体育选项课", teacher: "陈教练", credits: 1.0, category: .elective, capacity: 40, enrolled: 35),
                SelectableCourse(code: "CS301", name: "人工智能导论", teacher: "赵教授", credits: 3.0, category: .professional, capacity: 60, enrolled: 48),
            ]
            self.isLoading = false
        }
    }
    
    private func toggleCourseSelection(_ course: SelectableCourse) {
        if let index = selectedCourses.firstIndex(where: { $0.id == course.id }) {
            selectedCourses.remove(at: index)
        } else {
            selectedCourses.append(course)
        }
        
        // 触觉反馈
        #if !os(visionOS) && canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
    
    private func submitSelection() async {
        isLoading = true
        
        // 模拟提交延迟
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        await MainActor.run {
            // TODO: 实际提交选课
            self.isLoading = false
            
            // 成功反馈
            #if !os(visionOS) && canImport(UIKit)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            #endif
        }
    }
}

/// 可选课程模型
struct SelectableCourse: Identifiable, Codable {
    var id = UUID()
    let code: String
    let name: String
    let teacher: String
    let credits: Double
    let category: CourseSelectionView.CourseCategory
    let capacity: Int
    let enrolled: Int
    
    var availableSeats: Int {
        capacity - enrolled
    }
    
    var isFull: Bool {
        enrolled >= capacity
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
    let course: SelectableCourse
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(course.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    HStack(spacing: 12) {
                        Label(course.teacher, systemImage: "person")
                        Label("\(course.credits, specifier: "%.1f") 学分", systemImage: "book")
                        Label("\(course.availableSeats)/\(course.capacity)", systemImage: "person.2")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    
                    Text(course.code)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? .blue : .secondary)
                        .font(.title2)
                    
                    if course.isFull {
                        Text("已满")
                            .font(.caption2)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .disabled(course.isFull && !isSelected)
        .opacity(course.isFull && !isSelected ? 0.5 : 1.0)
    }
}

#Preview {
    CourseSelectionView()
        .environment(AppSettings())
}
