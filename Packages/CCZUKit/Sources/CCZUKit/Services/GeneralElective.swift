import Foundation

extension JwqywxApplication {
    public func getGeneralElectiveCourses(term: String, classCode: String, grade: Int, campus: String) async throws -> [GeneralElectiveCourse] {
        guard let authId = authorizationId, let stuNum = studentNumber else { throw CCZUError.notLoggedIn }
        let url = CCZUConstants.Jwqywx.generalElectiveCoursesURL
        let body: [String: Any] = [
            "xq": term,
            "bh": classCode,
            "nj": grade,
            "bmmc": campus,
            "xh": stuNum,
            "yhid": authId
        ]
        if enableDebugLogging { print("[DEBUG] getGeneralElectiveCourses body=\(body)") }
        let (data, _) = try await postAuthenticatedJSON(url: url, anyJSON: body)
        let decoder = JSONDecoder()
        let msg = try decoder.decode(Message<GeneralElectiveCourse>.self, from: data)
        if enableDebugLogging { print("[DEBUG] getGeneralElectiveCourses courses=\(msg.message.count)") }

        // 尝试请求实际已选人数并合并（接口：yxk_xk_xkrs_gx），如果失败则返回原始数据
        do {
            let actuals = try await getGeneralElectiveActualSelectedCounts(term: term, classCode: classCode, grade: grade, campus: campus)
            let map = Dictionary(uniqueKeysWithValues: actuals.map { ($0.courseSerial, $0.selectedCount) })
            let merged: [GeneralElectiveCourse] = msg.message.map { course in
                if let realSelected = map[course.courseSerial] {
                    let newAvailable = max(0, course.capacity - realSelected)
                    return GeneralElectiveCourse(
                        term: course.term,
                        courseSerial: course.courseSerial,
                        courseCode: course.courseCode,
                        courseName: course.courseName,
                        teacherCode: course.teacherCode,
                        teacherName: course.teacherName,
                        hours: course.hours,
                        credits: course.credits,
                        categoryCode: course.categoryCode,
                        categoryName: course.categoryName,
                        timeDescription: course.timeDescription,
                        capacity: course.capacity,
                        selectedCount: realSelected,
                        availableCount: newAvailable,
                        batchCode: course.batchCode,
                        description: course.description,
                        campus: course.campus,
                        week: course.week,
                        startSlot: course.startSlot,
                        endSlot: course.endSlot
                    )
                } else {
                    return course
                }
            }
            return merged
        } catch {
            if enableDebugLogging { print("[WARN] 合并实际已选人数失败: \(error)") }
            throw error
        }
    }

    /// 获取通识类课程的实际已选人数映射（来自 yxk_xk_xkrs_gx）
    private func getGeneralElectiveActualSelectedCounts(term: String, classCode: String, grade: Int, campus: String) async throws -> [ActualSelectedCount] {
        guard let authId = authorizationId, let stuNum = studentNumber else { throw CCZUError.notLoggedIn }
        let url = CCZUConstants.Jwqywx.generalElectiveActualCountsURL
        let body: [String: Any] = [
            "xq": term,
            "bh": classCode,
            "nj": grade,
            "bmmc": campus,
            "xh": stuNum,
            "yhid": authId
        ]
        if enableDebugLogging { print("[DEBUG] getGeneralElectiveActualSelectedCounts body=\(body)") }
        let (data, _) = try await postAuthenticatedJSON(url: url, anyJSON: body)
        let decoder = JSONDecoder()
        let msg = try decoder.decode(Message<ActualSelectedCount>.self, from: data)
        if enableDebugLogging { print("[DEBUG] getGeneralElectiveActualSelectedCounts items=\(msg.message.count)") }
        return msg.message
    }

    /// 获取已选通识类选修课程（yxk_xk_xh_yxkc_gx）
    /// - Parameter term: 学期
    /// - Returns: 已选课程列表
    public func getSelectedGeneralElectiveCourses(term: String) async throws -> [SelectedGeneralElectiveCourse] {
        guard let authId = authorizationId, let stuNum = studentNumber else { throw CCZUError.notLoggedIn }
        let url = CCZUConstants.Jwqywx.selectedGeneralElectiveCoursesURL
        let body: [String: String] = [
            "xq": term,
            "xh": stuNum,
            "yhid": authId
        ]
        if enableDebugLogging { print("[DEBUG] getSelectedGeneralElectiveCourses body=\(body)") }
        let (data, _) = try await postAuthenticatedJSON(url: url, json: body)
        if enableDebugLogging {
            if let s = String(data: data, encoding: .utf8) {
                print("[DEBUG] getSelectedGeneralElectiveCourses raw response: \(s)")
            } else {
                print("[DEBUG] getSelectedGeneralElectiveCourses raw response: <binary>")
            }
        }
        let decoder = JSONDecoder()
        let msg = try decoder.decode(Message<SelectedGeneralElectiveCourse>.self, from: data)
        if enableDebugLogging { print("[DEBUG] getSelectedGeneralElectiveCourses courses=\(msg.message.count)") }
        return msg.message
    }

    /// 检查通识类选修课程批次权限（yxk_xkqx_dm_nj）
    /// - Parameters:
    ///   - batchCode: 批次代码
    ///   - grade: 年级
    /// - Returns: 权限信息
    public func checkGeneralElectivePermission(batchCode: String, grade: Int) async throws -> GeneralElectivePermission {
        guard let authId = authorizationId else { throw CCZUError.notLoggedIn }
        let url = CCZUConstants.Jwqywx.checkGeneralElectivePermissionURL
        let body: [String: Any] = [
            "dm": batchCode,
            "nj": grade,
            "yhid": authId
        ]
        if enableDebugLogging { print("[DEBUG] checkGeneralElectivePermission body=\(body)") }
        let (data, _) = try await postAuthenticatedJSON(url: url, anyJSON: body)
        let decoder = JSONDecoder()
        let msg = try decoder.decode(Message<GeneralElectivePermission>.self, from: data)
        guard let perm = msg.message.first else { throw CCZUError.missingData("未获得通识选课权限") }
        if enableDebugLogging { print("[DEBUG] checkGeneralElectivePermission OK, term=\(perm.term)") }
        return perm
    }

    /// 选通识类选修课程（yxk_xk_insert_ggxx），最多2门一组，自动分片
    /// - Parameters:
    ///   - term: 学期
    ///   - courses: 待选课程（来自 getGeneralElectiveCourses）
    /// - Throws: 抛出首个失败错误
    public func selectGeneralElectiveCourses(term: String, courses: [GeneralElectiveCourse]) async throws {
        guard let authId = authorizationId, let stuNum = studentNumber else { throw CCZUError.notLoggedIn }

        // 获取姓名用于 xm 字段（暂时未使用）
        let basic = try await getStudentBasicInfo()
        _ = basic.message.first?.name ?? ""

        // 过滤：仅对可选课程进行提交（kxrs > 0）
        let available = courses.filter { $0.availableCount > 0 }
        if enableDebugLogging { print("[DEBUG] selectGeneralElective available count=\(available.count) total=\(courses.count)") }

        // 按2个分片（通识选课最多2门）
        let chunks: [[GeneralElectiveCourse]] = stride(from: 0, to: available.count, by: 2).map {
            Array(available[$0..<min($0+2, available.count)])
        }

        let url = CCZUConstants.Jwqywx.selectGeneralElectiveCoursesURL
        let decoder = JSONDecoder()

        for chunk in chunks where !chunk.isEmpty {
            // 构造请求体
            let payload: [String: Any] = [
                "xq": term,
                "xh": stuNum,
                "kcxh": chunk[0].courseSerial,
                "zc": chunk[0].week,
                "jc1": chunk[0].startSlot,
                "jc2": chunk[0].endSlot,
                "xxrs": chunk[0].capacity,
                "xkmc": chunk.count,  // 选课门数
                "yhid": authId
            ]
            if enableDebugLogging { print("[DEBUG] yxk_xk_insert_ggxx chunk size=\(chunk.count), courseSerial=\(chunk[0].courseSerial)") }

            // Only an explicit authentication rejection is retried by the transport.
            let (data, response) = try await postAuthenticatedJSON(url: url, anyJSON: payload)
            guard response.statusCode == 200 else {
                throw CCZUError.unknown("HTTP Status code: \(response.statusCode)")
            }
            let res = try decoder.decode(SimpleJWResponse.self, from: data)
            if enableDebugLogging { print("[DEBUG] yxk_xk_insert_ggxx status=\(res.status) messageInt=\(String(describing: res.messageInt)) messageString=\(String(describing: res.messageString))") }
            if res.status == 0 {
                // Accepted; continue to the next chunk.
            } else {
                throw CCZUError.unknown("通识选课失败: status=\(res.status), message=\(res.messageString ?? String(res.messageInt ?? -1))")
            }
        }
    }

    /// 退通识类选修课程（yxk_xk_delete_ggxx）
    /// - Parameters:
    ///   - term: 学期
    ///   - courseSerial: 课程序号
    /// - Throws: 退课失败时抛错
    public func dropGeneralElectiveCourse(term: String, courseSerial: Int) async throws {
        guard let authId = authorizationId, let stuNum = studentNumber else { throw CCZUError.notLoggedIn }
        let url = CCZUConstants.Jwqywx.dropGeneralElectiveCourseURL
        let body: [String: Any] = [
            "xq": term,
            "xh": stuNum,
            "kcxh": courseSerial,
            "yhid": authId
        ]
        if enableDebugLogging { print("[DEBUG] dropGeneralElectiveCourse body=\(body)") }
        let (data, response) = try await postAuthenticatedJSON(url: url, anyJSON: body)
        guard response.statusCode == 200 else {
            throw CCZUError.unknown("HTTP Status code: \(response.statusCode)")
        }
        let decoder = JSONDecoder()
        let res = try decoder.decode(SimpleJWResponse.self, from: data)
        if res.status != 0 {
            throw CCZUError.unknown("退通识选课失败: status=\(res.status), message=\(res.messageString ?? String(res.messageInt ?? -1))")
        }
        if enableDebugLogging { print("[DEBUG] dropGeneralElectiveCourse OK") }
    }
}
