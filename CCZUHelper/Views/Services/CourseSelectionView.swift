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
    @Environment(\.serviceEmbeddedNavigation) private var serviceEmbeddedNavigation
    @Environment(AppSettings.self) var settings
    
    // 选修课相关
    @State var availableCourses: [CourseSelectionItem] = []
    @State var selectedCourseIds: Set<Int> = []
    @State var isLoading = false
    @State var isSubmitting = false
    @State var errorMessage: String?
    @State private var searchText: String = ""
    @State private var selectedCategory: String = "common.all".localized
    @State private var showDropAllConfirm = false
    @State private var showDropGeneralConfirm = false
    
    // 通识课相关
    @State var availableGeneralCourses: [GeneralElectiveCourseItem] = []
    @State var selectedGeneralCourseIds: Set<Int> = []
    @State private var selectedGeneralLearnMode: LearnMode? = nil
    @State private var selectedGeneralCategory: String = ""
    @State var generalErrorMessage: String?
    @State var isGeneralLoading = false
    @State private var selectedGeneralFilter: GeneralFilter = .all
    @State private var hasEnteredGeneralOnce = false
    @State private var currentMode: CourseSelectionMode = .elective
    
    // MARK: - Computed Properties
    
    var filteredCourses: [CourseSelectionItem] {
        var courses = availableCourses

        if selectedCategory != "common.all".localized {
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
            .navigationTitle("course_selection.system".localized)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(macOS)
                if !serviceEmbeddedNavigation {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common.close".localized) {
                            dismiss()
                        }
                    }
                }
                #else
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.close".localized) {
                        dismiss()
                    }
                }
                #endif
                // 筛选菜单（全部 / 可选 / 已选） — 放在多功能菜单之前
                #if os(macOS)
                ToolbarItem(placement: .automatic) {
                    if currentMode == .general {
                        Menu {
                            Button(action: { selectedGeneralFilter = .all }) {
                                if selectedGeneralFilter == .all {
                                    Label("common.all".localized, systemImage: "checkmark")
                                } else {
                                    Text("common.all".localized)
                                }
                            }
                            Button(action: { selectedGeneralFilter = .available }) {
                                if selectedGeneralFilter == .available {
                                    Label("course.filter.available".localized, systemImage: "checkmark")
                                } else {
                                    Text("course.filter.available".localized)
                                }
                            }
                            Button(action: { selectedGeneralFilter = .selected }) {
                                if selectedGeneralFilter == .selected {
                                    Label("course_selection.selected".localized, systemImage: "checkmark")
                                } else {
                                    Text("course_selection.selected".localized)
                                }
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease")
                        }
                    }
                }
                #else
                ToolbarItem(placement: .navigationBarTrailing) {
                    if currentMode == .general {
                        Menu {
                            Button(action: { selectedGeneralFilter = .all }) {
                                if selectedGeneralFilter == .all {
                                    Label("common.all".localized, systemImage: "checkmark")
                                } else {
                                    Text("common.all".localized)
                                }
                            }
                            Button(action: { selectedGeneralFilter = .available }) {
                                if selectedGeneralFilter == .available {
                                    Label("course.filter.available".localized, systemImage: "checkmark")
                                } else {
                                    Text("course.filter.available".localized)
                                }
                            }
                            Button(action: { selectedGeneralFilter = .selected }) {
                                if selectedGeneralFilter == .selected {
                                    Label("course_selection.selected".localized, systemImage: "checkmark")
                                } else {
                                    Text("course_selection.selected".localized)
                                }
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease")
                        }
                    }
                }
                #endif
                // 多功能菜单（刷新/提交/退选等）
                #if os(macOS)
                ToolbarItem(placement: .primaryAction) {
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
                #else
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
                #endif
                // 仅在选修模式下显示提交中的进度指示，通识模式不在右上角显示加载状态
                #if os(macOS)
                ToolbarItem(placement: .automatic) {
                    if currentMode == .elective && isSubmitting {
                        ProgressView()
                    }
                }
                #else
                ToolbarItem(placement: .navigationBarTrailing) {
                    if currentMode == .elective && isSubmitting {
                        ProgressView()
                    }
                }
                #endif
            }
            .alert(Text("course_selection.drop_all_confirm_title"), isPresented: $showDropAllConfirm) {
                Button(role: .destructive) {
                    Task { await dropAllSelectedCourses() }
                } label: {
                    Text("course_selection.drop")
                }
                Button("common.cancel".localized, role: .cancel) { }
            } message: {
                Text("course_selection.drop_all_confirm_message")
            }

            .alert(Text("course_selection.general_drop_confirm_title"), isPresented: $showDropGeneralConfirm) {
                Button(role: .destructive) {
                    Task { await dropSelectedGeneralCourses() }
                } label: {
                    Text("course_selection.drop")
                }
                Button("common.cancel".localized, role: .cancel) { }
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
                .background(
                    {
                        #if os(macOS)
                        return Color(nsColor: .windowBackgroundColor)
                        #else
                        return Color(uiColor: .systemGroupedBackground)
                        #endif
                    }()
                )
                
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
    
}
