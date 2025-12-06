//
//  ContentView.swift
//  CCZUHelperLite Watch App
//
//  Created by rayanceking on 2025/12/6.
//

import SwiftUI
import Foundation

struct ContentView: View {
    @State private var todayCourses: [WatchDataManager.WatchCourse] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    ProgressView()
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
                    ScrollView {
                        VStack(spacing: 12) {
                            Text("schedule.today".localized)
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            VStack(spacing: 8) {
                                ForEach(todayCourses, id: \.name) { course in
                                    CourseRowView(course: course)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("CCZUHelper")
        }
        .onAppear {
            loadTodayCourses()
        }
    }
    
    private func loadTodayCourses() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let courses = WatchDataManager.shared.loadTodayCoursesFromApp()
            DispatchQueue.main.async {
                self.todayCourses = courses
                self.isLoading = false
            }
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
        
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
}

#Preview {
    ContentView()
}
