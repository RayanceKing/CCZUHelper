import SwiftUI
import CCZUKit

struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isSelected ? Color.blue :
                    {
                        #if os(macOS)
                        return Color(nsColor: .controlBackgroundColor)
                        #else
                        return Color(uiColor: .secondarySystemGroupedBackground)
                        #endif
                    }()
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct CourseSelectionRow: View {
    let course: CourseSelectionItem
    let isSelected: Bool
    let isRemoteSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(course.raw.courseName)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    HStack(spacing: 12) {
                        Label(course.raw.teacherName, systemImage: "person")
                        Label(String(format: NSLocalizedString("course.credits_format", comment: "%.1f 学分"), course.raw.credits), systemImage: "book")
                        Label(course.raw.examTypeName, systemImage: "list.bullet")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Text("\(course.raw.courseCode) · \(course.raw.courseSerial)")
                        Text(String(format: NSLocalizedString("course_selection.capacity_format", comment: "容量 %lld"), course.raw.capacity))
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }

                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? .blue : .secondary)
                        .font(.title2)

                    if isRemoteSelected {
                        Text(NSLocalizedString("course_selection.selected", comment: "已选"))
                            .font(.caption2)
                            .foregroundStyle(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

struct GeneralCourseSelectionRow: View {
    let course: GeneralElectiveCourseItem
    let isSelected: Bool
    let isRemoteSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(course.raw.courseName)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    HStack(spacing: 12) {
                        Label(course.raw.teacherName, systemImage: "person")
                        Label(course.raw.categoryName, systemImage: "tag")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        if let description = course.raw.description, !description.isEmpty {
                            Text(description)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(2)
                        }

                        HStack(spacing: 8) {
                            Label(course.learnMode.rawValue.localized, systemImage: course.learnMode == .online ? "wifi" : "building.2")
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(course.learnMode == .online ? Color.blue : Color.orange)
                                .clipShape(Capsule())

                            Text("\(NSLocalizedString("course_selection.available_format", comment: "可选"))：\(course.raw.availableCount)/\(course.raw.capacity)")
                                .font(.caption2)
                                .foregroundStyle(isGeneralCourseAvailable(course.raw) ? .green : .red)
                        }
                    }

                    HStack(spacing: 8) {
                        Text("\(NSLocalizedString("course_selection.week_format", comment: "周次："))\(course.raw.week)")
                        Text("\(NSLocalizedString("course_selection.slot_format", comment: "节次："))\(course.raw.startSlot)-\(course.raw.endSlot)")
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }

                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? .blue : .secondary)
                        .font(.title2)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}
