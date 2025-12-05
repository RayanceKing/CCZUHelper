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
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    
    @Query private var courses: [Course]
    @Query private var schedules: [Schedule]
    
    @State private var selectedDate: Date = Date()
    @State private var baseDate: Date = Date() // 用于计算周偏移的基准日期
    @State private var showDatePicker = false
    @State private var showLoginSheet = false
    @State private var showManageSchedules = false
    @State private var showImagePicker = false
    @State private var showUserSettings = false
    @State private var weekOffset: Int = 0 // 周偏移量
    @State private var scrollProxy: ScrollViewProxy?
    
    private let helpers = ScheduleHelpers()
    private let calendar = Calendar.current
    private let timeAxisWidth: CGFloat = 50
    private let headerHeight: CGFloat = 60
    private let widgetDataManager = WidgetDataManager.shared
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // 背景图片
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
                    
                    VStack(spacing: 0) {
                        // 星期标题行
                        WeekdayHeader(
                            width: geometry.size.width,
                            timeAxisWidth: timeAxisWidth,
                            headerHeight: headerHeight,
                            weekDates: helpers.getWeekDates(for: helpers.getDateForWeekOffset(weekOffset, baseDate: baseDate), weekStartDay: settings.weekStartDay),
                            settings: settings,
                            helpers: helpers
                        )
                        
                        // 课程表主体 - 支持左右滑动
                        TabView(selection: $weekOffset) {
                            ForEach(-52...52, id: \.self) { offset in
                                ScrollViewReader { proxy in
                                    ScrollView {
                                        scheduleGrid(
                                            width: geometry.size.width,
                                            height: geometry.size.height - headerHeight - 100,
                                            weekOffset: offset
                                        )
                                        .id("schedule_\(offset)")
                                    }
                                    .onAppear {
                                        scrollProxy = proxy
                                    }
                                }
                                .tag(offset)
                            }
                        }
                        #if os(macOS)
                        .tabViewStyle(.automatic)
                        #else
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        #endif
                        .onChange(of: weekOffset) { oldValue, newValue in
                            // 滑动切换周时触发震动
                            #if os(iOS)
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            #endif
                            updateSelectedDateForWeekOffset(newValue)
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        Button(action: { showDatePicker = true }) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(helpers.yearMonthString(for: selectedDate))
                                    .font(.headline)
                                    .fontWeight(.bold)
                                Text("schedule.week.format".localized(with: helpers.currentWeekNumber(for: selectedDate, schedules: schedules, semesterStartDate: settings.semesterStartDate)))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button("schedule.today".localized) {
                            withAnimation {
                                let now = Date()
                                weekOffset = 0
                                baseDate = now
                                selectedDate = now
                                // 滚动到当前时间
                                scrollToCurrentTime()
                            }
                        }
                        
                        UserMenuButton(
                            showUserSettings: $showUserSettings
                        )
                    }
                }
            }
            .onAppear {
                // 进入页面时重置为当前周
                if weekOffset != 0 || !calendar.isDate(baseDate, equalTo: Date(), toGranularity: .day) {
                    let now = Date()
                    baseDate = now
                    selectedDate = now
                    weekOffset = 0
                }
            }
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(selectedDate: $selectedDate)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showLoginSheet) {
                LoginView()
                    .environment(settings)
            }
            .sheet(isPresented: $showManageSchedules) {
                ManageSchedulesView()
                    .environment(settings)
            }
            #if os(iOS)
            .sheet(isPresented: $showImagePicker) {
                ImagePickerView { url in
                    settings.backgroundImagePath = url?.path
                    // 只有当用户成功选择图片后，才将开关状态设为 true
                    settings.backgroundImageEnabled = (url != nil)
                }
            }
            #endif
            .sheet(isPresented: $showUserSettings) {
                UserSettingsView(
                    showManageSchedules: $showManageSchedules,
                    showLoginSheet: $showLoginSheet,
                    showImagePicker: $showImagePicker
                )
                .environment(settings)
            }
            //.ignoresSafeArea(.container,edges: .bottom)
        }
        .onChange(of: selectedDate) { oldValue, newValue in
            // 当从日期选择器选择新日期时，计算与基准日期的周偏移量
            // 并将 TabView 切换到对应的周
            let newOffset = calendar.dateComponents([.weekOfYear], from: baseDate, to: newValue).weekOfYear ?? 0
            
            // 仅当周偏移量实际发生变化时才更新，以避免不必要的重绘或潜在的更新循环
            if newOffset != weekOffset {
                withAnimation {
                    weekOffset = newOffset
                }
            }
        }
        .onChange(of: settings.weekStartDay) { oldValue, newValue in
            // 当每周开始日变化时，强制刷新视图
            // 通过临时改变 weekOffset 来触发 TabView 重新渲染
            let tempOffset = weekOffset
            weekOffset = tempOffset + 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                weekOffset = tempOffset
            }
        }
        // 应用全局主题设置，确保所有子视图（包括 sheet）都能正确响应
//        .preferredColorScheme(settings.themeMode.colorScheme)
    }    // MARK: - 课程表网格
    private func scheduleGrid(width: CGFloat, height: CGFloat, weekOffset: Int) -> some View {
        let rawDayWidth = (width - timeAxisWidth) / 7
        let dayWidth = max(0, rawDayWidth.isFinite ? rawDayWidth : 0)
        let totalHours = settings.calendarEndHour - settings.calendarStartHour
        let hourHeight: CGFloat = 60
        let targetDate = helpers.getDateForWeekOffset(weekOffset, baseDate: baseDate)
        let weekCourses = helpers.coursesForWeek(courses: courses, date: targetDate, semesterStartDate: settings.semesterStartDate)
        
        // 当是当前周时，只保存今天的课程到Widget
        if weekOffset == 0 {
            let today = Date()
            let todayWeekday = Calendar.current.component(.weekday, from: today)
            // iOS中 weekday: 1=周日, 2=周一, ..., 7=周六
            // 转换为 1=周一, 2=周二, ..., 7=周日
            let todayDayOfWeek = todayWeekday == 1 ? 7 : todayWeekday - 1
            
            print("🔍 Widget保存调试:")
            print("  当前时间: \(today)")
            print("  iOS weekday: \(todayWeekday)")
            print("  转换后dayOfWeek: \(todayDayOfWeek)")
            print("  weekCourses总数: \(weekCourses.count)")
            print("  weekCourses详情:")
            for course in weekCourses {
                print("    - \(course.name) (dayOfWeek: \(course.dayOfWeek), timeSlot: \(course.timeSlot))")
            }
            
            let todayCourses = weekCourses.filter { $0.dayOfWeek == todayDayOfWeek }
            print("  今天的课程数: \(todayCourses.count)")
            print("  今天的课程:")
            for course in todayCourses {
                print("    - \(course.name) (dayOfWeek: \(course.dayOfWeek))")
            }
            
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
        
        return HStack(alignment: .top, spacing: 0) {
            // 时间轴
            TimeAxis(
                timeAxisWidth: timeAxisWidth,
                hourHeight: hourHeight,
                settings: settings
            )
            
            // 课程网格
            ZStack(alignment: .topLeading) {
                // 网格线
                if settings.showGridLines {
                    ScheduleGridLines(
                        dayWidth: dayWidth,
                        hourHeight: hourHeight,
                        totalHours: totalHours
                    )
                }
                
                // 课程块
                ForEach(weekCourses, id: \.id) { course in
                    CourseBlock(
                        course: course,
                        dayWidth: dayWidth,
                        hourHeight: hourHeight,
                        settings: settings,
                        helpers: helpers
                    )
                }
                
                // 当前时间线 - 只在当前周显示
                if weekOffset == 0 {
                    CurrentTimeLine(
                        dayWidth: dayWidth,
                        hourHeight: hourHeight,
                        totalWidth: dayWidth * 7,
                        settings: settings
                    )
                }
            }
            .frame(height: CGFloat(totalHours) * hourHeight)
        }
    }

    
    // MARK: - 辅助方法
    
    // 更新选中日期以匹配周偏移
    private func updateSelectedDateForWeekOffset(_ offset: Int) {
        selectedDate = helpers.getDateForWeekOffset(offset, baseDate: baseDate)
    }
    
    // 滚动到当前时间
    private func scrollToCurrentTime() {
        guard let proxy = scrollProxy else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation {
                proxy.scrollTo("schedule_0", anchor: .top)
            }
        }
    }
}

#Preview {
    ScheduleView()
        .environment(AppSettings())
        .modelContainer(for: [Course.self, Schedule.self], inMemory: true)
}
