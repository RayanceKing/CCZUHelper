//
//  ManageSchedulesView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/11/30.
//

import SwiftUI
import SwiftData
import CCZUKit

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
                        ScheduleRow(schedule: schedule)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    scheduleToDelete = schedule
                                    showDeleteAlert = true
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                                
                                Button {
                                    setActiveSchedule(schedule)
                                } label: {
                                    Label("设为当前", systemImage: "checkmark.circle")
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
        }
    }
    
    private func setActiveSchedule(_ schedule: Schedule) {
        // 将所有课表设为非活跃
        for s in schedules {
            s.isActive = false
        }
        // 将选中的课表设为活跃
        schedule.isActive = true
    }
    
    private func deleteSchedule(_ schedule: Schedule) {
        // 同时删除关联的课程
        let scheduleId = schedule.id
        let descriptor = FetchDescriptor<Course>(
            predicate: #Predicate { $0.scheduleId == scheduleId }
        )
        
        if let courses = try? modelContext.fetch(descriptor) {
            for course in courses {
                modelContext.delete(course)
            }
        }
        
        modelContext.delete(schedule)
    }
}

/// 课表行视图
struct ScheduleRow: View {
    let schedule: Schedule
    
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
    }
}

/// 导入课表视图
struct ImportScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    
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
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                            } else {
                                Image(systemName: "arrow.down.circle")
                            }
                            Text("import_schedule.from_server".localized)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isLoading)
                    .padding(.horizontal)
                } else {
                    VStack(spacing: 12) {
                        Text("import_schedule.please_login".localized)
                            .foregroundStyle(.secondary)
                        
                        Button("import_schedule.go_login".localized) {
                            dismiss()
                            // 触发登录弹窗 - 这里可以通过通知或其他方式实现
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                Divider()
                    .padding(.vertical)
                
                Button(action: addDemoSchedule) {
                    HStack {
                        Image(systemName: "plus.rectangle.on.rectangle")
                        Text("import_schedule.add_demo".localized)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
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
                    throw NSError(domain: "CCZUHelper", code: -1, userInfo: [NSLocalizedDescriptionKey: "import_schedule.not_logged_in".localized])
                }
                
                // 从 Keychain 读取密码
                guard let password = KeychainHelper.read(service: "com.cczu.helper", account: username) else {
                    throw NSError(domain: "CCZUHelper", code: -1, userInfo: [NSLocalizedDescriptionKey: "import_schedule.credentials_missing".localized])
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
                    scheduleId: UUID().uuidString  // 临时ID，会被覆盖
                )
                
                await MainActor.run {
                    // 首先删除所有已有的活跃课表的课程
                    let courseDescriptor = FetchDescriptor<Course>()
                    if let allCourses = try? modelContext.fetch(courseDescriptor) {
                        for course in allCourses {
                            modelContext.delete(course)
                        }
                    }
                    
                    // 创建新课表
                    let schedule = Schedule(
                        name: "import_schedule.server_schedule_name".localized,
                        termName: extractTermName(),
                        isActive: true
                    )
                    modelContext.insert(schedule)
                    
                    // 将所有其他课表设为非活跃
                    let descriptor = FetchDescriptor<Schedule>()
                    if let allSchedules = try? modelContext.fetch(descriptor) {
                        for s in allSchedules where s.id != schedule.id {
                            s.isActive = false
                        }
                    }
                    
                    // 插入课程 - 已包含精确的时间信息
                    for course in courses {
                        course.scheduleId = schedule.id  // 更新为正确的课表ID
                        modelContext.insert(course)
                    }
                    
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "import_schedule.import_failed".localized(with: error.localizedDescription)
                    showError = true
                }
            }
        }
    }
    
    // 从课表数据中提取学期名称
    private func extractTermName() -> String {
        // 尝试从数据中提取学期信息，如果失败则使用默认值
        let currentYear = Calendar.current.component(.year, from: Date())
        let currentMonth = Calendar.current.component(.month, from: Date())
        let semester = currentMonth >= 2 && currentMonth <= 7 ? "春季" : "秋季"
        return "\(currentYear)年\(semester)学期"
    }
    
    private func addDemoSchedule() {
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
        
        for (index, demo) in demoCourses.enumerated() {
            let course = Course(
                name: demo.name,
                teacher: demo.teacher,
                location: demo.location,
                weeks: Array(1...16),
                dayOfWeek: demo.dayOfWeek,
                timeSlot: demo.timeSlot,
                color: Color.courseColorHexes[index % Color.courseColorHexes.count],
                scheduleId: schedule.id
            )
            modelContext.insert(course)
        }
        
        dismiss()
    }
}

#Preview {
    ManageSchedulesView()
        .environment(AppSettings())
        .modelContainer(for: [Schedule.self, Course.self], inMemory: true)
}
