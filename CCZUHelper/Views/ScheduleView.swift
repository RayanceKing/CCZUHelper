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
    @State private var showDatePicker = false
    @State private var showUserMenu = false
    @State private var showScheduleSettings = false
    @State private var showLoginSheet = false
    @State private var showManageSchedules = false
    @State private var showImagePicker = false
    
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
                        // 顶部工具栏
                        topToolbar
                        
                        // 星期标题行
                        weekdayHeader(width: geometry.size.width)
                        
                        // 课程表主体
                        ScrollView {
                            scheduleGrid(width: geometry.size.width, height: geometry.size.height - headerHeight - 100)
                        }
                    }
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
    
    // MARK: - 顶部工具栏
    private var topToolbar: some View {
        HStack {
            // 左上角: 年月显示,点击弹出日期选择
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
            .buttonStyle(.plain)
            
            Spacer()
            
            // 今日按钮
            Button("今日") {
                selectedDate = Date()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            // 右上角: 用户按钮
            userMenuButton
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
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
                Image(systemName: "person.crop.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
            } else {
                // 未登录显示默认图标
                Image(systemName: "person.crop.circle")
                    .font(.title2)
                    .foregroundStyle(.gray)
            }
        }
    }
    
    // MARK: - 星期标题行
    private func weekdayHeader(width: CGFloat) -> some View {
        let dayWidth = (width - timeAxisWidth) / 7
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
    private func scheduleGrid(width: CGFloat, height: CGFloat) -> some View {
        let dayWidth = (width - timeAxisWidth) / 7
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
                ForEach(coursesForCurrentWeek(), id: \.id) { course in
                    courseBlock(course: course, dayWidth: dayWidth, hourHeight: hourHeight)
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
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 0.5)
                    .offset(y: CGFloat(index) * hourHeight)
            }
            
            // 垂直线
            ForEach(0...7, id: \.self) { index in
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 0.5)
                    .offset(x: CGFloat(index) * dayWidth)
            }
        }
    }
    
    // MARK: - 课程块
    private func courseBlock(course: Course, dayWidth: CGFloat, hourHeight: CGFloat) -> some View {
        // 计算课程位置
        let dayIndex = adjustedDayIndex(for: course.dayOfWeek)
        let startHour = timeSlotToHour(course.timeSlot)
        let duration = 2 // 默认每节课2小时
        
        let xOffset = CGFloat(dayIndex) * dayWidth + 2
        let yOffset = CGFloat(startHour - settings.calendarStartHour) * hourHeight + 2
        let blockHeight = CGFloat(duration) * hourHeight - 4
        let blockWidth = dayWidth - 4
        
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
        calendar.component(.weekOfYear, from: selectedDate)
    }
    
    private func weekdayName(for index: Int) -> String {
        let weekdays = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
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
        let today = selectedDate
        
        // 获取本周的开始日期
        var startOfWeek = today
        var interval = TimeInterval(0)
        _ = calendar.dateInterval(of: .weekOfYear, start: &startOfWeek, interval: &interval, for: today)
        
        // 根据用户设置的周开始日调整
        let weekday = calendar.component(.weekday, from: startOfWeek)
        let adjustment: Int
        
        switch settings.weekStartDay {
        case .sunday:
            adjustment = weekday == 1 ? 0 : -(weekday - 1)
        case .monday:
            adjustment = weekday == 1 ? -6 : -(weekday - 2)
        case .saturday:
            adjustment = weekday == 7 ? 0 : -(weekday)
        }
        
        startOfWeek = calendar.date(byAdding: .day, value: adjustment, to: startOfWeek) ?? startOfWeek
        
        // 生成一周的日期
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: startOfWeek) {
                dates.append(date)
            }
        }
        
        return dates
    }
    
    private func coursesForCurrentWeek() -> [Course] {
        let weekNumber = currentWeekNumber
        return courses.filter { $0.weeks.contains(weekNumber) }
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
    
    private func timeSlotToHour(_ timeSlot: Int) -> Int {
        // 将节次转换为小时
        // 第1-2节: 8:00-10:00
        // 第3-4节: 10:00-12:00
        // 第5-6节: 14:00-16:00
        // 第7-8节: 16:00-18:00
        // 第9-10节: 19:00-21:00
        switch timeSlot {
        case 1, 2: return 8
        case 3, 4: return 10
        case 5, 6: return 14
        case 7, 8: return 16
        case 9, 10: return 19
        default: return 8
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
