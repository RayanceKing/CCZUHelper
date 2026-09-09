import Foundation

extension JwqywxApplication {
    /// 获取学生基本信息
    public func getStudentBasicInfo() async throws -> Message<StudentBasicInfo> {
        guard let authId = authorizationId else {
            throw CCZUError.notLoggedIn
        }

        guard let stuNum = studentNumber else {
            throw CCZUError.notLoggedIn
        }

        let url = CCZUConstants.Jwqywx.studentBasicInfoURL
        let requestData = [
            "xh": stuNum,
            "yhid": authId
        ]

        let (data, _) = try await postAuthenticatedJSON(url: url, json: requestData)

        let decoder = JSONDecoder()
        return try decoder.decode(Message<StudentBasicInfo>.self, from: data)
    }

    // MARK: - 课表查询

    /// 获取指定学期的课表
    public func getClassSchedule(term: String) async throws -> [[RawCourse]] {
        guard let authId = authorizationId else {
            throw CCZUError.notLoggedIn
        }

        let url = CCZUConstants.Jwqywx.classScheduleURL

        let requestData: [String: String] = [
            "xh": client.account.username,
            "xq": term,
            "yhid": authId
        ]

        let (data, _) = try await postAuthenticatedJSON(url: url, json: requestData)

        let decoder = JSONDecoder()
        let jsonObject = try decoder.decode(Message<CourseScheduleRow>.self, from: data)

        // 使用补充接口兜底授课教师（失败时不影响主流程）
        let fallbackTeachers = try await fetchCourseTeacherSupplements(term: term, authId: authId)
        return jsonObject.message.map { $0.toCourses(fallbackTeachersByCourseName: fallbackTeachers) }
    }

    /// 获取当前学期的课表
    public func getCurrentClassSchedule() async throws -> [[RawCourse]] {
        let terms = try await getTerms()
        guard let currentTerm = terms.message.first?.term else {
            throw CCZUError.missingData(CCZUConstants.Jwqywx.noTermFoundMessage)
        }
        return try await getClassSchedule(term: currentTerm)
    }

    private func fetchCourseTeacherSupplements(term: String, authId: String) async throws -> [String: String] {
        let url = CCZUConstants.Jwqywx.courseTeacherSupplementURL
        let requestData: [String: String] = [
            "xh": client.account.username,
            "xq": term,
            "yhid": authId
        ]

        let (data, _) = try await postAuthenticatedJSON(url: url, json: requestData)
        let decoder = JSONDecoder()
        let message = try decoder.decode(Message<CourseTeacherSupplementItem>.self, from: data)

        var result: [String: String] = [:]
        for item in message.message {
            guard !item.courseName.isEmpty, !item.teacherName.isEmpty else { continue }

            // 合并同名课程的多个教师，避免覆盖
            if let existing = result[item.courseName], !existing.isEmpty, !existing.contains(item.teacherName) {
                result[item.courseName] = "\(existing),\(item.teacherName)"
            } else if result[item.courseName] == nil {
                result[item.courseName] = item.teacherName
            }

            let normalizedName = item.courseName
                .replacingOccurrences(of: "（", with: "(")
                .replacingOccurrences(of: "）", with: ")")
            if normalizedName != item.courseName, result[normalizedName] == nil {
                result[normalizedName] = result[item.courseName]
            }
        }
        return result
    }

    // MARK: - 考试安排查询

    /// 获取指定学期的考试安排
    /// - Parameters:
    ///   - term: 学期，格式如 "25-26-1"，如果为空则获取当前学期
    ///   - examType: 考试类型，默认为 CCZUConstants.Jwqywx.defaultExamType
    /// - Returns: 考试安排列表
    public func getExamArrangements(term: String? = nil, examType: String = CCZUConstants.Jwqywx.defaultExamType) async throws -> [ExamArrangement] {
        guard let authId = authorizationId else {
            throw CCZUError.notLoggedIn
        }

        // 如果没有指定学期，获取当前学期
        let examTerm: String
        if let term = term {
            examTerm = term
        } else {
            let terms = try await getTerms()
            guard let currentTerm = terms.message.first?.term else {
                throw CCZUError.missingData(CCZUConstants.Jwqywx.noTermFoundMessage)
            }
            examTerm = currentTerm
        }

        let url = CCZUConstants.Jwqywx.examArrangementsURL

        let requestData: [String: String] = [
            "xq": examTerm,
            "yhdm": client.account.username,
            "dm": examType,
            "yhid": authId
        ]

        let (data, _) = try await postAuthenticatedJSON(url: url, json: requestData)

        let decoder = JSONDecoder()
        let message = try decoder.decode(Message<ExamArrangement>.self, from: data)

        return message.message
    }

    /// 获取当前学期的考试安排
    public func getCurrentExamArrangements() async throws -> [ExamArrangement] {
        return try await getExamArrangements()
    }

    // MARK: - 教师评价

    /// 获取指定学期可评价的课程列表
    /// - Parameter term: 学期，格式如 "25-26-1"
    /// - Returns: 可评价课程列表
    public func getEvaluatableClasses(term: String) async throws -> [EvaluatableClass] {
        guard let authId = authorizationId else {
            throw CCZUError.notLoggedIn
        }

        let url = CCZUConstants.Jwqywx.evaluatableClassesURL

        let requestData: [String: String] = [
            "pjxq": term,
            "xh": client.account.username,
            "yhid": authId
        ]

        let (data, _) = try await postAuthenticatedJSON(url: url, json: requestData)

        let decoder = JSONDecoder()
        let message = try decoder.decode(Message<EvaluatableClass>.self, from: data)

        return message.message
    }

    /// 获取当前学期可评价的课程列表
    public func getCurrentEvaluatableClasses() async throws -> [EvaluatableClass] {
        let terms = try await getTerms()
        guard let currentTerm = terms.message.first?.term else {
            throw CCZUError.missingData(CCZUConstants.Jwqywx.noTermFoundMessage)
        }
        return try await getEvaluatableClasses(term: currentTerm)
    }

    /// 获取指定学期已提交的评价信息
    /// - Parameter term: 学期，格式如 "25-26-1"
    /// - Returns: 已提交的评价列表
    public func getSubmittedEvaluations(term: String) async throws -> [SubmittedEvaluation] {
        let url = CCZUConstants.Jwqywx.submittedEvaluationsURL

        let requestData: [String: String] = [
            "pjxq": term,
            "xh": client.account.username
        ]

        let (data, _) = try await postAuthenticatedJSON(url: url, json: requestData)

        let decoder = JSONDecoder()
        let message = try decoder.decode(Message<SubmittedEvaluation>.self, from: data)

        return message.message
    }

    /// 获取当前学期已提交的评价信息
    public func getCurrentSubmittedEvaluations() async throws -> [SubmittedEvaluation] {
        let terms = try await getTerms()
        guard let currentTerm = terms.message.first?.term else {
            throw CCZUError.missingData(CCZUConstants.Jwqywx.noTermFoundMessage)
        }
        return try await getSubmittedEvaluations(term: currentTerm)
    }

    /// 提交教师评价
    /// - Parameters:
    ///   - term: 学期，格式如 "25-26-1"
    ///   - evaluatableClass: 可评价课程信息
    ///   - overallScore: 总体评分，建议值为90
    ///   - scores: 各项评分数组，例如 [100,80,100,80,100,80]
    ///   - comments: 评价意见
    public func submitTeacherEvaluation(
        term: String,
        evaluatableClass: EvaluatableClass,
        overallScore: Int,
        scores: [Int],
        comments: String
    ) async throws {
        guard let authId = authorizationId else {
            throw CCZUError.notLoggedIn
        }

        // 将分数数组转换为逗号分隔的字符串，末尾加逗号
        let scoresString = scores.map(String.init).joined(separator: ",") + ","

        let url = CCZUConstants.Jwqywx.submitTeacherEvaluationURL

        let requestData: [String: String] = [
            "pjxq": term,
            "yhdm": client.account.username,
            "jsdm": evaluatableClass.teacherCode,
            "kcdm": evaluatableClass.courseCode,
            "zhdf": String(overallScore),
            "pjjg": scoresString,
            "yjjy": comments,
            "yhid": authId
        ]

        let (_, response) = try await postAuthenticatedJSON(url: url, json: requestData)

        guard response.statusCode == 200 else {
            throw CCZUError.unknown("HTTP Status code: \(response.statusCode)")
        }
    }
}
