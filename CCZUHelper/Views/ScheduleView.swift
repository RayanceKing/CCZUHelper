//
//  ScheduleView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/11/30.
//

import SwiftUI
import SwiftData

private extension Notification.Name {
    static let scheduleExternalDateSelected = Notification.Name("ScheduleExternalDateSelected")
    static let scheduleCurrentDateDidChange = Notification.Name("ScheduleCurrentDateDidChange")
}

// MARK: - 课程表视图
struct ScheduleView: View {
    // MARK: - 环境 & 查询
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    
    @Query(sort: \Course.dayOfWeek) private var allCourses: [Course]
    @Query(sort: \Schedule.createdAt) private var schedules: [Schedule]
    
    // 只显示活跃课表的课程
    private var courses: [Course] {
        // 首先查找活跃课表
        let activeSchedules = schedules.filter { $0.isActive }
        
        if let activeSchedule = activeSchedules.first {
//            print("📚 Loading courses for active schedule: \(activeSchedule.name) (ID: \(activeSchedule.id))")
//            print("   📊 Searching in \(allCourses.count) total courses...")
            
            let filtered = allCourses.filter { course in
                let matches = course.scheduleId == activeSchedule.id
                if !matches && allCourses.count > 0 && allCourses.count <= 5 {
                    // 调试：如果课程很少，打印每一个的 scheduleId
//                    print("   ❌ Course '\(course.name)' scheduleId '\(course.scheduleId)' doesn't match schedule id '\(activeSchedule.id)'")
                }
                return matches
            }
            
            return filtered
        } else {
            // 如果没有活跃课表，尝试使用第一个课表
            if let firstSchedule = schedules.first {
                return allCourses.filter { $0.scheduleId == firstSchedule.id }
            }
            return []
        }
    }
    
    // MARK: - 状态属性
    @State private var selectedDate: Date = Date()
    @State private var baseDate: Date = Date()
    @State private var weekOffset: Int = 0
    @State private var tabSelection: Int = 0
    @State private var scrollProxy: ScrollViewProxy?
    
    // MARK: - 工作表状态
    @State private var showDatePicker = false
    @State private var showLoginSheet = false
    @State private var showManageSchedules = false
    @State private var showImagePicker = false
    @State private var showUserSettings = false
    
    // MARK: - 常量
    private let helpers = ScheduleHelpers()
    private let calendar = Calendar.current
    private let timeAxisWidth: CGFloat = 50
    private let headerHeight: CGFloat = 60
    private let widgetDataManager = WidgetDataManager.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    // MARK: - Body
    var body: some View {
        #if os(macOS)
        // macOS 上不使用 NavigationStack（已在 NavigationSplitView 中）
        mainContent
        #else
        NavigationStack {
            mainContent
        }
        #endif
    }
    
    private var mainContent: some View {
            GeometryReader { geometry in
                scheduleContentView(geometry: geometry)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .toolbar { toolbarContent }
            }
            .background(alignment: .center) {
                // 背景图必须放在最底层并忽略所有安全区，避免顶部/底部黑边
                fullScreenBackgroundImage
                    .allowsHitTesting(false)
            }
            .ignoresSafeArea(.container, edges: .bottom)
            #if !os(macOS)
            .toolbarBackground(settings.backgroundImageEnabled ? .hidden : .visible, for: .navigationBar)
            #endif
            .onAppear { handleViewAppear() }
            .sheet(isPresented: $showDatePicker) { datePickerSheet }
            .sheet(isPresented: $showLoginSheet) { loginSheet }
            .sheet(isPresented: $showManageSchedules) { manageSchedulesSheet }
            #if os(iOS)
            .sheet(isPresented: $showImagePicker) { imagePickerSheet }
            #endif
            .sheet(isPresented: $showUserSettings) { userSettingsSheet }
            .onChange(of: selectedDate) { oldValue, newValue in
                handleSelectedDateChange(oldValue, newValue)
                #if os(macOS)
                NotificationCenter.default.post(
                    name: .scheduleCurrentDateDidChange,
                    object: nil,
                    userInfo: ["date": newValue]
                )
                #endif
            }
            .onChange(of: settings.weekStartDay) { _, newValue in
                handleWeekStartDayChange(newValue)
            }
            .onChange(of: schedules) { _, _ in
                // 当课表列表变化时（包括切换活跃课表），重新加载课程数据
                print("🔄 Schedule list changed, reloading courses...")
                print("📋 Active schedules: \(schedules.filter { $0.isActive }.map { $0.name }.joined(separator: ", "))")
                print("📊 Total courses now visible: \(courses.count)")
                resetToTodayIfNeeded()
            }
            .onChange(of: courses) { oldValue, newValue in
                handleCoursesChange(oldValue, newValue)
            }
            .onChange(of: settings.courseNotificationTime) { _, newValue in
                handleNotificationTimeChange(newValue)
            }
            .onChange(of: settings.enableCourseNotification) { oldValue, newValue in
                handleNotificationToggle(oldValue, newValue)
            }
            #if os(macOS)
            .onReceive(NotificationCenter.default.publisher(for: .scheduleExternalDateSelected)) { notification in
                guard let date = notification.userInfo?["date"] as? Date else { return }
                if !calendar.isDate(selectedDate, inSameDayAs: date) {
                    selectedDate = date
                }
            }
            #endif
    }
    
    // MARK: - View Builders
    
    /// 背景图片视图
    @ViewBuilder
    private var fullScreenBackgroundImage: some View {
        #if os(macOS)
        EmptyView()
        #else
        if settings.backgroundImageEnabled,
           let imagePath = settings.backgroundImagePath,
           let platformImage = helpers.loadImage(from: imagePath) {
            Image(uiImage: platformImage)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea(.all, edges: .all)
                .opacity(settings.backgroundOpacity)
        }
        #endif
    }

    /// 课程表内容视图
    private func scheduleContentView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            weekdayHeader(width: geometry.size.width)
            weeklyScheduleTabView(geometry: geometry)
        }
        .onChange(of: weekOffset) { oldValue, newValue in
            handleWeekOffsetChange(oldValue, newValue)
        }
    }
    
    /// 星期标题行
    private func weekdayHeader(width: CGFloat) -> some View {
        WeekdayHeader(
            width: width,
            timeAxisWidth: timeAxisWidth,
            headerHeight: headerHeight,
            weekDates: helpers.getWeekDates(
                for: helpers.getDateForWeekOffset(weekOffset, baseDate: baseDate),
                weekStartDay: settings.weekStartDay
            ),
            settings: settings,
            helpers: helpers
        )
    }
    
    /// 周课程表TabView
    private func weeklyScheduleTabView(geometry: GeometryProxy) -> some View {
        #if os(macOS)
        scheduleScrollView(
            width: geometry.size.width,
            height: geometry.size.height,
            weekOffset: weekOffset
        )
        .id(weekOffset)
        .transition(.opacity)
        #else
        TabView(selection: $tabSelection) {
            ForEach(-52...52, id: \.self) { offset in
                scheduleScrollView(
                    width: geometry.size.width,
                    height: geometry.size.height,
                    weekOffset: offset
                )
                .tag(offset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onChange(of: tabSelection) { _, newValue in
            if newValue != weekOffset { weekOffset = newValue }
        }
        #endif
    }
    
    /// 单周课程表滚动视图
    private func scheduleScrollView(width: CGFloat, height: CGFloat, weekOffset: Int) -> some View {
        ScrollViewReader { proxy in
            ScrollView([.vertical, .horizontal], showsIndicators: false) {
                // 保证每页内容至少填满可用高度，避免 TabView 在 iPad 上垂直居中
                scheduleGrid(width: width, height: height, weekOffset: weekOffset)
                    .id("schedule_\(weekOffset)")
                    .frame(minHeight: height, maxHeight: .infinity, alignment: .topLeading)
                    // 在 iPad (regular 横向尺寸) 增加少量顶部间距，防止内容被日期栏微遮挡
                    .padding(.top, horizontalSizeClass == .regular ? 8 : 0)
            }
            .onAppear { scrollProxy = proxy }
        }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        #if os(macOS)
        ToolbarItem(placement: .navigation) {
            addScheduleButton
        }
        
        ToolbarItem(placement: .principal) {
            datePickerButton
        }
        #else
        ToolbarItem(placement: .navigation) {
            datePickerButton
        }
        #endif
        
        ToolbarItemGroup(placement: .primaryAction) {
            #if os(macOS)
            Button {
                withAnimation { weekOffset -= 1 }
            } label: {
                Label("Previous Week", systemImage: "chevron.left")
            }
            .keyboardShortcut(.leftArrow, modifiers: [])
            
            Button {
                withAnimation { weekOffset += 1 }
            } label: {
                Label("Next Week", systemImage: "chevron.right")
            }
            .keyboardShortcut(.rightArrow, modifiers: [])
            #endif
            
            todayButton
            #if os(macOS)
            UserMenuButton(
                showUserSettings: settings.isLoggedIn ? $showUserSettings : $showLoginSheet,
                isAuthenticated: settings.isLoggedIn
            )
            #else
            UserMenuButton(showUserSettings: $showUserSettings, isAuthenticated: settings.isLoggedIn)
            #endif
        }
    }
    
    /// 日期选择按钮
    private var datePickerButton: some View {
        Button(action: { showDatePicker = true }) {
            VStack(alignment: .leading, spacing: 2) {
                Text(helpers.yearMonthString(for: selectedDate))
                    .font(.headline)
                    .fontWeight(.bold)
                Text("schedule.week.format".localized(
                    with: helpers.currentWeekNumber(
                        for: selectedDate,
                        schedules: schedules,
                        semesterStartDate: settings.semesterStartDate,
                        weekStartDay: settings.weekStartDay
                    )
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
    
    /// 添加/管理课表按钮
    private var addScheduleButton: some View {
        Button {
            showManageSchedules = true
        } label: {
            Image(systemName: "plus")
        }
        .help("manage_schedules.title".localized)
    }
    
    /// 返回今天按钮
    private var todayButton: some View {
        Button("schedule.today".localized) {
            withAnimation {
                resetToToday()
            }
        }
    }
    
    // MARK: - 课程表网格
    
    private func scheduleGrid(width: CGFloat, height: CGFloat, weekOffset: Int) -> some View {
        let configuration = GridConfiguration(
            width: width,
            timeAxisWidth: timeAxisWidth,
            settings: settings
        )
        
        let targetDate = helpers.getDateForWeekOffset(weekOffset, baseDate: baseDate)
        let weekCourses = helpers.coursesForWeek(
            courses: courses,
            date: targetDate,
            semesterStartDate: settings.semesterStartDate,
            weekStartDay: settings.weekStartDay
        )
        let currentViewWeek = helpers.currentWeekNumber(
            for: targetDate,
            schedules: schedules,
            semesterStartDate: settings.semesterStartDate,
            weekStartDay: settings.weekStartDay
        )
        
        // 更新Widget数据
        updateWidgetDataIfNeeded(weekOffset: weekOffset, weekCourses: weekCourses)
        
        return HStack(alignment: .top, spacing: 0) {
            if settings.showTimeRuler {
                timeAxis(configuration: configuration)
            }
            ZStack(alignment: .topLeading) {
                if settings.showGridLines {
                    ScheduleGridLines(
                        dayWidth: configuration.dayWidth,
                        hourHeight: configuration.hourHeight,
                        totalHours: configuration.totalHours,
                        settings: settings
                    )
                }
                
                // 按天分组课程
                let coursesByDay = Dictionary(grouping: weekCourses) { $0.dayOfWeek }
                ForEach(Array(coursesByDay.keys).sorted(), id: \.self) { day in
                    let dayCourses = coursesByDay[day] ?? []
                    let overlapMap = computeOverlapColumns(for: dayCourses, settings: settings)
                    ForEach(dayCourses, id: \.id) { course in
                        let info = overlapMap[ObjectIdentifier(course)] ?? OverlapInfo(column: 0, total: 1)
                        CourseBlock(
                            course: course,
                            dayWidth: configuration.dayWidth,
                            hourHeight: configuration.hourHeight,
                            settings: settings,
                            helpers: helpers,
                            currentViewWeek: currentViewWeek,
                            overlapColumn: info.column,
                            totalColumns: info.total
                        )
                    }
                }
                
                if weekOffset == 0 {
                    CurrentTimeLine(
                        dayWidth: configuration.dayWidth,
                        hourHeight: configuration.hourHeight,
                        totalWidth: configuration.dayWidth * 7,
                        settings: settings
                    )
                }
            }
            .frame(height: configuration.gridTotalHeight)
        }
        .frame(
            width: configuration.dayWidth * 7 + (settings.showTimeRuler ? configuration.timeAxisWidth : 0),
            height: configuration.gridTotalHeight,
            alignment: .topLeading
        )
    }
    
    /// 时间轴
    private func timeAxis(configuration: GridConfiguration) -> some View {
        TimeAxis(
            timeAxisWidth: configuration.timeAxisWidth,
            hourHeight: configuration.hourHeight,
            settings: settings
        )
    }
    
    // MARK: - 工作表视图
    
    private var datePickerSheet: some View {
        DatePickerSheet(selectedDate: $selectedDate)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
    }
    
    private var loginSheet: some View {
        #if os(macOS)
        MacTeachingLoginModalView()
            .environment(settings)
        #else
        LoginView()
            .environment(settings)
        #endif
    }
    
    private var manageSchedulesSheet: some View {
        ManageSchedulesView()
            .environment(settings)
    }
    
    #if os(iOS)
    private var imagePickerSheet: some View {
        ImagePickerView { url in
            settings.backgroundImagePath = url?.path
            settings.backgroundImageEnabled = (url != nil)
        }
    }
    #endif
    
    private var userSettingsSheet: some View {
        #if os(macOS)
        MacTeachingUserInfoSheet()
            .environment(settings)
        #else
        UserSettingsView(
            showManageSchedules: $showManageSchedules,
            showLoginSheet: $showLoginSheet,
            showImagePicker: $showImagePicker
        )
        .environment(settings)
        #endif
    }
    
    // MARK: - 事件处理器
    
    /// 视图出现时的处理
    private func handleViewAppear() {
        // 确保有活跃课表
        ensureActiveSchedule()
        
        resetToTodayIfNeeded()
        initializeCourseNotifications()
        refreshNextCourseLiveActivity()
    }
    
    /// 确保至少有一个活跃课表
    private func ensureActiveSchedule() {
        let hasActiveSchedule = schedules.contains { $0.isActive }
        if !hasActiveSchedule && !schedules.isEmpty {
            print("⚠️ No active schedule found, activating first schedule")
            
            do {
                // 通过 FetchDescriptor 从数据库重新获取，确保数据一致性
                var descriptor = FetchDescriptor<Schedule>()
                descriptor.sortBy = [SortDescriptor(\Schedule.createdAt)]
                
                if let allSchedules = try? modelContext.fetch(descriptor), !allSchedules.isEmpty {
                    let firstSchedule = allSchedules[0]
                    print("   📋 First schedule: \(firstSchedule.name) (ID: \(firstSchedule.id))")
                    
                    // 确保没有其他活跃课表
                    for schedule in allSchedules {
                        if schedule.isActive {
                            schedule.isActive = false
                        }
                    }
                    
                    // 激活第一个课表
                    firstSchedule.isActive = true
                    try modelContext.save()
                    print("✅ Activated first schedule as default (ID: \(firstSchedule.id))")
                }
            } catch {
                print("❌ Failed to activate first schedule: \(error)")
            }
        }
    }
    
    /// 周偏移改变处理
    private func handleWeekOffsetChange(_ oldValue: Int, _ newValue: Int) {
        triggerHapticFeedback()
        // 注意：不要在这里调用 updateSelectedDateForWeekOffset
        // 因为 weekOffset 可能是由用户在 DatePickerSheet 中选择一个不同周的日期触发的
        // selectedDate 应该保持用户选择的确切日期，而不是被"纠正"到该周的开始日期
        if tabSelection != newValue { tabSelection = newValue }
    }
    
    /// 日期选择改变处理
    private func handleSelectedDateChange(_ oldValue: Date, _ newValue: Date) {
        let newOffset = calendar.dateComponents([.weekOfYear], from: baseDate, to: newValue).weekOfYear ?? 0
        
        if newOffset != weekOffset {
            withAnimation {
                weekOffset = newOffset
                tabSelection = newOffset
            }
        }
    }
    
    /// 周开始日改变处理
    private func handleWeekStartDayChange(_ newValue: AppSettings.WeekStartDay) {
        // 强制刷新视图
        let tempOffset = weekOffset
        weekOffset = tempOffset + 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            weekOffset = tempOffset
            tabSelection = tempOffset
        }
        refreshNextCourseLiveActivity()
    }
    
    /// 课程数据改变处理
    private func handleCoursesChange(_ oldValue: [Course], _ newValue: [Course]) {
        Task {
            // 保存课程数据到 App Intents 缓存
            if let username = settings.username {
                AppIntentsDataCache.shared.saveCourses(newValue, for: username)
            }
            
            await NotificationHelper.scheduleAllCourseNotifications(
                courses: newValue,
                settings: settings
            )
            #if os(iOS) && canImport(ActivityKit)
            await NextCourseLiveActivityManager.shared.refresh(courses: newValue, settings: settings)
            #endif
        }
    }
    
    /// 通知时间改变处理
    private func handleNotificationTimeChange(_ newValue: AppSettings.NotificationTime) {
        if settings.enableCourseNotification {
            Task {
                await NotificationHelper.scheduleAllCourseNotifications(
                    courses: courses,
                    settings: settings
                )
            }
        }
    }
    
    /// 通知开关改变处理
    private func handleNotificationToggle(_ oldValue: Bool, _ newValue: Bool) {
        Task {
            if newValue {
                await NotificationHelper.scheduleAllCourseNotifications(
                    courses: courses,
                    settings: settings
                )
            } else {
                await NotificationHelper.removeAllCourseNotifications()
            }
        }
    }
    
    // MARK: - 辅助方法
    
    /// 重置到今天
    private func resetToToday() {
        let now = Date()
        weekOffset = 0
        tabSelection = 0
        baseDate = now
        selectedDate = now
        if horizontalSizeClass == .compact {
            scrollToCurrentTime()
        }
    }
    
    /// 如果需要,重置到今天
    private func resetToTodayIfNeeded() {
        if weekOffset != 0 || !calendar.isDate(baseDate, equalTo: Date(), toGranularity: .day) {
            let now = Date()
            baseDate = now
            selectedDate = now
            weekOffset = 0
        }
    }
    
    /// 初始化课程通知
    private func initializeCourseNotifications() {
        Task {
            await NotificationHelper.requestAuthorizationIfNeeded()
            await NotificationHelper.scheduleAllCourseNotifications(
                courses: courses,
                settings: settings
            )
        }
    }

    private func refreshNextCourseLiveActivity() {
        #if os(iOS) && canImport(ActivityKit)
        Task {
            await NextCourseLiveActivityManager.shared.refresh(courses: courses, settings: settings)
        }
        #endif
    }
    
    /// 更新选中日期以匹配周偏移
    private func updateSelectedDateForWeekOffset(_ offset: Int) {
        selectedDate = helpers.getDateForWeekOffset(offset, baseDate: baseDate)
    }
    
    /// 滚动到当前时间
    private func scrollToCurrentTime() {
        guard let proxy = scrollProxy else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation {
                proxy.scrollTo("schedule_0", anchor: .top)
            }
        }
    }
    
    /// 触发触觉反馈
    private func triggerHapticFeedback() {
        #if os(iOS)
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        #endif
    }
    
    /// 更新Widget数据(当前周全量课程，供Widget按日期筛选)
    private func updateWidgetDataIfNeeded(weekOffset: Int, weekCourses: [Course]) {
        guard weekOffset == 0 else { return }

        let widgetCourses = weekCourses.map { course -> WidgetDataManager.WidgetCourse in
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
        
        DispatchQueue.main.async {
            widgetDataManager.saveCoursesForWidget(widgetCourses)
        }
    }
}

// MARK: - 支持类型

/// 网格配置
private struct GridConfiguration {
    let width: CGFloat
    let timeAxisWidth: CGFloat
    let dayWidth: CGFloat
    let hourHeight: CGFloat
    let totalHours: Int
    let gridTotalHeight: CGFloat  // 网格实际总高度
    
    init(width: CGFloat, timeAxisWidth: CGFloat, settings: AppSettings) {
        self.width = width
        self.timeAxisWidth = timeAxisWidth
        
        // 当隐藏时间标尺时，不占用空间
        let effectiveAxisWidth = settings.showTimeRuler ? timeAxisWidth : 0
        let rawDayWidth = (width - effectiveAxisWidth) / 7
        self.dayWidth = max(0.0, rawDayWidth.isFinite ? rawDayWidth : 0.0)
        
        self.totalHours = settings.calendarEndHour - settings.calendarStartHour
        
        // 根据显示模式设置 hourHeight
        if settings.timelineDisplayMode == .classTime {
            // 课程时间模式：hourHeight 增加到 120pt（两倍）
            self.hourHeight = 120.0
        } else {
            // 标准时间模式：hourHeight = 60pt
            self.hourHeight = 60.0
        }
        
        // 计算网格实际总高度
        // 无论哪种模式，总高度都基于日历时间范围
        let minuteHeight = hourHeight / 60.0
        let totalCalendarMinutes = (settings.calendarEndHour - settings.calendarStartHour) * 60
        self.gridTotalHeight = CGFloat(totalCalendarMinutes) * minuteHeight
    }
}

// MARK: - Preview

#Preview {
    ScheduleView()
        .environment(AppSettings())
        .modelContainer(for: [Course.self, Schedule.self], inMemory: true)
}
