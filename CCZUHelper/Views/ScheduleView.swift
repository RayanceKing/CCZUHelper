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
    @State private var showScheduleSettings = false
    @State private var showLoginSheet = false
    @State private var showManageSchedules = false
    @State private var showImagePicker = false
    @State private var weekOffset: Int = 0 // 周偏移量
    @State private var scrollProxy: ScrollViewProxy?
    
    private let helpers = ScheduleHelpers()
    private let calendar = Calendar.current
    private let timeAxisWidth: CGFloat = 50
    private let headerHeight: CGFloat = 60
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // 背景图片
                    if settings.backgroundImageEnabled,
                       let imagePath = settings.backgroundImagePath,
                       let uiImage = helpers.loadImage(from: imagePath) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                            .opacity(0.3)
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
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .onChange(of: weekOffset) { oldValue, newValue in
                            updateSelectedDateForWeekOffset(newValue)
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: { showDatePicker = true }) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(helpers.yearMonthString(for: selectedDate))
                                    .font(.headline)
                                    .fontWeight(.bold)
                                Text("第\(helpers.currentWeekNumber(for: selectedDate, schedules: schedules))周")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button("今日") {
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
                            showManageSchedules: $showManageSchedules,
                            showLoginSheet: $showLoginSheet,
                            showImagePicker: $showImagePicker
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
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showScheduleSettings) {
                ScheduleSettingsView()
                    .environment(settings)
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
                }
            }
            #endif
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
    }    // MARK: - 课程表网格
    private func scheduleGrid(width: CGFloat, height: CGFloat, weekOffset: Int) -> some View {
        let rawDayWidth = (width - timeAxisWidth) / 7
        let dayWidth = max(0, rawDayWidth.isFinite ? rawDayWidth : 0)
        let totalHours = settings.calendarEndHour - settings.calendarStartHour
        let hourHeight: CGFloat = 60
        let targetDate = helpers.getDateForWeekOffset(weekOffset, baseDate: baseDate)
        let weekCourses = helpers.coursesForWeek(courses: courses, date: targetDate)
        
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
