//
//  ScheduleView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/11/30.
//

import SwiftUI
import SwiftData

/// 课程表视图
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
                       let uiImage = loadImage(from: imagePath) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                            .opacity(0.3)
                    }
                    
                    VStack(spacing: 0) {
                        // 星期标题行
                        weekdayHeader(width: geometry.size.width)
                        
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
                                Text(yearMonthString)
                                    .font(.headline)
                                    .fontWeight(.bold)
                                Text("第\(currentWeekNumber)周")
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
                        
                        userMenuButton
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
    }
    
    // MARK: - 用户菜单按钮
    private var userMenuButton: some View {
        Menu {
            // 课程表设置
            Menu {
                Button(action: { showManageSchedules = true }) {
                    Label("管理课表", systemImage: "list.bullet")
                }
                
                Divider()
                
                // 日历开始时间
                Menu {
                    ForEach(6...12, id: \.self) { hour in
                        Button("\(hour):00") {
                            settings.calendarStartHour = hour
                        }
                    }
                } label: {
                    Label("日历开始时间: \(settings.calendarStartHour):00", systemImage: "clock")
                }
                
                // 日历结束时间
                Menu {
                    ForEach(18...23, id: \.self) { hour in
                        Button("\(hour):00") {
                            settings.calendarEndHour = hour
                        }
                    }
                } label: {
                    Label("日历结束时间: \(settings.calendarEndHour):00", systemImage: "clock.fill")
                }
                
                Divider()
                
                Toggle(isOn: Binding(
                    get: { settings.showGridLines },
                    set: { settings.showGridLines = $0 }
                )) {
                    Label("显示分割线", systemImage: "squareshape.split.3x3")
                }
                
                Toggle(isOn: Binding(
                    get: { settings.showTimeRuler },
                    set: { settings.showTimeRuler = $0 }
                )) {
                    Label("显示时间标尺", systemImage: "ruler")
                }
                
                Toggle(isOn: Binding(
                    get: { settings.showAllDayEvents },
                    set: { settings.showAllDayEvents = $0 }
                )) {
                    Label("显示全天日程", systemImage: "calendar.day.timeline.left")
                }
                
                Divider()
                
                // 时间间隔
                Menu {
                    ForEach(AppSettings.TimeInterval.allCases, id: \.rawValue) { interval in
                        Button(interval.displayName) {
                            settings.timeInterval = interval
                        }
                    }
                } label: {
                    Label("时间间隔: \(settings.timeInterval.displayName)", systemImage: "timer")
                }
                
                // 课程块透明度
                Menu {
                    ForEach([0.5, 0.6, 0.7, 0.8, 0.9, 1.0], id: \.self) { opacity in
                        Button("\(Int(opacity * 100))%") {
                            settings.courseBlockOpacity = opacity
                        }
                    }
                } label: {
                    Label("课程块透明度: \(Int(settings.courseBlockOpacity * 100))%", systemImage: "square.fill")
                }
                
                Divider()
                
                Toggle(isOn: Binding(
                    get: { settings.backgroundImageEnabled },
                    set: { newValue in
                        settings.backgroundImageEnabled = newValue
                        if newValue {
                            showImagePicker = true
                        }
                    }
                )) {
                    Label("开启背景图片", systemImage: "photo")
                }
                
            } label: {
                Label("课程表设置", systemImage: "gearshape")
            }
            
            Button(action: {}) {
                Label("通知", systemImage: "bell")
            }
            
            // 主题设置
            Menu {
                ForEach(AppSettings.ThemeMode.allCases, id: \.rawValue) { mode in
                    Button(action: { settings.themeMode = mode }) {
                        HStack {
                            Text(mode.rawValue)
                            if settings.themeMode == mode {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label("主题设置", systemImage: "paintbrush")
            }
            
            Divider()
            
            if settings.isLoggedIn {
                Button(role: .destructive, action: { settings.logout() }) {
                    Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } else {
                Button(action: { showLoginSheet = true }) {
                    Label("登录", systemImage: "person.circle")
                }
            }
            
        } label: {
            if settings.isLoggedIn {
                // 已登录显示用户头像
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.title2)
                    .foregroundStyle(.blue)
            } else {
                // 未登录显示默认图标
                Image(systemName: "person.crop.circle.badge.xmark")
                    .font(.title2)
                    .foregroundStyle(.gray)
            }
        }
    }
    
    // MARK: - 星期标题行
    private func weekdayHeader(width: CGFloat) -> some View {
        let rawDayWidth = (width - timeAxisWidth) / 7
        let dayWidth = max(0, rawDayWidth.isFinite ? rawDayWidth : 0)
        let weekDates = getWeekDates()
        
        return HStack(spacing: 0) {
            // 左上角空白
            Color.clear
                .frame(width: timeAxisWidth, height: headerHeight)
            
            // 星期标题
            ForEach(0..<7, id: \.self) { index in
                let date = weekDates[index]
                let isToday = calendar.isDateInToday(date)
                
                VStack(spacing: 4) {
                    Text(weekdayName(for: index))
                        .font(.caption)
                        .foregroundStyle(isToday ? .blue : .secondary)
                    
                    Text("\(calendar.component(.day, from: date))")
                        .font(.headline)
                        .fontWeight(isToday ? .bold : .regular)
                        .foregroundStyle(isToday ? .white : .primary)
                        .frame(width: 28, height: 28)
                        .background(isToday ? Color.blue : Color.clear)
                        .clipShape(Circle())
                }
                .frame(width: dayWidth, height: headerHeight)
            }
        }
        .background(Color(.systemBackground).opacity(0.95))
    }
    
    // MARK: - 课程表网格
    private func scheduleGrid(width: CGFloat, height: CGFloat, weekOffset: Int) -> some View {
        let rawDayWidth = (width - timeAxisWidth) / 7
        let dayWidth = max(0, rawDayWidth.isFinite ? rawDayWidth : 0)
        let totalHours = settings.calendarEndHour - settings.calendarStartHour
        let hourHeight: CGFloat = 60
        
        return HStack(alignment: .top, spacing: 0) {
            // 时间轴
            if settings.showTimeRuler {
                VStack(spacing: 0) {
                    ForEach(settings.calendarStartHour..<settings.calendarEndHour, id: \.self) { hour in
                        Text(String(format: "%02d:00", hour))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: timeAxisWidth, height: hourHeight, alignment: .topTrailing)
                            .padding(.trailing, 4)
                    }
                }
            } else {
                Color.clear
                    .frame(width: timeAxisWidth)
            }
            
            // 课程网格
            ZStack(alignment: .topLeading) {
                // 网格线
                if settings.showGridLines {
                    gridLines(dayWidth: dayWidth, hourHeight: hourHeight, totalHours: totalHours)
                }
                
                // 课程块
                ForEach(coursesForWeek(offset: weekOffset), id: \.id) { course in
                    courseBlock(course: course, dayWidth: dayWidth, hourHeight: hourHeight)
                }
                
                // 当前时间线 - 只在当前周显示
                if weekOffset == 0 {
                    currentTimeLine(dayWidth: dayWidth, hourHeight: hourHeight, totalWidth: dayWidth * 7)
                }
            }
            .frame(height: CGFloat(totalHours) * hourHeight)
        }
    }
    
    // MARK: - 网格线
    private func gridLines(dayWidth: CGFloat, hourHeight: CGFloat, totalHours: Int) -> some View {
        ZStack {
            // 水平线
            ForEach(0...totalHours, id: \.self) { index in
                Rectangle()
                    .stroke(Color.gray.opacity(0.2))
                    .offset(y: CGFloat(index) * hourHeight)
            }
            
            // 垂直线
            ForEach(0...7, id: \.self) { index in
                Rectangle()
                    .stroke(Color.gray.opacity(0.2))
                    .offset(x: CGFloat(index) * dayWidth)
            }
        }
    }
    
    // MARK: - 课程块
    private func courseBlock(course: Course, dayWidth: CGFloat, hourHeight: CGFloat) -> some View {
        // 计算课程位置 - 使用分钟级别精度
        let dayIndex = adjustedDayIndex(for: course.dayOfWeek)
        
        // 计算开始位置(以分钟为单位)
        let startMinutes = settings.timeSlotToMinutes(course.timeSlot)
        let calendarStartMinutes = settings.calendarStartHour * 60
        let minuteHeight = hourHeight / 60.0
        
        // 计算课程时长(以分钟为单位)
        let durationMinutes = settings.courseDurationInMinutes(startSlot: course.timeSlot, duration: course.duration)
        
        let xOffsetRaw = CGFloat(dayIndex) * dayWidth + 2
        let yOffsetRaw = CGFloat(startMinutes - calendarStartMinutes) * minuteHeight + 2
        let blockHeightRaw = CGFloat(durationMinutes) * minuteHeight - 4
        let blockWidthRaw = dayWidth - 4
        
        let xOffset = xOffsetRaw.isFinite ? xOffsetRaw : 0
        let yOffset = yOffsetRaw.isFinite ? yOffsetRaw : 0
        let blockHeight = max(0, blockHeightRaw.isFinite ? blockHeightRaw : 0)
        let blockWidth = max(0, blockWidthRaw.isFinite ? blockWidthRaw : 0)
        
        return VStack(alignment: .leading, spacing: 2) {
            Text(course.name)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(2)
            
            Text(course.location)
                .font(.caption2)
                .lineLimit(1)
            
            Text(course.teacher)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(4)
        .frame(width: blockWidth, height: blockHeight, alignment: .topLeading)
        .background(course.uiColor.opacity(settings.courseBlockOpacity))
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .offset(x: xOffset, y: yOffset)
    }
    
    // MARK: - 辅助方法
    private var yearMonthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: selectedDate)
    }
    
    private var currentWeekNumber: Int {
        // 计算当前显示周相对于学期开始的周数
        // 如果有活跃课表，使用课表开始日期；否则使用年度周数
        if let activeSchedule = schedules.first(where: { $0.isActive }) {
            // 假设学期第一周从 createdAt 或固定日期开始
            let semesterStart = activeSchedule.createdAt
            let weeksSinceStart = calendar.dateComponents([.weekOfYear], from: semesterStart, to: selectedDate).weekOfYear ?? 0
            return max(1, weeksSinceStart + 1)
        }
        return calendar.component(.weekOfYear, from: selectedDate)
    }
    
    private func weekdayName(for index: Int) -> String {
        let weekdays = [
            String(localized: "周一"),
            String(localized: "周二"),
            String(localized: "周三"),
            String(localized: "周四"),
            String(localized: "周五"),
            String(localized: "周六"),
            String(localized: "周日")
        ]
        let adjustedIndex: Int
        
        switch settings.weekStartDay {
        case .sunday:
            adjustedIndex = (index + 6) % 7
        case .monday:
            adjustedIndex = index
        case .saturday:
            adjustedIndex = (index + 5) % 7
        }
        
        return weekdays[adjustedIndex]
    }
    
    private func getWeekDates() -> [Date] {
        var dates: [Date] = []
        let targetDate = getDateForWeekOffset(weekOffset)
        
        // 获取目标日期所在周的周一
        let weekday = calendar.component(.weekday, from: targetDate)
        
        // 计算到本周一的天数偏移（weekday: 1=周日, 2=周一, ..., 7=周六）
        let daysFromMonday: Int
        switch settings.weekStartDay {
        case .monday:
            // 周一开始：周日往前6天，周一0天，周二往前1天...
            daysFromMonday = weekday == 1 ? -6 : -(weekday - 2)
        case .sunday:
            // 周日开始：周日0天，周一往前1天...
            daysFromMonday = -(weekday - 1)
        case .saturday:
            // 周六开始：周六0天，周日往前1天，周一往前2天...
            daysFromMonday = weekday == 7 ? -1 : -(weekday)
        }
        
        guard let startOfWeek = calendar.date(byAdding: .day, value: daysFromMonday, to: targetDate) else {
            return []
        }
        
        // 生成一周的日期
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: startOfWeek) {
                dates.append(date)
            }
        }
        
        return dates
    }
    
    // 根据周偏移量获取日期 - 使用基准日期而非selectedDate
    private func getDateForWeekOffset(_ offset: Int) -> Date {
        calendar.date(byAdding: .weekOfYear, value: offset, to: baseDate) ?? baseDate
    }
    
    // 更新选中日期以匹配周偏移
    private func updateSelectedDateForWeekOffset(_ offset: Int) {
        selectedDate = getDateForWeekOffset(offset)
    }
    
    private func coursesForWeek(offset: Int) -> [Course] {
        let targetDate = getDateForWeekOffset(offset)
        let weekNumber = calendar.component(.weekOfYear, from: targetDate)
        return courses.filter { $0.weeks.contains(weekNumber) }
    }
    
    // 当前时间线
    private func currentTimeLine(dayWidth: CGFloat, hourHeight: CGFloat, totalWidth: CGFloat) -> some View {
        GeometryReader { geometry in
            let now = Date()
            let calendar = Calendar.current
            
            // 检查是否是今天
            guard calendar.isDateInToday(now) else {
                return AnyView(EmptyView())
            }
            
            let hour = calendar.component(.hour, from: now)
            let minute = calendar.component(.minute, from: now)
            
            // 检查当前时间是否在显示范围内
            guard hour >= settings.calendarStartHour && hour < settings.calendarEndHour else {
                return AnyView(EmptyView())
            }
            
            let hoursFromStart = CGFloat(hour - settings.calendarStartHour)
            let minuteOffset = CGFloat(minute) / 60.0
            let yPosition = (hoursFromStart + minuteOffset) * hourHeight
            
            return AnyView(
                HStack(spacing: 0) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    
                    Rectangle()
                        .fill(Color.red)
                        .frame(height: 2)
                }
                .frame(width: totalWidth + 8)
                .offset(x: -4, y: yPosition)
                .zIndex(100)
            )
        }
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
    
    private func adjustedDayIndex(for dayOfWeek: Int) -> Int {
        switch settings.weekStartDay {
        case .sunday:
            return dayOfWeek == 7 ? 6 : dayOfWeek - 1
        case .monday:
            return dayOfWeek - 1
        case .saturday:
            return (dayOfWeek + 1) % 7
        }
    }
    
    private func loadImage(from path: String) -> PlatformImage? {
        #if os(iOS)
        return UIImage(contentsOfFile: path)
        #elseif os(macOS)
        return NSImage(contentsOfFile: path)
        #else
        return nil
        #endif
    }
}

// MARK: - 平台图片类型
#if os(iOS)
typealias PlatformImage = UIImage
#elseif os(macOS)
typealias PlatformImage = NSImage
#else
typealias PlatformImage = Any
#endif

// MARK: - 日期选择器弹窗
struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            DatePicker(
                "选择日期",
                selection: $selectedDate,
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .padding()
            .navigationTitle("选择日期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ScheduleView()
        .environment(AppSettings())
        .modelContainer(for: [Course.self, Schedule.self], inMemory: true)
}
