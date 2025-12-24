//
//  ManageSchedulesView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/11/30.
//

import SwiftUI
import SwiftData
import CCZUKit
import UniformTypeIdentifiers
import WidgetKit

#if canImport(UIKit)
import UIKit
#endif

/// 课程信息结构
struct CourseInfo {
    let name: String
    let teacher: String
    let location: String
    let weeks: [Int]
    let dayOfWeek: Int
    let timeSlot: Int
    let duration: Int
}

/// 管理课表视图
struct ManageSchedulesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    
    @Query(sort: \Schedule.createdAt, order: .reverse) private var schedules: [Schedule]
    
    @State private var showImportSheet = false
    @State private var showDeleteAlert = false
    @State private var scheduleToDelete: Schedule?
    @State private var showShareSheet = false
    @State private var exportURL: URL?
    @State private var isExporting = false
    @State private var exportErrorMessage: String?
    @State private var showExportError = false
    @State private var isSyncingCalendar = false
    @State private var calendarSyncError: String?
    @State private var showCalendarSyncError = false
    
    var body: some View {
        NavigationStack {
            List {
                if schedules.isEmpty {
                    ContentUnavailableView {
                        Label("manage_schedules.no_schedules".localized, systemImage: "calendar.badge.exclamationmark")
                    } description: {
                        Text("manage_schedules.no_schedules_hint".localized)
                    }
                } else {
                    ForEach(schedules) { schedule in
                        ScheduleRow(
                            schedule: schedule,
                            onExport: { exportSchedule(schedule) },
                            onSync: { syncCalendarIfNeeded(activeSchedule: schedule) }
                        )
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    scheduleToDelete = schedule
                                    showDeleteAlert = true
                                } label: {
                                    Label("delete".localized, systemImage: "trash")
                                }
                                
                                Button {
                                    setActiveSchedule(schedule)
                                } label: {
                                    Label("schedule.set_current".localized, systemImage: "checkmark.circle")
                                }
                                .tint(.blue)
                            }
                    }
                }
            }
            .navigationTitle("manage_schedules.title".localized)
            #if os(iOS) || os(tvOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showImportSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("manage_schedules.delete_confirm_title".localized, isPresented: $showDeleteAlert, presenting: scheduleToDelete) { schedule in
                Button("cancel".localized, role: .cancel) { }
                Button("delete".localized, role: .destructive) {
                    deleteSchedule(schedule)
                }
            } message: { schedule in
                Text("manage_schedules.delete_confirm_message".localized(with: schedule.name))
            }
            .sheet(isPresented: $showImportSheet) {
                ImportScheduleView()
                    .environment(settings)
            }
            .sheet(isPresented: $showShareSheet, onDismiss: { exportURL = nil }) {
                #if canImport(UIKit)
                if let url = exportURL {
                    ActivityView(activityItems: [url])
                }
                #else
                Text("当前平台不支持分享导出")
                    .padding()
                #endif
            }
            .alert("calendar.export_failed".localized, isPresented: $showExportError) {
                Button("ok".localized, role: .cancel) { }
            } message: {
                Text(exportErrorMessage ?? "error.unknown".localized)
            }
            .alert("calendar.sync_failed".localized, isPresented: $showCalendarSyncError) {
                Button("ok".localized, role: .cancel) { }
            } message: {
                Text(calendarSyncError ?? "error.unknown".localized)
            }
        }
    }
    
    private func setActiveSchedule(_ schedule: Schedule) {
        let targetScheduleId = schedule.id
        
        // 获取所有课表的 ID 列表，用于重新查询
        _ = schedules.map { $0.id }
        
        // 通过 FetchDescriptor 查询所有课表，确保获得数据库中的最新对象
        do {
            let descriptor = FetchDescriptor<Schedule>()
            if let allSchedules = try? modelContext.fetch(descriptor) {
                // 将所有课表设为非活跃
                for s in allSchedules {
                    if s.isActive {
                        s.isActive = false
                    }
                }
                
                // 查找目标课表并激活
                if let targetSchedule = allSchedules.first(where: { $0.id == targetScheduleId }) {
                    targetSchedule.isActive = true
                } else {
                    // 降级：直接修改传入的 schedule 对象
                    schedule.isActive = true
                }
            }
            
            // 保存所有更改
            try modelContext.save()
            
            // 更新Widget数据 - 获取新活跃课表的今天课程
            updateWidgetWithSchedule(schedule)
        } catch {
            // 静默处理错误
        }
        
        // 提供触觉反馈
        #if os(iOS)
        let success = UINotificationFeedbackGenerator()
        success.notificationOccurred(.success)
        #endif
        
        syncCalendarIfNeeded(activeSchedule: schedule)
    }
    
    private func deleteSchedule(_ schedule: Schedule) {
        // 同时删除关联的课程
        let scheduleId = schedule.id
        let descriptor = FetchDescriptor<Course>(
            predicate: #Predicate { $0.scheduleId == scheduleId }
        )
        
        if let courses = try? modelContext.fetch(descriptor) {
            for course in courses {
                // 移除课程通知
                Task {
                    for week in course.weeks {
                        let notificationId = "\(course.id)_week\(week)"
                        await NotificationHelper.removeCourseNotification(courseId: notificationId)
                    }
                }
                modelContext.delete(course)
            }
        }
        
        modelContext.delete(schedule)
    }

    private func exportSchedule(_ schedule: Schedule) {
        guard !isExporting else { return }
        isExporting = true
        Task {
            do {
                let scheduleId = schedule.id
                let descriptor = FetchDescriptor<Course>(
                    predicate: #Predicate { $0.scheduleId == scheduleId }
                )
                let courses = try modelContext.fetch(descriptor)
                let ics = ICSConverter.export(schedule: schedule, courses: courses, settings: settings)
                guard !ics.isEmpty else { throw NSError(domain: "EduPal", code: -10, userInfo: [NSLocalizedDescriptionKey: "导出结果为空"]) }
                let fileName = schedule.name.replacingOccurrences(of: " ", with: "_") + ".ics"
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                try ics.data(using: .utf8)?.write(to: url)
                await MainActor.run {
                    exportURL = url
                    showShareSheet = true
                }
            } catch {
                await MainActor.run {
                    exportErrorMessage = error.localizedDescription
                    showExportError = true
                }
            }
            await MainActor.run { isExporting = false }
        }
    }
    
    private func updateWidgetWithSchedule(_ schedule: Schedule) {
        Task {
            do {
                let scheduleId = schedule.id
                let descriptor = FetchDescriptor<Course>(
                    predicate: #Predicate { $0.scheduleId == scheduleId }
                )
                let courses = try modelContext.fetch(descriptor)
                
                // 获取当前周的课程，供Widget按日筛选
                let helpers = ScheduleHelpers()
                let currentWeekCourses = helpers.coursesForWeek(
                    courses: courses,
                    date: Date(),
                    semesterStartDate: settings.semesterStartDate,
                    weekStartDay: settings.weekStartDay
                )
                
                // 转换为Widget数据格式
                let widgetCourses = currentWeekCourses.map { course -> WidgetDataManager.WidgetCourse in
                    WidgetDataManager.WidgetCourse(
                        name: course.name,
                        teacher: course.teacher,
                        location: course.location,
                        timeSlot: course.timeSlot,
                        duration: course.duration,
                        color: course.color,
                        dayOfWeek: course.dayOfWeek
                    )
                }
                
                // 保存到Widget共享容器并刷新时间线
                await MainActor.run {
                    WidgetDataManager.shared.saveCoursesForWidget(widgetCourses)
                    WidgetCenter.shared.reloadTimelines(ofKind: "CCZUHelperWidget")
                }
            } catch {
                // 静默处理错误
            }
        }
    }
    
    private func syncCalendarIfNeeded(activeSchedule: Schedule) {
        guard settings.enableCalendarSync else { return }
        guard !isSyncingCalendar else { return }
        isSyncingCalendar = true
        Task {
            do {
                let scheduleId = activeSchedule.id
                let descriptor = FetchDescriptor<Course>(predicate: #Predicate { $0.scheduleId == scheduleId })
                let courses = try modelContext.fetch(descriptor)
                try await CalendarSyncManager.sync(schedule: activeSchedule, courses: courses, settings: settings)
            } catch {
                await MainActor.run {
                    calendarSyncError = error.localizedDescription
                    showCalendarSyncError = true
                }
            }
            await MainActor.run { isSyncingCalendar = false }
        }
    }
}

/// 课表行视图
struct ScheduleRow: View {
    let schedule: Schedule
    var onExport: (() -> Void)? = nil
    var onSync: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(schedule.name)
                        .font(.headline)
                    
                    if schedule.isActive {
                        Text("manage_schedules.current_badge".localized)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
                
                Text(schedule.termName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text("manage_schedules.import_time".localized(with: schedule.createdAt.formatted(date: .abbreviated, time: .shortened)))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                onExport?()
            } label: {
                Label("calendar.export_to_ics".localized, systemImage: "square.and.arrow.up")
            }
            Button {
                onSync?()
            } label: {
                Label("calendar.sync_to_system".localized, systemImage: "calendar")
            }
        }
    }
}

/// 导入课表视图
struct ImportScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    
    @Query(sort: \Schedule.createdAt, order: .reverse) private var schedules: [Schedule]
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showICSImporter = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)
                
                Text("import_schedule.title".localized)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("import_schedule.description".localized)
                    .foregroundStyle(.secondary)
                
                if settings.isLoggedIn {
                    Button(action: importFromServer) {
                        Label {
                            Text("import_schedule.from_server".localized)
                        } icon: {
                            ZStack {
                                Image(systemName: "arrow.down.circle")
                                    .opacity(isLoading ? 0 : 1)
                                
                                if isLoading {
                                    ProgressView()
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .applyPrimaryButtonStyle()
                    .controlSize(.large)
                    .buttonBorderShape(.automatic)
                    .fontWeight(.medium)
                    .disabled(isLoading)
                    .padding(.horizontal)
                } else {
                    VStack(spacing: 12) {
                        Text("import_schedule.please_login".localized)
                            .foregroundStyle(.secondary)
                        
                        Button {
                            dismiss()
                            // 触发登录弹窗 - 这里可以通过通知或其他方式实现
                        } label: {
                            Text("import_schedule.go_login".localized)
                                .frame(maxWidth: .infinity)
                        }
                        .applyPrimaryButtonStyle()
                        .controlSize(.large)
                        .buttonBorderShape(.automatic)
                        .fontWeight(.medium)
                        .padding(.horizontal)
                    }
                }
                
                Divider()
                    .padding(.vertical)
                
                Button(action: addDemoSchedule) {
                    Label("import_schedule.add_demo".localized, systemImage: "plus.rectangle.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .applyPrimaryButtonStyle()
                .tint(.secondary)
                .controlSize(.large)
                .buttonBorderShape(.automatic)
                .fontWeight(.medium)
                .padding(.horizontal)

                Button(action: { showICSImporter = true }) {
                    Label("calendar.import_from_ics".localized, systemImage: "doc.text.magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .applyPrimaryButtonStyle()
                .controlSize(.large)
                .buttonBorderShape(.automatic)
                .fontWeight(.medium)
                .padding(.horizontal)
                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle("import_schedule.title".localized)
            #if os(iOS) || os(tvOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
            }
            .alert("import_schedule.error".localized, isPresented: $showError) {
                Button("ok".localized, role: .cancel) { }
            } message: {
                Text(errorMessage ?? "error.unknown".localized)
            }
            .fileImporter(
                isPresented: $showICSImporter,
                allowedContentTypes: [UTType(filenameExtension: "ics") ?? .data],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        importFromICS(url)
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func importFromServer() {
        guard settings.isLoggedIn else {
            errorMessage = "import_schedule.please_login_error".localized
            showError = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                // 使用 CCZUKit 从服务器获取课表
                guard let username = settings.username else {
                    throw NSError(domain: "EduPal", code: -1, userInfo: [NSLocalizedDescriptionKey: "import_schedule.not_logged_in".localized])
                }
                
                // 从 Keychain 读取密码
                guard let password = KeychainHelper.read(service: KeychainServices.localKeychain, account: username) else {
                    throw NSError(domain: "EduPal", code: -1, userInfo: [NSLocalizedDescriptionKey: "import_schedule.credentials_missing".localized])
                }
                
                let client = DefaultHTTPClient(username: username, password: password)
                
                // 登录 SSO
                _ = try await client.ssoUniversalLogin()
                
                // 创建教务系统应用实例
                let app = JwqywxApplication(client: client)
                _ = try await app.login()
                
                // 获取当前课表
                let scheduleData = try await app.getCurrentClassSchedule()
                
                // 解析课表
                let parsedCourses = CalendarParser.parseWeekMatrix(scheduleData)
                
                // 使用CourseTimeCalculator处理课程时间
                let timeCalculator = CourseTimeCalculator()
                let courses = timeCalculator.generateCourses(
                    from: parsedCourses,
                    scheduleId: UUID().uuidString  // 临时ID, 会被覆盖
                )
                
                await MainActor.run {
                    // 将所有其他课表设为非活跃
                    let scheduleDescriptor = FetchDescriptor<Schedule>()
                    if let allSchedules = try? modelContext.fetch(scheduleDescriptor) {
                        for s in allSchedules {
                            if s.isActive {
                                s.isActive = false
                            }
                        }
                    }
                    
                    // 创建新课表
                    let schedule = Schedule(
                        name: "import_schedule.server_schedule_name".localized,
                        termName: extractTermName(),
                        isActive: true
                    )
                    modelContext.insert(schedule)
                    
                    // 插入课程 - 已包含精确的时间信息
                    for course in courses {
                        course.scheduleId = schedule.id  // 更新为正确的课表ID
                        modelContext.insert(course)
                    }
                    
                    // 保存模型上下文
                    do {
                        try modelContext.save()
                    } catch {
                        // 静默处理错误
                    }
                    
                    // 保存课程到 App Intents 缓存
                    if let username = settings.username {
                        AppIntentsDataCache.shared.saveCourses(courses, for: username)
                    }
                    
                    // 安排课程通知
                    Task {
                        await NotificationHelper.scheduleAllCourseNotifications(courses: courses, settings: settings)
                    }
                    
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    
                    // 触发错误震动
                    triggerErrorHaptic()
                    
                    let errorDesc = error.localizedDescription.lowercased()
                    if errorDesc.contains("authentication") || errorDesc.contains("认证") {
                        errorMessage = "error.authentication_failed".localized
                    } else if errorDesc.contains("network") || errorDesc.contains("网络") {
                        errorMessage = "error.network_failed".localized
                    } else if errorDesc.contains("timeout") || errorDesc.contains("超时") {
                        errorMessage = "error.timeout".localized
                    } else {
                        errorMessage = "import_schedule.import_failed".localized(with: error.localizedDescription)
                    }
                    
                    showError = true
                }
            }
        }
    }

    private func importFromICS(_ url: URL) {
        isLoading = true
        Task {
            let scopedURL = url
            #if os(iOS)
            let needsAccess = scopedURL.startAccessingSecurityScopedResource()
            #endif
            defer {
                #if os(iOS)
                if needsAccess { scopedURL.stopAccessingSecurityScopedResource() }
                #endif
            }
            do {
                let result = try ICSConverter.importICS(from: scopedURL, settings: settings)
                await MainActor.run {
                    let schedule = Schedule(
                        name: result.scheduleName,
                        termName: result.termName,
                        isActive: true
                    )
                    modelContext.insert(schedule)
                    // 将其他课表设为非活跃
                    let descriptor = FetchDescriptor<Schedule>()
                    if let allSchedules = try? modelContext.fetch(descriptor) {
                        for s in allSchedules where s.id != schedule.id {
                            s.isActive = false
                        }
                    }
                    // 插入课程
                    var insertedCourses: [Course] = []
                    for template in result.courses {
                        let course = template.toCourse(scheduleId: schedule.id)
                        insertedCourses.append(course)
                        modelContext.insert(course)
                    }
                    settings.semesterStartDate = result.semesterStartDate
                    Task {
                        await NotificationHelper.scheduleAllCourseNotifications(courses: insertedCourses, settings: settings)
                        if settings.enableCalendarSync {
                            do {
                                try await CalendarSyncManager.sync(schedule: schedule, courses: insertedCourses, settings: settings)
                            } catch {
                                await MainActor.run {
                                    errorMessage = error.localizedDescription
                                    showError = true
                                }
                            }
                        }
                    }
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    /// 触发错误震动反馈
    private func triggerErrorHaptic() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        #endif
    }
    
    // 从课表数据中提取学期名称
    private func extractTermName() -> String {
        // 尝试从数据中提取学期信息, 如果失败则使用默认值
        let currentYear = Calendar.current.component(.year, from: Date())
        let currentMonth = Calendar.current.component(.month, from: Date())
        let semester = currentMonth >= 2 && currentMonth <= 7 ? "春季" : "秋季"
        return "\(currentYear)年\(semester)学期"
    }
    
    private func addDemoSchedule() {
        // 将所有其他课表设为非活跃
        for s in schedules {
            s.isActive = false
        }
        
        // 创建示例课表
        let schedule = Schedule(
            name: "import_schedule.demo_schedule_name".localized,
            termName: "import_schedule.demo_term_name".localized,
            isActive: true
        )
        modelContext.insert(schedule)
        
        // 添加示例课程
        let demoCourses = [
            (name: "course.higher_math".localized, teacher: "teacher.prof_zhang".localized, location: "location.building_a101".localized, dayOfWeek: 1, timeSlot: 1),
            (name: "course.college_english".localized, teacher: "teacher.teacher_li".localized, location: "location.building_b203".localized, dayOfWeek: 2, timeSlot: 3),
            (name: "course.programming".localized, teacher: "teacher.prof_wang".localized, location: "location.building_c301".localized, dayOfWeek: 3, timeSlot: 5),
            (name: "course.linear_algebra".localized, teacher: "teacher.teacher_zhao".localized, location: "location.building_a205".localized, dayOfWeek: 4, timeSlot: 1),
            (name: "course.college_physics".localized, teacher: "teacher.prof_qian".localized, location: "location.building_d102".localized, dayOfWeek: 5, timeSlot: 3),
        ]
        
        // 高对比度颜色池
        let highContrastColors = [
            "#FF6B6B",  // 鲜红
            "#4ECDC4",  // 青绿
            "#45B7D1",  // 天蓝
            "#96CEB4",  // 薄荷绿
            "#FFD93D",  // 金黄
            "#FF9E9E",  // 浅红
            "#A8D8EA",  // 浅蓝
            "#FF90EE",  // 热粉
            "#98FB98",  // 浅绿
            "#FFA500",  // 橙色
            "#87CEEB",  // 天空蓝
            "#F08080",  // 浅珊瑚红
            "#20B2AA",  // 深青色
            "#FFB6C1",  // 浅粉
            "#3CB371",  // 中海绿
            "#DDA0DD",  // 梅紫
            "#F7DC6F",  // 明黄
            "#BB8FCE",  // 紫罗兰
            "#85C1E9",  // 淡蓝
            "#F8B88B",  // 沙色
        ]
        
        var insertedCourses: [Course] = []
        for (index, demo) in demoCourses.enumerated() {
            let course = Course(
                name: demo.name,
                teacher: demo.teacher,
                location: demo.location,
                weeks: Array(1...16),
                dayOfWeek: demo.dayOfWeek,
                timeSlot: demo.timeSlot,
                color: highContrastColors[index % highContrastColors.count],
                scheduleId: schedule.id
            )
            modelContext.insert(course)
            insertedCourses.append(course)
        }
        
        // 保存课程到 App Intents 缓存
        if let username = settings.username {
            AppIntentsDataCache.shared.saveCourses(insertedCourses, for: username)
        }
        
        // 安排课程通知
        Task {
            await NotificationHelper.scheduleAllCourseNotifications(
                courses: insertedCourses,
                settings: settings
            )
        }
        
        dismiss()
    }
}

#Preview {
    ManageSchedulesView()
        .environment(AppSettings())
        .modelContainer(for: [Schedule.self, Course.self], inMemory: true)
}

#if canImport(UIKit)
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

private extension View {
    @ViewBuilder
    func applyPrimaryButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            #if os(visionOS)
            self.buttonStyle(.borderedProminent)
            #else
            self.buttonStyle(.glassProminent)
            #endif
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }
}
