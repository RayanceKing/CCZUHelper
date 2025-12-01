import SwiftUI
import SwiftData

/// 课程表（低版本回退）
struct ScheduleViewFallback: View {
    @Environment(AppSettings.self) private var settings
    @Query private var courses: [Course]
    @State private var selectedDate: Date = Date()

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                // 顶部：简化的日期与今日按钮（无 glass）
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(yearMonthString)
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("第\(currentWeekNumber)周")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button("今日") {
                        selectedDate = Date()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // 简化课程列表（避免复杂网格、材质等）
                List(coursesForCurrentWeek(), id: \.id) { course in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(course.name)
                            .font(.headline)
                        HStack {
                            Text(course.location)
                            Text("·")
                            Text(course.teacher)
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("课程表")
        }
    }

    private var yearMonthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: selectedDate)
    }

    private var currentWeekNumber: Int {
        calendar.component(.weekOfYear, from: selectedDate)
    }

    private func coursesForCurrentWeek() -> [Course] {
        let weekNumber = currentWeekNumber
        return courses.filter { $0.weeks.contains(weekNumber) }
    }
}

#Preview {
    ScheduleViewFallback()
        .environment(AppSettings())
        .modelContainer(for: [Course.self, Schedule.self], inMemory: true)
}
