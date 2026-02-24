import Foundation
import CCZUKit

func isGeneralCourseAvailable(_ course: GeneralElectiveCourse) -> Bool {
    course.availableCount > 0 || course.selectedCount < course.capacity
}

enum CourseSelectionMode: String, CaseIterable {
    case elective = "course_selection.mode.elective"
    case general = "course_selection.mode.general"
}

enum LearnMode: String, CaseIterable {
    case online = "course.learn_mode.online"
    case offline = "course.learn_mode.offline"
}

enum GeneralFilter: String {
    case all = "common.all"
    case available = "course.filter.available"
    case selected = "course_selection.selected"
}

struct CourseSelectionItem: Identifiable, Equatable {
    let raw: SelectableCourse

    var id: Int { raw.idn }
    var idn: Int { raw.idn }
    var isRemoteSelected: Bool {
        !raw.selectionStatus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || raw.selectedId > 0
    }

    static func == (lhs: CourseSelectionItem, rhs: CourseSelectionItem) -> Bool {
        lhs.idn == rhs.idn
    }
}

struct GeneralElectiveCourseItem: Identifiable, Equatable {
    let raw: GeneralElectiveCourse
    let learnMode: LearnMode

    var id: Int { raw.courseSerial }
    var courseSerial: Int { raw.courseSerial }

    init(raw: GeneralElectiveCourse) {
        self.raw = raw
        let description = raw.description ?? ""
        let isOnline = description.contains(NSLocalizedString("course.online_learning", comment: "在线学习")) ||
            description.contains(NSLocalizedString("course.learn_mode.online", comment: "线上")) ||
            description.contains(NSLocalizedString("course.platform.zhihuishu", comment: "智慧树"))
        self.learnMode = isOnline ? .online : .offline
    }

    static func == (lhs: GeneralElectiveCourseItem, rhs: GeneralElectiveCourseItem) -> Bool {
        lhs.id == rhs.id
    }
}
