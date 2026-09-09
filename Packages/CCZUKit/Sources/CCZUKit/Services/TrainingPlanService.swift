import Foundation

extension JwqywxApplication {
    /// 获取并缓存培养方案（含磁盘缓存）
    public func getTrainingPlan(forceRefresh: Bool = false) async throws -> TrainingPlan {
        if !forceRefresh, let cached = trainingPlanCache { return cached }
        guard let authId = authorizationId else { throw CCZUError.notLoggedIn }
        guard let stuNum = studentNumber else { throw CCZUError.notLoggedIn }

        // 先尝试读取磁盘缓存
        if !forceRefresh, let disk = try? loadTrainingPlanFromDisk(studentNumber: stuNum) {
            trainingPlanCache = disk
            return disk
        }

        // 真实端点 - 清理参数空格，并复用学生基本信息填充必需字段
        let url = CCZUConstants.Jwqywx.trainingPlanURL
        let cleanStudentNumber = stuNum.trimmingCharacters(in: .whitespacesAndNewlines)
        var requestData: [String: String] = [
            // 先尝试用授权ID作为 xh（部分实现以内部ID查询更稳定）
            "xh": authId,
            "yhid": authId
        ]

        let basic = try await getStudentBasicInfo()
        guard let info = basic.message.first else { throw CCZUError.missingData("学生基本信息") }
        requestData["nj"] = String(info.grade)
        requestData["xz"] = String(info.studyLength)
        if !info.majorCode.isEmpty { requestData["zydm"] = info.majorCode }
        var (data, _) = try await postAuthenticatedJSON(url: url, json: requestData)
        lastTrainingPlanRawResponse = String(data: data, encoding: .utf8)

        var plan: TrainingPlan
        do {
            plan = try TrainingPlanParser.parse(from: data, basicInfo: info)
        } catch {
            // 若失败或返回空数组，回退用学号作为 xh 再试一次
            requestData["xh"] = cleanStudentNumber
            let retry = try await postAuthenticatedJSON(url: url, json: requestData)
            data = retry.0
            if let responseString = String(data: data, encoding: .utf8) {
                lastTrainingPlanRawResponse = responseString
            }
            plan = try TrainingPlanParser.parse(from: data, basicInfo: info)
        }
        trainingPlanCache = plan
        try? saveTrainingPlanToDisk(plan, studentNumber: stuNum)
        return plan
    }

    /// 预取培养方案（触发网络并落盘）
    @discardableResult
    public func prefetchTrainingPlan() async throws -> TrainingPlan {
        guard let _ = authorizationId, let _ = studentNumber else { throw CCZUError.notLoggedIn }
        return try await getTrainingPlan()
    }

    /// 清除培养方案缓存
    public func clearTrainingPlanCache() {
        trainingPlanCache = nil
    }

    // MARK: - 磁盘缓存帮助
    private func cacheURL(studentNumber: String) throws -> URL {
        let fm = FileManager.default
        let dir = try fm.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent(CCZUConstants.Jwqywx.cacheDirectoryName, isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("\(CCZUConstants.Jwqywx.trainingPlanCachePrefix)\(studentNumber)\(CCZUConstants.Jwqywx.trainingPlanCacheExtension)")
    }

    private func saveTrainingPlanToDisk(_ plan: TrainingPlan, studentNumber: String) throws {
        let url = try cacheURL(studentNumber: studentNumber)
        let data = try JSONEncoder().encode(plan)
        try data.write(to: url, options: .atomic)
    }

    private func loadTrainingPlanFromDisk(studentNumber: String) throws -> TrainingPlan? {
        let url = try cacheURL(studentNumber: studentNumber)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(TrainingPlan.self, from: data)
    }

    /// 删除磁盘缓存
    public func deleteTrainingPlanDiskCache() {
        guard let stuNum = studentNumber, let url = try? cacheURL(studentNumber: stuNum) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
