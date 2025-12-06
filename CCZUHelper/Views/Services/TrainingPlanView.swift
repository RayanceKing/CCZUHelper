//
//  TrainingPlanView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/6.
//

import SwiftUI

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
                            TrainingPlanInfoRow(label: "training_plan.degree".localized, value: plan.degree)
                            TrainingPlanInfoRow(label: "training_plan.duration".localized, value: "\(plan.duration) 年")
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
                                ForEach(1...plan.duration * 2, id: \.self) { semester in
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
                        Section("training_plan.objectives".localized) {
                            Text(plan.objectives)
                                .font(.body)
                                .foregroundStyle(.secondary)
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
                            Task {
                                await loadTrainingPlan()
                            }
                        }) {
                            Label("refresh".localized, systemImage: "arrow.clockwise")
                        }
                        
                        Button(action: {
                            exportPlan()
                        }) {
                            Label("training_plan.export".localized, systemImage: "square.and.arrow.up")
                        }
                        .disabled(planData == nil)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            if planData == nil {
                Task {
                    await loadTrainingPlan()
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadTrainingPlan() async {
        isLoading = true
        errorMessage = nil
        
        // 模拟加载延迟
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            // TODO: 实际从API加载培养方案
            // 临时使用示例数据
            self.planData = TrainingPlan(
                majorName: "法学",
                degree: "法学学士",
                duration: 4,
                totalCredits: 160.0,
                requiredCredits: 120.0,
                electiveCredits: 30.0,
                practiceCredits: 10.0,
                objectives: "本专业培养德智体美劳全面发展，具有扎实的法学理论基础和较强的法律实务能力，能够在国家机关、企事业单位和社会团体从事法律工作的应用型、复合型法律人才。",
                coursesBySemester: [
                    1: [
                        PlanCourse(name: "法理学", code: "70091061", credits: 4.0, type: .required, teacher: "张教授"),
                        PlanCourse(name: "宪法学", code: "70730041", credits: 4.0, type: .required, teacher: "李教授"),
                        PlanCourse(name: "中国法律史", code: "7A270041", credits: 4.0, type: .required, teacher: "王教授"),
                        PlanCourse(name: "大学英语", code: "EN101", credits: 3.0, type: .required, teacher: "赵老师"),
                        PlanCourse(name: "体育", code: "PE101", credits: 1.0, type: .required, teacher: "陈教练"),
                    ],
                    2: [
                        PlanCourse(name: "刑法总论", code: "70770061", credits: 4.0, type: .required, teacher: "刘教授"),
                        PlanCourse(name: "民法总论", code: "70250061", credits: 4.0, type: .required, teacher: "周教授"),
                        PlanCourse(name: "马克思主义基本原理", code: "72330051", credits: 3.0, type: .required, teacher: "吴教授"),
                        PlanCourse(name: "大学英语", code: "EN102", credits: 3.0, type: .required, teacher: "赵老师"),
                        PlanCourse(name: "体育", code: "PE102", credits: 1.0, type: .required, teacher: "陈教练"),
                    ],
                    3: [
                        PlanCourse(name: "刑法分论", code: "70771061", credits: 4.0, type: .required, teacher: "刘教授"),
                        PlanCourse(name: "民法分论", code: "7A250071", credits: 4.0, type: .required, teacher: "周教授"),
                        PlanCourse(name: "刑事诉讼法", code: "70780043", credits: 4.0, type: .required, teacher: "戈教授"),
                        PlanCourse(name: "经济法", code: "70550043", credits: 3.0, type: .elective, teacher: "郑教授"),
                    ]
                ]
            )
            self.isLoading = false
        }
    }
    
    private func exportPlan() {
        // TODO: 实现导出功能
        print("Export training plan")
    }
}

/// 培养方案模型
struct TrainingPlan: Codable {
    let majorName: String
    let degree: String
    let duration: Int
    let totalCredits: Double
    let requiredCredits: Double
    let electiveCredits: Double
    let practiceCredits: Double
    let objectives: String
    let coursesBySemester: [Int: [PlanCourse]]
}

/// 计划课程模型
struct PlanCourse: Identifiable, Codable {
    let id = UUID()
    let name: String
    let code: String
    let credits: Double
    let type: CourseType
    let teacher: String
    
    enum CourseType: String, Codable {
        case required = "必修"
        case elective = "选修"
        case practice = "实践"
    }
}

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
        credits / total
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
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(course.name)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    Text(course.code)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(course.teacher)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(course.credits, specifier: "%.1f") 学分")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(course.type.rawValue)
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
