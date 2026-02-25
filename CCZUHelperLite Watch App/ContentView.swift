//
//  ContentView.swift
//  CCZUHelperLite Watch App
//
//  Created by rayanceking on 2025/12/6.
//

import SwiftUI
import Foundation

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var todayCourses: [WatchDataManager.WatchCourse] = []
    @State private var isLoading = true
    @State private var lastUpdated: Date?
    @State private var loadFailureReason: WatchDataManager.LoadFailureReason?
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let failure = loadFailureReason {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title3)
                            .foregroundStyle(.yellow)
                        Text("schedule.loading_failed".localized)
                            .font(.callout)
                            .multilineTextAlignment(.center)
                        Text(errorDescription(for: failure))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("retry".localized) {
                            Task { await reloadTodayCourses() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if todayCourses.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle")
                            .font(.title)
                            .foregroundStyle(.green)
                        Text("schedule.no_classes_today".localized)
                            .font(.callout)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            ForEach(todayCourses) { course in
                                CourseRowView(course: course)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                                    .listRowBackground(Color.clear)
                            }
                        } header: {
                            HStack {
                                Text("schedule.today".localized)
                                Spacer()
                                if let lastUpdated {
                                    Text(lastUpdated, style: .time)
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .listStyle(.carousel)
                    .refreshable {
                        await reloadTodayCourses()
                    }
                }
            }
            .navigationTitle("EduPal")
        }
        .onAppear {
            Task { await reloadTodayCourses() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .watchCoursesDidUpdate)) { _ in
            Task { await reloadTodayCourses() }
        }
    }
    
    @MainActor
    private func reloadTodayCourses() async {
        isLoading = true
        let result = WatchDataManager.shared.loadTodayCoursesFromApp()
        todayCourses = result.courses
        loadFailureReason = result.failureReason
        lastUpdated = result.lastModified ?? Date()
        if result.failureReason == .missingFile {
            #if canImport(WatchConnectivity)
            WatchConnectivityReceiver.shared.requestCoursesSyncFromPhone()
            #endif
        }
        isLoading = false
    }

    private func errorDescription(for reason: WatchDataManager.LoadFailureReason) -> String {
        switch reason {
        case .missingContainer:
            return "App Group unavailable"
        case .missingFile:
            return "Waiting for iPhone sync"
        case .decodeFailed:
            return "Course data format invalid"
        }
    }
}

// MARK: - 课程行视图
struct CourseRowView: View {
    let course: WatchDataManager.WatchCourse
    
    var timeRange: (start: String, end: String)? {
        WatchDataManager.shared.getTimeRange(for: course.timeSlot)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                // 颜色指示器
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: course.color) ?? .blue)
                    .frame(width: 4)
                
                // 课程名称和时间
                VStack(alignment: .leading, spacing: 2) {
                    Text(course.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    if let timeRange = timeRange {
                        Text("\(timeRange.start) - \(timeRange.end)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // 教师和地点
            HStack(spacing: 8) {
                Label(course.teacher, systemImage: "person.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 8) {
                Label(course.location, systemImage: "mappin.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(Color(white: 0.1, opacity: 1.0))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Color 扩展
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        guard hexSanitized.count == 6 else { return nil }
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
}

#Preview {
    ContentView()
}
