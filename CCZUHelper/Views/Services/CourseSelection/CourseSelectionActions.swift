import SwiftUI
import CCZUKit
#if canImport(UIKit)
import UIKit
#endif

extension CourseSelectionView {
    func loadCourses() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let app = try await settings.ensureJwqywxLoggedIn()
            let basicInfo = try await app.getStudentBasicInfo()
            guard let info = basicInfo.message.first else {
                throw CCZUError.missingData(NSLocalizedString("error.missing_student_info", comment: "无法获取学生基本信息"))
            }
            let classCode = info.classCode
            let grade = info.grade

            let courses = try await app.getCurrentSelectableCoursesWithPreflight(classCode: classCode, grade: grade)
            let items = courses.map { CourseSelectionItem(raw: $0) }

            await MainActor.run {
                availableCourses = items
                selectedCourseIds = Set(items.filter { $0.isRemoteSelected }.map { $0.idn })
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    func loadGeneralCourses() async {
        await MainActor.run {
            isGeneralLoading = true
            generalErrorMessage = nil
        }

        do {
            let app = try await settings.ensureJwqywxLoggedIn()
            let basicInfo = try await app.getStudentBasicInfo()
            guard let info = basicInfo.message.first else {
                throw CCZUError.missingData(NSLocalizedString("error.missing_student_info", comment: "无法获取学生基本信息"))
            }

            let term: String
            if let batch = try await app.getGeneralElectiveSelectionBatch(grade: info.grade) {
                term = batch.term
            } else {
                let terms = try await app.getTerms()
                guard let t = terms.message.first?.term else {
                    throw CCZUError.missingData(NSLocalizedString("error.missing_term", comment: "无法获取学期信息"))
                }
                term = t
            }

            let courses = try await app.getGeneralElectiveCourses(
                term: term,
                classCode: info.classCode,
                grade: info.grade,
                campus: info.campus
            )

            let items = courses.map { GeneralElectiveCourseItem(raw: $0) }

            var selectedCourseSerials: Set<Int> = []
            do {
                let selected = try await app.getSelectedGeneralElectiveCourses(term: term)
                selectedCourseSerials = Set(selected.map { $0.courseSerial })
            } catch {
                if app.enableDebugLogging {
                    print("[WARN] \(NSLocalizedString("course_selection.get_selected_general_failed", comment: "获取已选通识课程失败")): \(error)")
                }
            }

            await MainActor.run {
                availableGeneralCourses = items
                selectedGeneralCourseIds = selectedCourseSerials
                isGeneralLoading = false
                print("[DEBUG] availableGeneralCourses count: \(items.count)")
                print("[DEBUG] selectedGeneralCourseIds: \(selectedCourseSerials)")
                let selectedDetails = items.filter { selectedCourseSerials.contains($0.courseSerial) }.map { "\($0.courseSerial): \($0.raw.courseName)" }
                print("[DEBUG] selected general courses: \(selectedDetails)")
            }
        } catch {
            await MainActor.run {
                isGeneralLoading = false
                generalErrorMessage = error.localizedDescription
            }
        }
    }

    func toggleCourseSelection(_ course: CourseSelectionItem) {
        if selectedCourseIds.contains(course.idn) {
            selectedCourseIds.remove(course.idn)
        } else {
            selectedCourseIds.insert(course.idn)
        }

        #if !os(visionOS) && canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }

    func toggleGeneralCourseSelection(_ course: GeneralElectiveCourseItem) {
        if selectedGeneralCourseIds.contains(course.courseSerial) {
            selectedGeneralCourseIds.remove(course.courseSerial)
        } else {
            if selectedGeneralCourseIds.count < 2 {
                selectedGeneralCourseIds.insert(course.courseSerial)
            } else {
                generalErrorMessage = NSLocalizedString("general.max_two_error", comment: "通识课最多只能选择2门")
            }
        }

        #if !os(visionOS) && canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }

    func selectAll() {
        let allIds = Set(filteredCourses.map { $0.idn })
        selectedCourseIds.formUnion(allIds)
        #if !os(visionOS) && canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }

    func submitSelection() async {
        guard !isSubmitting else { return }
        await MainActor.run { isSubmitting = true }
        defer { Task { @MainActor in isSubmitting = false } }

        do {
            let app = try await settings.ensureJwqywxLoggedIn()

            let toSelect = availableCourses.filter { selectedCourseIds.contains($0.idn) && !$0.isRemoteSelected }
            let toDropIds = availableCourses
                .filter { !selectedCourseIds.contains($0.idn) && $0.isRemoteSelected }
                .compactMap { $0.raw.selectedId > 0 ? $0.raw.selectedId : nil }

            if !toSelect.isEmpty {
                let term = toSelect.first?.raw.term ?? ""
                guard !term.isEmpty else {
                    throw CCZUError.missingData(NSLocalizedString("error.missing_term", comment: "无法获取选课学期"))
                }
                try await app.selectCourses(term: term, items: toSelect.map { $0.raw })
            }

            if !toDropIds.isEmpty {
                _ = try await app.dropCourses(selectedIds: toDropIds)
            }

            await loadCourses()

            #if !os(visionOS) && canImport(UIKit)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            #endif
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
            #if !os(visionOS) && canImport(UIKit)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            #endif
        }
    }

    func submitGeneralSelection() async {
        guard !isSubmitting else { return }
        await MainActor.run { isSubmitting = true }
        defer { Task { @MainActor in isSubmitting = false } }

        do {
            let app = try await settings.ensureJwqywxLoggedIn()
            let basicInfo = try await app.getStudentBasicInfo()
            guard let info = basicInfo.message.first else {
                throw CCZUError.missingData(NSLocalizedString("error.missing_student_info", comment: "无法获取学生基本信息"))
            }

            let coursesToSelect = availableGeneralCourses.filter {
                selectedGeneralCourseIds.contains($0.courseSerial)
            }

            guard !coursesToSelect.isEmpty else {
                throw CCZUError.missingData(NSLocalizedString("course_selection.please_select", comment: "请先选择课程"))
            }

            let term: String
            if let batch = try await app.getGeneralElectiveSelectionBatch(grade: info.grade) {
                term = batch.term
            } else {
                let terms = try await app.getTerms()
                guard let t = terms.message.first?.term else {
                    throw CCZUError.missingData(NSLocalizedString("error.missing_term", comment: "无法获取选课学期"))
                }
                term = t
            }

            try await app.selectGeneralElectiveCourses(
                term: term,
                courses: coursesToSelect.map { $0.raw }
            )

            await loadGeneralCourses()

            #if !os(visionOS) && canImport(UIKit)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            #endif
        } catch {
            await MainActor.run {
                generalErrorMessage = error.localizedDescription
            }
            #if !os(visionOS) && canImport(UIKit)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            #endif
        }
    }

    func dropAllSelectedCourses() async {
        guard !isSubmitting else { return }
        await MainActor.run { isSubmitting = true }
        defer { Task { @MainActor in isSubmitting = false } }

        do {
            let app = try await settings.ensureJwqywxLoggedIn()
            let ids = availableCourses
                .filter { $0.isRemoteSelected }
                .compactMap { $0.raw.selectedId > 0 ? $0.raw.selectedId : nil }
            guard !ids.isEmpty else { return }
            _ = try await app.dropCourses(selectedIds: ids)
            await loadCourses()
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    func dropSelectedGeneralCourses() async {
        guard !isSubmitting else { return }
        await MainActor.run { isSubmitting = true }
        defer { Task { @MainActor in isSubmitting = false } }

        do {
            let app = try await settings.ensureJwqywxLoggedIn()
            let basicInfo = try await app.getStudentBasicInfo()
            guard let info = basicInfo.message.first else {
                throw CCZUError.missingData(NSLocalizedString("error.missing_student_info", comment: "无法获取学生基本信息"))
            }

            let term: String
            if let batch = try await app.getGeneralElectiveSelectionBatch(grade: info.grade) {
                term = batch.term
            } else {
                let terms = try await app.getTerms()
                guard let t = terms.message.first?.term else {
                    throw CCZUError.missingData(NSLocalizedString("error.missing_term", comment: "无法获取学生学期信息"))
                }
                term = t
            }

            let selected = try await app.getSelectedGeneralElectiveCourses(term: term)
            guard !selected.isEmpty else {
                await MainActor.run { generalErrorMessage = NSLocalizedString("course_selection.no_general_selected", comment: "未选通识课") }
                return
            }

            for item in selected {
                try await app.dropGeneralElectiveCourse(term: term, courseSerial: item.courseSerial)
            }

            await loadGeneralCourses()

            #if !os(visionOS) && canImport(UIKit)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            #endif
        } catch {
            await MainActor.run { generalErrorMessage = error.localizedDescription }
            #if !os(visionOS) && canImport(UIKit)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            #endif
        }
    }

    func categoryName(for course: CourseSelectionItem) -> String {
        let code = course.raw.courseAttrCode.uppercased()
        if code.hasPrefix("A") { return NSLocalizedString("course.category.required", comment: "必修课") }
        if code.hasPrefix("B") { return NSLocalizedString("course.category.major", comment: "专业课") }
        if code.hasPrefix("G") { return NSLocalizedString("course.category.general", comment: "通识课") }
        return NSLocalizedString("course.category.elective", comment: "选修课")
    }
}
