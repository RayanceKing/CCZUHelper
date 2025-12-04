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
                        Label("暂无课表", systemImage: "calendar.badge.exclamationmark")
                    } description: {
                        Text("点击右上角按钮导入课表")
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
            .navigationTitle("管理课表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showImportSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("删除课表", isPresented: $showDeleteAlert, presenting: scheduleToDelete) { schedule in
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    deleteSchedule(schedule)
                }
            } message: { schedule in
                Text("确定要删除「\(schedule.name)」吗？此操作不可撤销。")
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
                        Text("当前")
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
                
                Text("导入时间: \(schedule.createdAt.formatted(date: .abbreviated, time: .shortened))")
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
                
                Text("导入课表")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("从教务系统导入您的课程表")
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
                            Text("从教务系统导入")
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
                        Text("请先登录账号")
                            .foregroundStyle(.secondary)
                        
                        Button("前往登录") {
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
                        Text("添加示例课表")
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
            .navigationTitle("导入课表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .alert("错误", isPresented: $showError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "未知错误")
            }
        }
    }
    
    private func importFromServer() {
        guard settings.isLoggedIn else {
            errorMessage = "请先登录"
            showError = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                // 使用 CCZUKit 从服务器获取课表
                guard let username = settings.username else {
                    throw NSError(domain: "CCZUHelper", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录"])
                }
                
                // 从 Keychain 读取密码
                guard let password = KeychainHelper.read(service: "com.cczu.helper", account: username) else {
                    throw NSError(domain: "CCZUHelper", code: -1, userInfo: [NSLocalizedDescriptionKey: "密码丢失，请重新登录"])
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
                    // 创建新课表
                    let schedule = Schedule(
                        name: "教务系统课表",
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
                    errorMessage = "导入失败: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    /// 合并连续的课程节次以计算时长
    /// - Parameter courses: 原始解析的课程列表
    /// - Returns: 合并后的课程列表，包含正确的时长
    private func mergeConsecutiveCourses(_ courses: [ParsedCourse]) -> [CourseInfo] {
        var merged: [CourseInfo] = []
        
        // 按照 dayOfWeek 和 name 分组
        var grouped: [String: [ParsedCourse]] = [:]
        for course in courses {
            let key = "\(course.dayOfWeek)_\(course.name)_\(course.location)"
            if grouped[key] == nil {
                grouped[key] = []
            }
            grouped[key]?.append(course)
        }
        
        // 处理每组课程，合并连续节次
        for (_, groupedCourses) in grouped {
            // 按时间节次排序
            let sorted = groupedCourses.sorted { $0.timeSlot < $1.timeSlot }
            
            // 合并连续的节次
            var i = 0
            while i < sorted.count {
                let startCourse = sorted[i]
                var duration = 1
                
                // 查找连续的节次
                while i + duration < sorted.count {
                    let nextCourse = sorted[i + duration]
                    // 检查是否是连续的节次（允许相邻节次）
                    if nextCourse.timeSlot == startCourse.timeSlot + duration {
                        duration += 1
                    } else {
                        break
                    }
                }
                
                // 创建合并后的课程信息
                let mergedCourse = CourseInfo(
                    name: startCourse.name,
                    teacher: startCourse.teacher,
                    location: startCourse.location,
                    weeks: startCourse.weeks,
                    dayOfWeek: startCourse.dayOfWeek,
                    timeSlot: startCourse.timeSlot,
                    duration: duration
                )
                merged.append(mergedCourse)
                
                i += duration
            }
        }
        
        return merged
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
            name: "示例课表",
            termName: "2025年春季学期",
            isActive: true
        )
        modelContext.insert(schedule)
        
        // 添加示例课程
        let demoCourses = [
            (name: "高等数学", teacher: "张教授", location: "教学楼A101", dayOfWeek: 1, timeSlot: 1),
            (name: "大学英语", teacher: "李老师", location: "外语楼B203", dayOfWeek: 2, timeSlot: 3),
            (name: "程序设计", teacher: "王教授", location: "计算机楼C301", dayOfWeek: 3, timeSlot: 5),
            (name: "线性代数", teacher: "赵老师", location: "教学楼A205", dayOfWeek: 4, timeSlot: 1),
            (name: "大学物理", teacher: "钱教授", location: "理学楼D102", dayOfWeek: 5, timeSlot: 3),
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

