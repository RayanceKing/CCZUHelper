//
//  ContentView.swift
//  CCZUHelperWatch Watch App
//
//  Created by rayanceking on 2025/12/04.
//

import SwiftUI

// MARK: - 本地化辅助
extension String {
    var localized: String {
        NSLocalizedString(self, bundle: Bundle.main, comment: "")
    }
    
    func localized(_ args: CVarArg...) -> String {
        String(format: NSLocalizedString(self, bundle: Bundle.main, comment: ""), arguments: args)
    }
}

// MARK: - 课程数据模型
struct WatchCourse: Codable, Identifiable {
    var id: String { "\(name)-\(timeSlot)" }
    let name: String
    let teacher: String
    let location: String
    let timeSlot: Int
    let duration: Int
    let color: String
}

// MARK: - 数据管理器
class WatchDataManager: ObservableObject {
    static let shared = WatchDataManager()
    
    @Published var courses: [WatchCourse] = []
    @Published var isLoading = false
    @Published var lastUpdateTime: Date?
    
    private let appGroupIdentifier = "group.com.cczu.helper"
    
    init() {
        loadCourses()
    }
    
    private var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }
    
    func loadCourses() {
        isLoading = true
        
        guard let containerURL = sharedContainerURL else {
            print("无法访问共享容器")
            isLoading = false
            return
        }
        
        let coursesFile = containerURL.appendingPathComponent("widget_courses.json")
        
        do {
            let data = try Data(contentsOf: coursesFile)
            let decoder = JSONDecoder()
            courses = try decoder.decode([WatchCourse].self, from: data)
            lastUpdateTime = Date()
        } catch {
            print("加载课程数据失败: \(error)")
            courses = []
        }
        
        isLoading = false
    }
    
    func refresh() {
        loadCourses()
    }
}

// MARK: - 主视图
struct ContentView: View {
    @StateObject private var dataManager = WatchDataManager.shared
    @State private var currentTime = Date()
    
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationStack {
            Group {
                if dataManager.isLoading {
                    LoadingView()
                } else if dataManager.courses.isEmpty {
                    EmptyStateView(onRefresh: {
                        dataManager.refresh()
                    })
                } else {
                    CourseListView(courses: dataManager.courses, currentTime: currentTime)
                }
            }
            .navigationTitle("watch.title".localized)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        dataManager.refresh()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
        .onAppear {
            dataManager.refresh()
        }
    }
}

// MARK: - 加载视图
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("watch.loading".localized)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 空状态视图
struct EmptyStateView: View {
    let onRefresh: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("watch.no_courses".localized)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text("watch.no_courses_hint".localized)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: onRefresh) {
                Label("watch.refresh".localized, systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

// MARK: - 课程列表视图
struct CourseListView: View {
    let courses: [WatchCourse]
    let currentTime: Date
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // 当前时间
                TimeHeaderView(time: currentTime)
                
                // 课程列表
                ForEach(courses) { course in
                    CourseCardView(
                        course: course,
                        currentTime: currentTime,
                        isCurrentCourse: isCurrentCourse(course)
                    )
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private func isCurrentCourse(_ course: WatchCourse) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentTime)
        let minute = calendar.component(.minute, from: currentTime)
        let currentMinutes = hour * 60 + minute
        
        let startMinutes = getStartTime(for: course.timeSlot)
        let endMinutes = startMinutes + course.duration * 45
        
        return currentMinutes >= startMinutes && currentMinutes < endMinutes
    }
    
    private func getStartTime(for slot: Int) -> Int {
        let times = [
            1: 8 * 60,      // 8:00
            2: 8 * 60 + 50, // 8:50
            3: 10 * 60,     // 10:00
            4: 10 * 60 + 50,// 10:50
            5: 14 * 60,     // 14:00
            6: 14 * 60 + 50,// 14:50
            7: 16 * 60,     // 16:00
            8: 16 * 60 + 50,// 16:50
            9: 19 * 60,     // 19:00
            10: 19 * 60 + 50// 19:50
        ]
        return times[slot] ?? 0
    }
}

// MARK: - 时间头部视图
struct TimeHeaderView: View {
    let time: Date
    
    var body: some View {
        VStack(spacing: 4) {
            Text(time, style: .time)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(formattedDate())
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "watch.date_format".localized
        formatter.locale = Locale.current
        return formatter.string(from: time)
    }
}

// MARK: - 课程卡片视图
struct CourseCardView: View {
    let course: WatchCourse
    let currentTime: Date
    let isCurrentCourse: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 课程名称和时间
            HStack {
                Circle()
                    .fill(colorFromHex(course.color))
                    .frame(width: 8, height: 8)
                
                Text(course.name)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)
                
                Spacer()
                
                if isCurrentCourse {
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 12))
                }
            }
            
            // 课程详情
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10))
                    Text(timeSlotText(course.timeSlot))
                        .font(.system(size: 11))
                    Text("•")
                        .font(.system(size: 10))
                    Text("\(course.duration)" + "watch.classes".localized)
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary)
                
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 10))
                    Text(course.location)
                        .font(.system(size: 11))
                        .lineLimit(1)
                }
                .foregroundColor(.secondary)
                
                HStack(spacing: 6) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 10))
                    Text(course.teacher)
                        .font(.system(size: 11))
                        .lineLimit(1)
                }
                .foregroundColor(.secondary)
            }
            
            // 进度条(仅当前课程显示)
            if isCurrentCourse, let progress = courseProgress() {
                ProgressView(value: progress)
                    .tint(colorFromHex(course.color))
                    .scaleEffect(y: 0.5)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCurrentCourse ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCurrentCourse ? Color.green : Color.clear, lineWidth: 2)
        )
        .padding(.horizontal)
    }
    
    private func courseProgress() -> Double? {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentTime)
        let minute = calendar.component(.minute, from: currentTime)
        let currentMinutes = hour * 60 + minute
        
        let startMinutes = getStartTime(for: course.timeSlot)
        let endMinutes = startMinutes + course.duration * 45
        
        if currentMinutes >= startMinutes && currentMinutes < endMinutes {
            return Double(currentMinutes - startMinutes) / Double(endMinutes - startMinutes)
        }
        return nil
    }
    
    private func timeSlotText(_ slot: Int) -> String {
        let times = [
            1: "8:00", 2: "8:50", 3: "10:00", 4: "10:50",
            5: "14:00", 6: "14:50", 7: "16:00", 8: "16:50",
            9: "19:00", 10: "19:50"
        ]
        return times[slot] ?? ""
    }
    
    private func getStartTime(for slot: Int) -> Int {
        let times = [
            1: 8 * 60, 2: 8 * 60 + 50, 3: 10 * 60, 4: 10 * 60 + 50,
            5: 14 * 60, 6: 14 * 60 + 50, 7: 16 * 60, 8: 16 * 60 + 50,
            9: 19 * 60, 10: 19 * 60 + 50
        ]
        return times[slot] ?? 0
    }
}

// MARK: - 辅助函数
private func colorFromHex(_ hex: String) -> Color {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)
    let r, g, b: UInt64
    switch hex.count {
    case 3:
        (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
    case 6:
        (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
    default:
        (r, g, b) = (0, 0, 0)
    }
    return Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
}

// MARK: - Preview
#Preview {
    ContentView()
}
