//
//  ServicesView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/11/30
//

import SwiftUI
#if canImport(SafariServices)
import SafariServices
#endif
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

private struct ServiceEmbeddedNavigationKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var serviceEmbeddedNavigation: Bool {
        get { self[ServiceEmbeddedNavigationKey.self] }
        set { self[ServiceEmbeddedNavigationKey.self] = newValue }
    }
}

/// 服务视图
struct ServicesView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showGradeQuery = false
    @State private var showExamSchedule = false
    @State private var showCreditGPA = false
    @State private var showCourseEvaluation = false
    @State private var showTeachingNotice = false
    @State private var showCourseSelection = false
    @State private var showTrainingPlan = false
    @State private var showElectricityQuery = false
    @State private var showCompetitionQuery = false
    @State private var selectedURLWrapper: URLWrapper?
    #if os(macOS)
    @State private var macCurrentRoute: MacServiceRoute? = nil
    @State private var macBackStack: [MacServiceRoute] = []
    @State private var macForwardStack: [MacServiceRoute] = []
    #endif
    
    private let services: [ServiceItem] = [
        ServiceItem(title: "services.grade_query".localized, icon: "chart.bar.doc.horizontal", color: .blue),
        ServiceItem(title: "services.credit_gpa".localized, icon: "star.circle", color: .orange),
        ServiceItem(title: "services.exam_schedule".localized, icon: "calendar.badge.clock", color: .purple),
        ServiceItem(title: "electricity.title".localized, icon: "bolt.fill", color: .green),
        ServiceItem(title: "services.competition_query".localized, icon: "trophy.fill", color: .yellow),
    ]
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]
    
    var body: some View {
        #if os(macOS)
        Group {
            if let route = macCurrentRoute {
                macDestinationView(for: route)
            } else {
                macRootList
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    macGoBack()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(macCurrentRoute == nil && macBackStack.isEmpty)

                Button {
                    macGoForward()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(macForwardStack.isEmpty)
            }
        }
        .navigationTitle(macCurrentRoute?.title ?? "services.title".localized)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("IntentPresentGradeQuery"))) { _ in
            macPush(.gradeQuery)
        }
        #else
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
            .sheet(isPresented: $showCompetitionQuery) {
                CompetitionQueryView()
            }
            #if canImport(UIKit)
            .sheet(item: $selectedURLWrapper) { wrapper in
                SafariView(url: wrapper.url)
            }
            #endif
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("IntentPresentGradeQuery"))) { _ in
                showGradeQuery = true
            }
        }
        #endif
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
            #if os(macOS)
            VStack(spacing: 10) {
                macOSCommonFunctionGroup([
                    ("services.course_evaluation".localized, "hand.thumbsup", { showCourseEvaluation = true }),
                    ("services.course_selection".localized, "checklist", { showCourseSelection = true }),
                    ("services.training_plan".localized, "doc.text", { showTrainingPlan = true }),
                ])
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 10, bottom: 8, trailing: 10))
            .listRowBackground(Color.clear)
            #else
            Button(action: { showCourseEvaluation = true }) {
                Label("services.course_evaluation".localized, systemImage: "hand.thumbsup")
            }
            Button(action: { showCourseSelection = true }) {
                Label("services.course_selection".localized, systemImage: "checklist")
            }
            Button(action: { showTrainingPlan = true }) {
                Label("services.training_plan".localized, systemImage: "doc.text")
            }
            #endif
        }
    }

    #if os(macOS)
    private func macOSCommonFunctionGroup(_ items: [(title: String, icon: String, action: () -> Void)]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Button(action: item.action) {
                    HStack(spacing: 12) {
                        Image(systemName: item.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.secondary.opacity(0.12))
                            )

                        Text(item.title)
                            .font(.body)
                            .foregroundStyle(.primary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                }
                .buttonStyle(.plain)

                if index < items.count - 1 {
                    Divider()
                        .padding(.leading, 48)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
    #endif
    
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
        let competitionTitle = "services.competition_query".localized
        
        switch title {
        case gradeQueryTitle:
            showGradeQuery = true
        case creditGPATitle:
            showCreditGPA = true
        case examScheduleTitle:
            showExamSchedule = true
        case electricityTitle:
            showElectricityQuery = true
        case competitionTitle:
            showCompetitionQuery = true
        default:
            break
        }
    }

    #if os(macOS)
    private var macRootList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                macSettingsGroup(
                    title: "services.title".localized,
                    rows: [
                        .init(route: .gradeQuery),
                        .init(route: .creditGPA),
                        .init(route: .examSchedule),
                        .init(route: .electricityQuery),
                        .init(route: .competitionQuery),
                    ]
                )

                macSettingsGroup(
                    title: "services.common_functions".localized,
                    rows: [
                        .init(route: .courseEvaluation),
                        .init(route: .courseSelection),
                        .init(route: .trainingPlan),
                    ]
                )

                macSettingsGroup(
                    title: "services.quick_links".localized,
                    rows: [
                        .init(link: .teachingSystem),
                        .init(link: .emailSystem),
                        .init(link: .vpn),
                        .init(link: .smartCampus),
                    ]
                )
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private func macDestinationView(for route: MacServiceRoute) -> some View {
        switch route {
        case .gradeQuery:
            GradeQueryView()
                .environment(settings)
                .environment(\.serviceEmbeddedNavigation, true)
        case .creditGPA:
            CreditGPAView()
                .environment(settings)
                .environment(\.serviceEmbeddedNavigation, true)
        case .examSchedule:
            ExamScheduleView()
                .environment(settings)
                .environment(\.serviceEmbeddedNavigation, true)
        case .electricityQuery:
            ElectricityQueryView()
                .environment(settings)
                .environment(\.serviceEmbeddedNavigation, true)
        case .competitionQuery:
            CompetitionQueryView()
                .environment(\.serviceEmbeddedNavigation, true)
        case .courseEvaluation:
            CourseEvaluationView()
                .environment(settings)
                .environment(\.serviceEmbeddedNavigation, true)
        case .courseSelection:
            CourseSelectionView()
                .environment(settings)
                .environment(\.serviceEmbeddedNavigation, true)
        case .trainingPlan:
            TrainingPlanView()
                .environment(settings)
                .environment(\.serviceEmbeddedNavigation, true)
        }
    }

    private func macPush(_ route: MacServiceRoute) {
        if let current = macCurrentRoute {
            macBackStack.append(current)
        }
        macCurrentRoute = route
        macForwardStack.removeAll()
    }

    private func macGoBack() {
        if let previous = macBackStack.popLast() {
            if let current = macCurrentRoute {
                macForwardStack.append(current)
            }
            macCurrentRoute = previous
            return
        }
        if let current = macCurrentRoute {
            macForwardStack.append(current)
            macCurrentRoute = nil
        }
    }

    private func macGoForward() {
        guard let next = macForwardStack.popLast() else { return }
        if let current = macCurrentRoute {
            macBackStack.append(current)
        }
        macCurrentRoute = next
    }

    private func openQuickLink(_ link: MacQuickLink) {
        guard let url = URL(string: link.urlString) else { return }
        openURL(url)
    }

    private func macSettingsGroup(title: String?, rows: [MacDetailRow]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.headline)
                    .padding(.horizontal, 2)
            }

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    Button {
                        switch row.kind {
                        case .route(let route):
                            macPush(route)
                        case .link(let link):
                            openQuickLink(link)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: row.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(row.color)
                                .frame(width: 28, height: 28)
                                .background(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(row.color.opacity(0.14))
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.title)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                if let subtitle = row.subtitle {
                                    Text(subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < rows.count - 1 {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        Color(nsColor: .quinaryLabel)
                    )
            )
        }
    }
    #endif
}

#if os(macOS)
private enum MacServiceRoute: String, CaseIterable, Hashable, Identifiable {
    case gradeQuery
    case creditGPA
    case examSchedule
    case electricityQuery
    case competitionQuery
    case courseEvaluation
    case courseSelection
    case trainingPlan

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gradeQuery: return "services.grade_query".localized
        case .creditGPA: return "services.credit_gpa".localized
        case .examSchedule: return "services.exam_schedule".localized
        case .electricityQuery: return "electricity.title".localized
        case .competitionQuery: return "services.competition_query".localized
        case .courseEvaluation: return "services.course_evaluation".localized
        case .courseSelection: return "services.course_selection".localized
        case .trainingPlan: return "services.training_plan".localized
        }
    }

    var icon: String {
        switch self {
        case .gradeQuery: return "chart.bar.doc.horizontal"
        case .creditGPA: return "star.circle"
        case .examSchedule: return "calendar.badge.clock"
        case .electricityQuery: return "bolt.fill"
        case .competitionQuery: return "trophy.fill"
        case .courseEvaluation: return "hand.thumbsup"
        case .courseSelection: return "checklist"
        case .trainingPlan: return "doc.text"
        }
    }

    var color: Color {
        switch self {
        case .gradeQuery: return .blue
        case .creditGPA: return .orange
        case .examSchedule: return .purple
        case .electricityQuery: return .green
        case .competitionQuery: return .yellow
        case .courseEvaluation: return .pink
        case .courseSelection: return .indigo
        case .trainingPlan: return .mint
        }
    }
}

private enum MacQuickLink: String, CaseIterable, Hashable, Identifiable {
    case teachingSystem
    case emailSystem
    case vpn
    case smartCampus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .teachingSystem: return "services.teaching_system".localized
        case .emailSystem: return "services.email_system".localized
        case .vpn: return "services.vpn".localized
        case .smartCampus: return "services.smart_campus".localized
        }
    }

    var icon: String {
        switch self {
        case .teachingSystem: return "globe"
        case .emailSystem: return "envelope"
        case .vpn: return "network"
        case .smartCampus: return "building"
        }
    }

    var urlString: String {
        switch self {
        case .teachingSystem: return "http://jwqywx.cczu.edu.cn/"
        case .emailSystem: return "https://www.cczu.edu.cn/yxxt/list.htm"
        case .vpn: return "https://zmvpn.cczu.edu.cn"
        case .smartCampus: return "https://www.cczu.edu.cn/"
        }
    }
}

private struct MacDetailRow {
    enum Kind {
        case route(MacServiceRoute)
        case link(MacQuickLink)
    }

    let kind: Kind
    let title: String
    let subtitle: String?
    let icon: String
    let color: Color

    init(route: MacServiceRoute) {
        self.kind = .route(route)
        self.title = route.title
        self.subtitle = nil
        self.icon = route.icon
        self.color = route.color
    }

    init(link: MacQuickLink) {
        self.kind = .link(link)
        self.title = link.title
        self.subtitle = link.urlString
        self.icon = link.icon
        self.color = .blue
    }
}
#endif

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
