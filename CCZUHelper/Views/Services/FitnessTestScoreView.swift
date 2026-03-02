//
//  FitnessTestScoreView.swift
//  CCZUHelper
//
//  Created by Codex on 2026/3/2.
//

import SwiftUI

struct FitnessTestScoreView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.serviceEmbeddedNavigation) private var serviceEmbeddedNavigation
    @Environment(AppSettings.self) private var settings

    @AppStorage("fitness.uid") private var uid: String = "14341581"
    @AppStorage("fitness.schoolID") private var schoolID: String = "195"
    @AppStorage("fitness.studentNum") private var studentNum: String = ""
    @AppStorage("fitness.h5Token") private var h5Token: String = ""
    @AppStorage("fitness.phpSessionID") private var phpSessionID: String = ""
    @AppStorage("fitness.mobileDeviceID") private var mobileDeviceID: String = "D12E8D8D-94D8-4ACB-ABCE-DFD8DD9411FC"
    @AppStorage("fitness.nonce") private var nonce: String = "109546"

    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var responseInfo: String?
    @State private var scoreData: FitnessScoreData?

    private var selectableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((max(currentYear - 8, 2018)...currentYear).reversed())
    }

    var body: some View {
        NavigationStack {
            List {
                requestConfigSection
                resultSection
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.inset)
            #endif
            .navigationTitle("体育成绩")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                if !serviceEmbeddedNavigation {
                    ToolbarItem(placement: .cancellationAction) {
                        if #available(iOS 26.0, macOS 26.0, visionOS 2, *) {
                            Button(role: .cancel) { dismiss() }
                        } else {
                            Button("common.close".localized) { dismiss() }
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await queryScore() }
                    } label: {
                        if isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "magnifyingglass")
                        }
                    }
                    .disabled(isLoading)
                }
            }
            .onAppear {
                if studentNum.isEmpty, let username = settings.username {
                    studentNum = username
                }
            }
        }
    }

    private var requestConfigSection: some View {
        Section("查询配置") {
            Picker("学年", selection: $selectedYear) {
                ForEach(selectableYears, id: \.self) { year in
                    Text("\(year)").tag(year)
                }
            }
            TextField("学号/卡号", text: $studentNum)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("UID", text: $uid)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("school_id", text: $schoolID)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("h5_token", text: $h5Token)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("PHPSESSID(可选)", text: $phpSessionID)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("mobileDeviceId", text: $mobileDeviceID)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("nonce", text: $nonce)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button {
                Task { await queryScore() }
            } label: {
                HStack {
                    Spacer()
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("开始查询")
                    }
                    Spacer()
                }
            }
            .disabled(isLoading || studentNum.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let responseInfo {
                Text(responseInfo)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        Section("成绩结果") {
            if let scoreData {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(scoreData.studentName) (\(scoreData.studentNum))")
                        .font(.headline)
                    Text("\(scoreData.studentYear)  总分 \(scoreData.totalScore)  等级 \(scoreData.totalGrade)")
                        .font(.subheadline)
                    Text("状态: \(scoreData.reportStatus)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                ForEach(scoreData.metrics) { metric in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(metric.title)
                                .font(.subheadline)
                            Text(metric.value)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(metric.grade)
                            .font(.footnote)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(metric.badgeColor.opacity(0.15))
                            .foregroundStyle(metric.badgeColor)
                            .clipShape(Capsule())
                    }
                }
            } else if isLoading {
                HStack {
                    Spacer()
                    ProgressView("common.loading".localized)
                    Spacer()
                }
            } else {
                Text("暂无数据")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func queryScore() async {
        let trimmedStudentNum = studentNum.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUID = uid.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSchoolID = schoolID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToken = h5Token.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedStudentNum.isEmpty else {
            await MainActor.run { errorMessage = "请先填写学号/卡号" }
            return
        }
        guard !trimmedUID.isEmpty, !trimmedSchoolID.isEmpty, !trimmedToken.isEmpty else {
            await MainActor.run { errorMessage = "UID / school_id / h5_token 不能为空" }
            return
        }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
            responseInfo = nil
        }

        do {
            let result = try await withTimeout(seconds: 20.0) {
                try await fetchFitnessScore(
                    year: selectedYear,
                    uid: trimmedUID,
                    schoolID: trimmedSchoolID,
                    studentNum: trimmedStudentNum,
                    h5Token: trimmedToken
                )
            }

            await MainActor.run {
                responseInfo = result.info
                scoreData = result.data
                if result.data == nil {
                    errorMessage = nil
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "查询失败: \(error.localizedDescription)"
            }
        }
    }

    private func fetchFitnessScore(
        year: Int,
        uid: String,
        schoolID: String,
        studentNum: String,
        h5Token: String
    ) async throws -> FitnessScoreResult {
        guard let url = URL(string: "https://api2.lptiyu.com/bdlp_h5_fitness_test/public/index.php/index/Report/getStudentScore") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")

        var cookieParts = ["COOKIE_QUERY_YEAR=\(year)", "login_type=1"]
        let phpsessid = phpSessionID.trimmingCharacters(in: .whitespacesAndNewlines)
        if !phpsessid.isEmpty {
            cookieParts.append("PHPSESSID=\(phpsessid)")
        }
        request.setValue(cookieParts.joined(separator: "; "), forHTTPHeaderField: "Cookie")

        let timestamp = String(Int(Date().timeIntervalSince1970))
        let bodyParams: [(String, String)] = [
            ("version", "4.2.0"),
            ("moblileOsVersion", "iOS26.4"),
            ("sign", ""),
            ("mobileModel", "iPhone15,4"),
            ("uid", uid),
            ("school_id", schoolID),
            ("timestamp", timestamp),
            ("ostype", "2"),
            ("card_id", studentNum),
            ("mobileDeviceId", mobileDeviceID),
            ("nonce", nonce),
            ("login_type", "1"),
            ("student_num", studentNum),
            ("user_type", "2"),
            ("year_num", "\(year)"),
            ("h5_token", h5Token)
        ]

        var components = URLComponents()
        components.queryItems = bodyParams.map { URLQueryItem(name: $0.0, value: $0.1) }
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }

        let info = jsonObject["info"] as? String ?? "未知响应"
        let parsedData: FitnessScoreData?
        if let rawData = jsonObject["data"] as? [String: Any], !rawData.isEmpty {
            parsedData = FitnessScoreData(dictionary: rawData)
        } else {
            parsedData = nil
        }

        return FitnessScoreResult(info: info, data: parsedData)
    }
}

private struct FitnessScoreResult {
    let info: String
    let data: FitnessScoreData?
}

private struct FitnessScoreData {
    let studentName: String
    let studentNum: String
    let studentYear: String
    let totalScore: String
    let totalGrade: String
    let reportStatus: String
    let metrics: [FitnessMetric]

    init(dictionary: [String: Any]) {
        func stringValue(_ key: String, fallback: String = "-") -> String {
            if let value = dictionary[key] {
                if let string = value as? String { return string }
                if let number = value as? NSNumber { return number.stringValue }
                return "\(value)"
            }
            return fallback
        }

        self.studentName = stringValue("student_name")
        self.studentNum = stringValue("student_num")
        self.studentYear = stringValue("studentYear")
        self.totalScore = stringValue("total_score")
        self.totalGrade = stringValue("total_grade")
        self.reportStatus = stringValue("report_status")
        self.metrics = [
            FitnessMetric(
                title: "BMI",
                value: stringValue("bmi_score_new", fallback: stringValue("bmi_score")),
                grade: stringValue("bmi_grade"),
                className: stringValue("bmi_class")
            ),
            FitnessMetric(
                title: "肺活量",
                value: stringValue("vc_score"),
                grade: stringValue("vc_grade"),
                className: stringValue("vc_class")
            ),
            FitnessMetric(
                title: "立定跳远",
                value: stringValue("jump_score"),
                grade: stringValue("jump_grade"),
                className: stringValue("jump_class")
            ),
            FitnessMetric(
                title: "坐位体前屈",
                value: stringValue("sit_and_reach_score"),
                grade: stringValue("sit_and_reach_grade"),
                className: stringValue("sit_and_reach_class")
            ),
            FitnessMetric(
                title: "引体/仰卧",
                value: stringValue("pull_and_sit_score"),
                grade: stringValue("pull_and_sit_grade"),
                className: stringValue("pull_and_sit_class")
            ),
            FitnessMetric(
                title: "50 米",
                value: stringValue("50m_score"),
                grade: stringValue("50m_grade"),
                className: stringValue("50m_class")
            ),
            FitnessMetric(
                title: "耐力跑",
                value: stringValue("run_score"),
                grade: stringValue("run_grade"),
                className: stringValue("run_class")
            )
        ]
    }
}

private struct FitnessMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let grade: String
    let className: String

    var badgeColor: Color {
        switch className.lowercased() {
        case "red":
            return .red
        case "yellow":
            return .orange
        case "green":
            return .green
        default:
            return .secondary
        }
    }
}

#Preview {
    FitnessTestScoreView()
        .environment(AppSettings())
}
