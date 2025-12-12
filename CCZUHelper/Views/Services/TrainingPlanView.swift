//
//  TrainingPlanView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/6.
//

import SwiftUI
import CCZUKit

/// 培养方案视图
struct TrainingPlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    
    @State private var planData: TrainingPlan?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedSemester: Int = 1
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("loading".localized)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    ContentUnavailableView {
                        Label("training_plan.loading_failed".localized, systemImage: "exclamationmark.triangle.fill")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("retry".localized) {
                            Task {
                                await loadTrainingPlan()
                            }
                        }
                    }
                } else if let plan = planData {
                    List {
                        // 专业信息概览
                        Section {
                            TrainingPlanInfoRow(label: "training_plan.major".localized, value: plan.majorName)
                            TrainingPlanInfoRow(label: "training_plan.duration".localized, value: "\(plan.durationYears) 年")
                            TrainingPlanInfoRow(label: "training_plan.total_credits".localized, value: "\(plan.totalCredits) 学分")
                        }
                        
                        // 学分分布
                        Section("training_plan.credit_distribution".localized) {
                            CreditDistributionRow(label: "training_plan.required_credits".localized, credits: plan.requiredCredits, total: plan.totalCredits, color: .blue)
                            CreditDistributionRow(label: "training_plan.elective_credits".localized, credits: plan.electiveCredits, total: plan.totalCredits, color: .orange)
                            CreditDistributionRow(label: "training_plan.practice_credits".localized, credits: plan.practiceCredits, total: plan.totalCredits, color: .green)
                        }
                        
                        // 学期选择器
                        Section {
                            Picker("training_plan.semester".localized, selection: $selectedSemester) {
                                ForEach(plan.coursesBySemester.keys.sorted(), id: \.self) { semester in
                                    Text("第 \(semester) 学期").tag(semester)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        
                        // 课程列表
                        if let courses = plan.coursesBySemester[selectedSemester] {
                            Section("training_plan.semester_courses".localized) {
                                ForEach(courses) { course in
                                    PlanCourseRow(course: course)
                                }
                                
                                // 学期学分统计
                                HStack {
                                    Text("training_plan.semester_total".localized)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text("\(courses.reduce(0) { $0 + $1.credits }, specifier: "%.1f") 学分")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        
                        // 培养目标
                        if let objectives = plan.objectives, !objectives.isEmpty {
                            Section("training_plan.objectives".localized) {
                                Text(objectives)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    ContentUnavailableView {
                        Label("training_plan.no_plan".localized, systemImage: "doc.text")
                    } description: {
                        Text("training_plan.no_plan_desc".localized)
                    }
                }
            }
            .navigationTitle("training_plan.title".localized)
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
                            Task { await loadTrainingPlan() }
                        }) {
                            Label("refresh".localized, systemImage: "arrow.clockwise")
                        }

                        Button(action: { clearTrainingPlanCache() }) {
                            Label("training_plan.clear_cache".localized, systemImage: "trash")
                        }

                        Button(action: { exportPlan() }) {
                            Label("training_plan.export".localized, systemImage: "square.and.arrow.up")
                        }
                        .disabled(true)
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
        }
        .onAppear {
            if planData == nil {
                Task { await loadTrainingPlan() }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadTrainingPlan() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let app = try await settings.ensureJwqywxLoggedIn()
            let plan = try await app.getTrainingPlan()
            self.planData = plan
            if let firstSemester = plan.coursesBySemester.keys.sorted().first {
                self.selectedSemester = firstSemester
            }
            isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            print("TrainingPlan error: \(error)")
        }
    }

    private func clearTrainingPlanCache() {
#if canImport(CCZUKit)
        if let app = settings.jwqywxApplication {
            app.clearTrainingPlanCache()
            app.deleteTrainingPlanDiskCache()
            Task { await loadTrainingPlan() }
        }
#endif
    }
    
    private func exportPlan() {
        // TODO: 实现导出功能
        print("Export training plan")
    }
}

// 使用 CCZUKit 的模型类型

/// 信息行视图
struct TrainingPlanInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

/// 学分分布行视图
struct CreditDistributionRow: View {
    let label: String
    let credits: Double
    let total: Double
    let color: Color
    
    var percentage: Double {
        guard total > 0 else { return 0 }
        return credits / total
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text("\(credits, specifier: "%.1f") 学分")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("(\(percentage * 100, specifier: "%.1f")%)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * percentage)
                }
            }
            .frame(height: 8)
            .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}

/// 计划课程行视图
struct PlanCourseRow: View {
    let course: PlanCourse
    
    var typeColor: Color {
        switch course.type {
        case .required: return .blue
        case .elective: return .orange
        case .practice: return .green
        }
    }
    
    var localizedTypeText: String {
        switch course.type {
        case .required:
            return NSLocalizedString("training_plan.type.required", comment: "")
        case .elective:
            return NSLocalizedString("training_plan.type.elective", comment: "")
        case .practice:
            return NSLocalizedString("training_plan.type.practice", comment: "")
        }
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(course.name)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    Text(course.code)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if let teacher = course.teacher {
                        Text(teacher)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(course.credits, specifier: "%.1f") 学分")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(localizedTypeText)
                    .font(.caption2)
                    .foregroundStyle(typeColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(typeColor.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    TrainingPlanView()
        .environment(AppSettings())
}

