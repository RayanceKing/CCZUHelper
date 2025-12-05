//
//  ScheduleView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/11/30.
//

import SwiftUI
import SwiftData

// MARK: - 课程表视图
struct ScheduleView: View {
    // MARK: - 环境 & 查询
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    
    @Query private var courses: [Course]
    @Query private var schedules: [Schedule]
    
    // MARK: - 状态属性
    @State private var selectedDate: Date = Date()
    @State private var baseDate: Date = Date()
    @State private var weekOffset: Int = 0
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
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    backgroundImageView(geometry: geometry)
                    scheduleContentView(geometry: geometry)
                }
                .toolbar { toolbarContent }
            }
            .ignoresSafeArea(.container, edges: .bottom)
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
            }
            .onChange(of: settings.weekStartDay) { _, newValue in
                handleWeekStartDayChange(newValue)
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
        }
    }
    
    // MARK: - View Builders
    
    /// 背景图片视图
    @ViewBuilder
    private func backgroundImageView(geometry: GeometryProxy) -> some View {
        if settings.backgroundImageEnabled,
           let imagePath = settings.backgroundImagePath,
           let platformImage = helpers.loadImage(from: imagePath) {
            #if os(macOS)
            Image(nsImage: platformImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .opacity(0.3)
            #else
            Image(uiImage: platformImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .opacity(0.3)
            #endif
        }
    }
    
    /// 课程表内容视图
    private func scheduleContentView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            weekdayHeader(width: geometry.size.width)
            weeklyScheduleTabView(geometry: geometry)
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
        TabView(selection: $weekOffset) {
            ForEach(-52...52, id: \.self) { offset in
                scheduleScrollView(
                    width: geometry.size.width,
                    height: geometry.size.height,
                    weekOffset: offset
                )
                .tag(offset)
            }
        }
        #if os(macOS)
        .tabViewStyle(.automatic)
        #else
        .tabViewStyle(.page(indexDisplayMode: .never))
        #endif
        .onChange(of: weekOffset) { oldValue, newValue in
            handleWeekOffsetChange(oldValue, newValue)
        }
    }
    
    /// 单周课程表滚动视图
    private func scheduleScrollView(width: CGFloat, height: CGFloat, weekOffset: Int) -> some View {
        ScrollViewReader { proxy in
            ScrollView([.vertical, .horizontal], showsIndicators: false) {
                scheduleGrid(width: width, height: height, weekOffset: weekOffset)
                    .id("schedule_\(weekOffset)")
            }
            .onAppear { scrollProxy = proxy }
        }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            datePickerButton
        }
        
        ToolbarItemGroup(placement: .primaryAction) {
            todayButton
            UserMenuButton(showUserSettings: $showUserSettings)
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
                        semesterStartDate: settings.semesterStartDate
                    )
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
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
            semesterStartDate: settings.semesterStartDate
        )
        
        // 更新Widget数据
        updateWidgetDataIfNeeded(weekOffset: weekOffset, weekCourses: weekCourses)
        
        return HStack(alignment: .top, spacing: 0) {
            timeAxis(configuration: configuration)
            courseGrid(configuration: configuration, weekCourses: weekCourses, weekOffset: weekOffset)
        }
        .frame(
            width: configuration.dayWidth * 7 + configuration.timeAxisWidth,
            height: CGFloat(configuration.totalHours) * configuration.hourHeight,
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
    
    /// 课程网格
    private func courseGrid(configuration: GridConfiguration, weekCourses: [Course], weekOffset: Int) -> some View {
        ZStack(alignment: .topLeading) {
            if settings.showGridLines {
                ScheduleGridLines(
                    dayWidth: configuration.dayWidth,
                    hourHeight: configuration.hourHeight,
                    totalHours: configuration.totalHours
                )
            }
            
            ForEach(weekCourses, id: \.id) { course in
                CourseBlock(
                    course: course,
                    dayWidth: configuration.dayWidth,
                    hourHeight: configuration.hourHeight,
                    settings: settings,
                    helpers: helpers
                )
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
        .frame(height: CGFloat(configuration.totalHours) * configuration.hourHeight)
    }
    
    // MARK: - 工作表视图
    
    private var datePickerSheet: some View {
        DatePickerSheet(selectedDate: $selectedDate)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
    }
    
    private var loginSheet: some View {
        LoginView()
            .environment(settings)
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
        UserSettingsView(
            showManageSchedules: $showManageSchedules,
            showLoginSheet: $showLoginSheet,
            showImagePicker: $showImagePicker
        )
        .environment(settings)
    }
    
    // MARK: - 事件处理器
    
    /// 视图出现时的处理
    private func handleViewAppear() {
        resetToTodayIfNeeded()
        initializeCourseNotifications()
    }
    
    /// 周偏移改变处理
    private func handleWeekOffsetChange(_ oldValue: Int, _ newValue: Int) {
        triggerHapticFeedback()
        updateSelectedDateForWeekOffset(newValue)
    }
    
    /// 日期选择改变处理
    private func handleSelectedDateChange(_ oldValue: Date, _ newValue: Date) {
        let newOffset = calendar.dateComponents([.weekOfYear], from: baseDate, to: newValue).weekOfYear ?? 0
        
        if newOffset != weekOffset {
            withAnimation {
                weekOffset = newOffset
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
        }
    }
    
    /// 课程数据改变处理
    private func handleCoursesChange(_ oldValue: [Course], _ newValue: [Course]) {
        Task {
            await NotificationHelper.scheduleAllCourseNotifications(
                courses: newValue,
                settings: settings
            )
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
        baseDate = now
        selectedDate = now
        scrollToCurrentTime()
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
    
    /// 更新Widget数据(仅当前周)
    private func updateWidgetDataIfNeeded(weekOffset: Int, weekCourses: [Course]) {
        guard weekOffset == 0 else { return }
        
        let today = Date()
        let todayWeekday = calendar.component(.weekday, from: today)
        let todayDayOfWeek = todayWeekday == 1 ? 7 : todayWeekday - 1
        
        let todayCourses = weekCourses.filter { $0.dayOfWeek == todayDayOfWeek }
        let widgetCourses = todayCourses.map { course -> WidgetDataManager.WidgetCourse in
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
            widgetDataManager.saveTodayCoursesForWidget(widgetCourses)
        }
    }
}

// MARK: - 支持类型

/// 网格配置
private struct GridConfiguration {
    let width: CGFloat
    let timeAxisWidth: CGFloat
    let dayWidth: CGFloat
    let hourHeight: CGFloat = 60
    let totalHours: Int
    
    init(width: CGFloat, timeAxisWidth: CGFloat, settings: AppSettings) {
        self.width = width
        self.timeAxisWidth = timeAxisWidth
        
        let rawDayWidth = (width - timeAxisWidth) / 7
        self.dayWidth = max(0, rawDayWidth.isFinite ? rawDayWidth : 0)
        
        self.totalHours = settings.calendarEndHour - settings.calendarStartHour
    }
}

// MARK: - Preview

#Preview {
    ScheduleView()
        .environment(AppSettings())
        .modelContainer(for: [Course.self, Schedule.self], inMemory: true)
}
