import Foundation

extension JwqywxApplication {
    public func checkSelectionPermission(userId: String, functionCode: String = CCZUConstants.Jwqywx.defaultSelectionFunctionCode) async throws {
        guard let authId = authorizationId else { throw CCZUError.notLoggedIn }
        let url = CCZUConstants.Jwqywx.checkSelectionPermissionURL
        let body: [String: String] = [
            "yhdm": userId,
            "gnmk": functionCode,
            "yhid": authId
        ]
        if enableDebugLogging { print("[DEBUG] checkSelectionPermission body=\(body)") }
        let (data, _) = try await postAuthenticatedJSON(url: url, json: body)
        let decoder = JSONDecoder()
        let msg = try decoder.decode(Message<[String: String]>.self, from: data)
        if msg.status != 0 { throw CCZUError.unknown("选课权限检查失败") }
        if enableDebugLogging { print("[DEBUG] checkSelectionPermission OK") }
    }

    /// 获取该年级的选课批次列表（需要先确认用户身份）
    /// - Parameter grade: 年级（如 2025）
    /// - Returns: 选课批次列表
    public func getSelectionBatches(grade: Int) async throws -> [SelectionBatch] {
        guard let userId = studentNumber else { throw CCZUError.notLoggedIn }
        let url = CCZUConstants.Jwqywx.selectionBatchesURL
        let body: [String: Any] = [
            "yhdm": userId,
            "nj": grade
        ]
        if enableDebugLogging { print("[DEBUG] getSelectionBatches body=\(body)") }
        let (data, _) = try await postAuthenticatedJSON(url: url, anyJSON: body)
        let decoder = JSONDecoder()
        let msg = try decoder.decode(Message<SelectionBatch>.self, from: data)
        if enableDebugLogging { print("[DEBUG] getSelectionBatches batches=\(msg.message.count)") }
        return msg.message
    }

    /// 获取通识类选修课对应的选课批次（优先返回名称中包含“通识”的批次）
    /// - Parameter grade: 年级
    /// - Returns: 找到的批次或 nil
    public func getGeneralElectiveSelectionBatch(grade: Int) async throws -> SelectionBatch? {
        let batches = try await getSelectionBatches(grade: grade)
        if enableDebugLogging { print("[DEBUG] getGeneralElectiveSelectionBatch batches=\(batches.map{$0.name})") }
        if let found = batches.first(where: { $0.name.contains("通识") || $0.name.contains("通识教育") || $0.name.contains("通识类") }) {
            return found
        }
        // 回退到首个批次（若没有明确标记的通识批次）
        return batches.first
    }

    /// 检查某批次的选课权限
    /// - Parameters:
    ///   - batchCode: 批次代码（如"0003-004"）
    ///   - grade: 年级
    /// - Returns: 选课权限信息
    public func checkBatchPermission(batchCode: String, grade: Int) async throws -> SelectionPermission {
        guard let authId = authorizationId else { throw CCZUError.notLoggedIn }
        let url = CCZUConstants.Jwqywx.batchPermissionURL
        let body: [String: Any] = [
            "dm": batchCode,
            "nj": grade,
            "yhid": authId
        ]
        if enableDebugLogging { print("[DEBUG] checkBatchPermission body=\(body)") }
        let (data, _) = try await postAuthenticatedJSON(url: url, anyJSON: body)
        let decoder = JSONDecoder()
        let msg = try decoder.decode(Message<SelectionPermission>.self, from: data)
        guard let perm = msg.message.first else { throw CCZUError.missingData("未获得选课权限") }
        if !perm.isAllowed { throw CCZUError.unknown("该批次对你的年级未开放选课权限") }
        if enableDebugLogging { print("[DEBUG] checkBatchPermission OK, term=\(perm.term)") }
        return perm
    }

    /// 综合前置检查后，获取当前允许批次的可选课程
    /// - Parameters:
    ///   - classCode: 班级代码
    ///   - grade: 年级（如 2025）
    /// - Returns: 可选课程列表
    public func getCurrentSelectableCoursesWithPreflight(classCode: String, grade: Int) async throws -> [SelectableCourse] {
        guard let userId = studentNumber else { throw CCZUError.notLoggedIn }
        // 1) 功能权限
        try await checkSelectionPermission(userId: userId)
        // 2) 获取批次并选择处于开放状态的批次
        let batches = try await getSelectionBatches(grade: grade)
        // 简化策略：优先选择 isOpen=true 且 xk=true 的批次；否则取最新 endDate 未过期的批次
        let candidate = batches.first { $0.isOpen && $0.isAllowed } ?? batches.sorted { ($0.endDate) > ($1.endDate) }.first
        guard let batch = candidate else { throw CCZUError.missingData("当前年级没有开放的选课批次") }
        // 3) 批次权限校验以获得正确学期
        let perm = try await checkBatchPermission(batchCode: batch.code, grade: grade)
        let term = perm.term
        // 4) 按正确学期拉取可选课程
        let courses = try await getSelectableCourses(term: term, classCode: classCode)
        if enableDebugLogging { print("[DEBUG] getCurrentSelectableCoursesWithPreflight term=\(term), courses=\(courses.count)") }
        return courses
    }
    /// 查询选课状态/课程列表（xk_xh_kbk）
    public func getSelectableCourses(term: String, classCode: String) async throws -> [SelectableCourse] {
        guard let authId = authorizationId, let stuNum = studentNumber else { throw CCZUError.notLoggedIn }
        let url = CCZUConstants.Jwqywx.selectableCoursesURL
        let body: [String: String] = [
            "xq": term,
            "bh": classCode,
            "xh": stuNum,
            "yhid": authId
        ]
        if enableDebugLogging { print("[DEBUG] xk_xh_kbk body=\(body)") }
        let (data, _) = try await postAuthenticatedJSON(url: url, json: body)
        let decoder = JSONDecoder()
        let msg = try decoder.decode(Message<SelectableCourse>.self, from: data)
        if enableDebugLogging { print("[DEBUG] xk_xh_kbk items=\(msg.message.count)") }
        return msg.message
    }

    /// 查询当前学期、本人班级的可选课程
    public func getCurrentSelectableCourses() async throws -> [SelectableCourse] {
        let terms = try await getTerms()
        guard let currentTerm = terms.message.first?.term else { throw CCZUError.missingData(CCZUConstants.Jwqywx.noTermFoundMessage) }
        let info = try await getStudentBasicInfo()
        guard let basic = info.message.first else { throw CCZUError.missingData(CCZUConstants.Jwqywx.noBasicInfoMessage) }
        return try await getSelectableCourses(term: currentTerm, classCode: basic.classCode)
    }

    /// 选课（xk_insert_xfz），最多5门一组，自动分片
    /// - Parameters:
    ///   - term: 学期，如 "25-26-2"
    ///   - items: 待选课程（来自 getSelectableCourses）
    /// - Throws: 抛出首个失败错误
    public func selectCourses(term: String, items: [SelectableCourse]) async throws {
        guard let authId = authorizationId, let stuNum = studentNumber else { throw CCZUError.notLoggedIn }

        // 获取姓名用于 xm 字段
        let basic = try await getStudentBasicInfo()
        let name = basic.message.first?.name ?? ""

        // 过滤：仅对未选(xkqk为空)的课程进行提交
        let pending = items.filter { $0.selectionStatus.isEmpty }
        if enableDebugLogging { print("[DEBUG] select pending count=\(pending.count) total=\(items.count)") }

        // 按5个分片
        let chunks: [[SelectableCourse]] = stride(from: 0, to: pending.count, by: 5).map {
            Array(pending[$0..<min($0+5, pending.count)])
        }

        let url = CCZUConstants.Jwqywx.selectCoursesURL
        let decoder = JSONDecoder()

        for chunk in chunks where !chunk.isEmpty {
            // postdata 需要与抓包一致的字段集合
            let postdata: [[String: Any]] = chunk.map { c in
                [
                    "xq": term,
                    "bh": c.classCode,
                    "bj": c.className,
                    "kcdm": c.courseCode,
                    "kcmc": c.courseName,
                    "kch": c.courseSerial,
                    "lbdh": c.categoryCode,
                    "xs": c.hours,
                    "xf": c.credits,
                    "ksfs": c.examTypeName,
                    "kkrs": c.capacity,
                    "kcxbdm": c.courseAttrCode,
                    "jsdm": c.teacherCode,
                    "jsmc": c.teacherName,
                    "ksxzm": c.isExamType,
                    "ksfsm": c.examMode,
                    "idn": c.idn,
                    "xkqk": c.selectionStatus,
                    "xkidn": c.selectedId,
                    "xklb": c.studyType
                ]
            }

            // 构造 JSON 体
            let payload: [String: Any] = [
                "xq": term,
                "xh": stuNum,
                "xm": name,
                "postdata": postdata,
                "yhid": authId
            ]
            if enableDebugLogging { print("[DEBUG] xk_insert_xfz chunk size=\(chunk.count)") }

            // Only an explicit authentication rejection is retried by the transport.
            let (data, response) = try await postAuthenticatedJSON(url: url, anyJSON: payload)
            guard response.statusCode == 200 else {
                throw CCZUError.unknown("HTTP Status code: \(response.statusCode)")
            }
            let res = try decoder.decode(SimpleJWResponse.self, from: data)
            if enableDebugLogging { print("[DEBUG] xk_insert_xfz status=\(res.status) messageInt=\(String(describing: res.messageInt)) messageString=\(String(describing: res.messageString))") }
            if res.status == 0 {
                // Accepted; continue to the next chunk.
            } else {
                throw CCZUError.unknown("选课失败: status=\(res.status), message=\(res.messageString ?? String(res.messageInt ?? -1))")
            }
        }
    }

    /// 根据 idn 列表选课（自动查询并匹配条目）
    public func selectCoursesByIdn(term: String, classCode: String, idns: [Int]) async throws {
        let all = try await getSelectableCourses(term: term, classCode: classCode)
        let map = Dictionary(uniqueKeysWithValues: all.map { ($0.idn, $0) })
        let items = idns.compactMap { map[$0] }
        guard !items.isEmpty else { return }
        try await selectCourses(term: term, items: items)
    }

    /// 批量退课（xk_delete_xfzxkmd）
    /// - Parameter selectedIds: xkidn 列表（已选课程记录ID）
    public func dropCourses(selectedIds: [Int]) async throws -> String {
        guard let authId = authorizationId else { throw CCZUError.notLoggedIn }
        guard !selectedIds.isEmpty else { return "" }

        let url = CCZUConstants.Jwqywx.dropCoursesURL
        // 按抓包格式，结尾带逗号
        let idnlist = selectedIds.map(String.init).joined(separator: ",") + ","
        let body: [String: String] = [
            "idnlist": idnlist,
            "yhid": authId
        ]
        let (data, response) = try await postAuthenticatedJSON(url: url, json: body)
        guard response.statusCode == 200 else {
            throw CCZUError.unknown("HTTP Status code: \(response.statusCode)")
        }
        let decoder = JSONDecoder()
        let res = try decoder.decode(SimpleJWResponse.self, from: data)
        if res.status != 0 {
            throw CCZUError.unknown("退课失败: status=\(res.status), message=\(res.messageString ?? String(res.messageInt ?? -1))")
        }
        return res.messageString ?? ""
    }
}
