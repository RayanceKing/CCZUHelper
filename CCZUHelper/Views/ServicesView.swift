//
//  ServicesView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/11/30
//

import SwiftUI
import SafariServices
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
/// 用于在 SwiftUI 中包装 SFSafariViewController 的视图
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // 无需更新
    }
}
#endif

/// 一个可识别的 URL 包装器, 用于 sheet 展示
struct URLWrapper: Identifiable {
    let id = UUID()
    let url: URL
}

/// 服务视图
struct ServicesView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.openURL) private var varopenURL
    
    @State private var showGradeQuery = false
    @State private var showExamSchedule = false
    @State private var showCreditGPA = false
    @State private var showCourseEvaluation = false
    @State private var showTeachingNotice = false
    @State private var showCourseSelection = false
    @State private var showTrainingPlan = false
    @State private var showElectricityQuery = false
    @State private var selectedURLWrapper: URLWrapper?
    
    private let services: [ServiceItem] = [
        ServiceItem(title: "services.grade_query".localized, icon: "chart.bar.doc.horizontal", color: .blue),
        ServiceItem(title: "services.credit_gpa".localized, icon: "star.circle", color: .orange),
        ServiceItem(title: "services.exam_schedule".localized, icon: "calendar.badge.clock", color: .purple),
        ServiceItem(title: "electricity.title".localized, icon: "bolt.fill", color: .green),
    ]
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]
    
    var body: some View {
        NavigationStack {
            List {
                serviceGridSection
                commonFunctionsSection
                quickLinksSection
            }
            .navigationTitle("services.title".localized)
            .sheet(isPresented: $showGradeQuery) {
                GradeQueryView()
                    .environment(settings)
            }
            .sheet(isPresented: $showExamSchedule) {
                ExamScheduleView()
                    .environment(settings)
            }
            .sheet(isPresented: $showCreditGPA) {
                CreditGPAView()
                    .environment(settings)
            }
            .sheet(isPresented: $showCourseEvaluation) {
                CourseEvaluationView()
                    .environment(settings)
            }
            .sheet(isPresented: $showTeachingNotice) {
                TeachingNoticeView()
                    .environment(settings)
            }
            .sheet(isPresented: $showCourseSelection) {
                CourseSelectionView()
                    .environment(settings)
            }
            .sheet(isPresented: $showTrainingPlan) {
                TrainingPlanView()
                    .environment(settings)
            }
            .sheet(isPresented: $showElectricityQuery) {
                ElectricityQueryView()
                    .environment(settings)
            }
            #if canImport(UIKit)
            .sheet(item: $selectedURLWrapper) { wrapper in
                SafariView(url: wrapper.url)
            }
            #endif
        }
    }
    
    /// 服务网格
    private var serviceGridSection: some View {
        Section {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(services) { service in
                    Button(action: {
                        handleServiceTap(service.title)
                    }) {
                        ServiceButton(item: service)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
    
    /// 常用功能
    private var commonFunctionsSection: some View {
        Section("services.common_functions".localized) {
            //暂时移除教务通知功能
//            Button(action: { showTeachingNotice = true }) {
//                Label {
//                    HStack {
//                        Text("services.teaching_notice".localized)
//                        Spacer()
//                        Text("services.new".localized)
//                            .font(.caption2)
//                            .fontWeight(.bold)
//                            .foregroundStyle(.white)
//                            .padding(.horizontal, 6)
//                            .padding(.vertical, 2)
//                            .background(Color.red)
//                            .clipShape(Capsule())
//                    }
//                } icon: {
//                    Image(systemName: "bell.badge")
//                }
//            }

            Button(action: { showCourseEvaluation = true }) {
                Label("services.course_evaluation".localized, systemImage: "hand.thumbsup")
            }

            Button(action: { showCourseSelection = true }) {
                Label("services.course_selection".localized, systemImage: "checklist")
            }

            Button(action: { showTrainingPlan = true }) {
                Label("services.training_plan".localized, systemImage: "doc.text")
            }
        }
    }
    
    /// 快捷入口
    private var quickLinksSection: some View {
        Section("services.quick_links".localized) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    QuickLink(title: "services.teaching_system".localized, icon: "globe", color: .blue) {
                        if let url = URL(string: "http://jwqywx.cczu.edu.cn/") {
                            #if canImport(UIKit)
                            selectedURLWrapper = URLWrapper(url: url)
                            #else
                            openURL(url)
                            #endif
                        }
                    }
                    QuickLink(title: "services.email_system".localized, icon: "envelope", color: .orange) {
                        if let url = URL(string: "https://www.cczu.edu.cn/yxxt/list.htm") {
                            #if canImport(UIKit)
                            selectedURLWrapper = URLWrapper(url: url)
                            #else
                            openURL(url)
                            #endif
                        }
                    }
                    QuickLink(title: "services.vpn".localized, icon: "network", color: .green) {
                        if let url = URL(string: "https://zmvpn.cczu.edu.cn") {
                            #if canImport(UIKit)
                            selectedURLWrapper = URLWrapper(url: url)
                            #else
                            openURL(url)
                            #endif
                        }
                    }
                    QuickLink(title: "services.smart_campus".localized, icon: "building", color: .purple) {
                        // 无 URL, 不执行任何操作
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear) // Added this line to clear the background
        }
    }
    
    private func handleServiceTap(_ title: String) {
        let gradeQueryTitle = "services.grade_query".localized
        let creditGPATitle = "services.credit_gpa".localized
        let examScheduleTitle = "services.exam_schedule".localized
        let electricityTitle = "electricity.title".localized
        
        switch title {
        case gradeQueryTitle:
            showGradeQuery = true
        case creditGPATitle:
            showCreditGPA = true
        case examScheduleTitle:
            showExamSchedule = true
        case electricityTitle:
            showElectricityQuery = true
        default:
            break
        }
    }
}

/// 服务项目模型
struct ServiceItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
}

/// 服务按钮
struct ServiceButton: View {
    let item: ServiceItem
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: item.icon)
                .font(.title)
                .foregroundStyle(item.color)
                .frame(width: 50, height: 50)
                .background(item.color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            Text(item.title)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }
}

/// 服务行
struct ServiceRow: View {
    let title: String
    let icon: String
    var hasNew: Bool = false
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 30)
            
            Text(title)
                .font(.body)
            
            Spacer()
            
            if hasNew {
                Text("services.new".localized)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red)
                    .clipShape(Capsule())
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .contentShape(Rectangle())
    }
}

/// 快捷链接
struct QuickLink: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(color.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ServicesView()
        .environment(AppSettings())
}
