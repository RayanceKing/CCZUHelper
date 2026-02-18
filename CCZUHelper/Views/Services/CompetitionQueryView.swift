//
//  CompetitionQueryView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2026/2/18.
//

import SwiftUI

struct CompetitionQueryView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var competitions: [CompetitionListItem] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var loadError: String?
    @State private var searchText = ""

    @State private var selectedCollege = ""
    @State private var selectedCategory = ""
    @State private var selectedLevel = ""

    @State private var colleges: [String] = []
    @State private var categories: [String] = []
    @State private var levels: [String] = []

    @State private var currentPage = 0
    @State private var hasMore = true

    @State private var didUseAllDataFallback = false

    private let pageSize = 30

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                content
            }
            .navigationTitle("services.competition_query".localized)
            .searchable(text: $searchText, prompt: "competition.search.placeholder".localized)
            .onChange(of: searchText) { _, newValue in
                if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Task { await reloadCompetitionsOnly() }
                }
            }
            .onSubmit(of: .search) {
                Task { await reloadCompetitionsOnly() }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.close".localized) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await reloadAll() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
            .task {
                await reloadAll()
            }
            .navigationDestination(for: CompetitionListItem.self) { item in
                CompetitionDetailView(item: item)
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterMenu(
                    title: "competition.filter.college".localized,
                    selection: $selectedCollege,
                    values: colleges
                )
                filterMenu(
                    title: "competition.filter.category".localized,
                    selection: $selectedCategory,
                    values: categories
                )
                filterMenu(
                    title: "competition.filter.level".localized,
                    selection: $selectedLevel,
                    values: levels
                )
                Button("competition.filter.reset".localized) {
                    selectedCollege = ""
                    selectedCategory = ""
                    selectedLevel = ""
                    Task { await reloadCompetitionsOnly() }
                }
                .font(.footnote)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private var content: some View {
        Group {
            if isLoading && competitions.isEmpty {
                ProgressView("loading".localized)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let loadError, competitions.isEmpty {
                ContentUnavailableView {
                    Label("competition.loading_failed".localized, systemImage: "exclamationmark.triangle")
                } description: {
                    Text(loadError)
                } actions: {
                    Button("common.retry".localized) {
                        Task { await reloadAll() }
                    }
                }
            } else if competitions.isEmpty {
                ContentUnavailableView {
                    Label("competition.empty".localized, systemImage: "trophy")
                } description: {
                    Text("competition.empty_hint".localized)
                }
            } else {
                List {
                    ForEach(competitions) { item in
                        NavigationLink(value: item) {
                            CompetitionRow(item: item)
                                .onAppear {
                                    Task {
                                        await loadMoreIfNeeded(currentID: item.id)
                                    }
                                }
                        }
                    }

                    if isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable {
                    await reloadCompetitionsOnly()
                }
            }
        }
    }

    private func filterMenu(title: String, selection: Binding<String>, values: [String]) -> some View {
        Menu {
            Button("common.all".localized) {
                selection.wrappedValue = ""
                Task { await reloadCompetitionsOnly() }
            }

            ForEach(values, id: \.self) { value in
                Button(value) {
                    selection.wrappedValue = value
                    Task { await reloadCompetitionsOnly() }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(selection.wrappedValue.isEmpty ? title : selection.wrappedValue)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .font(.footnote)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
            .clipShape(Capsule())
        }
    }

    private func reloadAll() async {
        await loadFilterOptions()
        await reloadCompetitionsOnly()
    }

    private func reloadCompetitionsOnly() async {
        currentPage = 0
        hasMore = true
        didUseAllDataFallback = false
        await loadPage(reset: true)
    }

    private func loadMoreIfNeeded(currentID: Int) async {
        guard hasMore, !isLoading, !isLoadingMore else { return }
        guard competitions.last?.id == currentID else { return }
        await loadPage(reset: false)
    }

    private func loadFilterOptions() async {
        do {
            async let collegeValues = fetchOptionValues(url: CompetitionAPI.collegesURL)
            async let categoryValues = fetchOptionValues(url: CompetitionAPI.categoriesURL)
            async let levelValues = fetchOptionValues(url: CompetitionAPI.levelsURL)

            let (newColleges, newCategories, newLevels) = try await (collegeValues, categoryValues, levelValues)
            colleges = newColleges
            categories = newCategories
            levels = newLevels
        } catch {
            // 筛选项获取失败不阻断主流程
        }
    }

    private func loadPage(reset: Bool) async {
        if reset {
            isLoading = true
        } else {
            isLoadingMore = true
        }
        defer {
            isLoading = false
            isLoadingMore = false
        }

        do {
            let pageToLoad = reset ? 0 : currentPage
            let keyword = normalizedKeyword(searchText)
            let response = try await fetchCompetitionsPage(
                page: pageToLoad,
                size: pageSize,
                keyword: keyword,
                college: emptyToNil(selectedCollege),
                category: emptyToNil(selectedCategory),
                level: emptyToNil(selectedLevel)
            )

            let items = response.map(\.asListItem)
            if reset {
                competitions = items
            } else {
                competitions.append(contentsOf: items.filter { incoming in
                    !competitions.contains(where: { $0.id == incoming.id })
                })
            }

            if items.isEmpty && pageToLoad == 0 && !didUseAllDataFallback {
                didUseAllDataFallback = true
                let allItems = try await fetchAllCompetitionsFallback()
                competitions = applyLocalFilter(allItems)
                hasMore = false
                currentPage = 0
            } else {
                hasMore = items.count >= pageSize
                currentPage = pageToLoad + 1
            }

            loadError = nil
        } catch {
            if reset && !didUseAllDataFallback {
                didUseAllDataFallback = true
                do {
                    let allItems = try await fetchAllCompetitionsFallback()
                    competitions = applyLocalFilter(allItems)
                    hasMore = false
                    currentPage = 0
                    loadError = nil
                    return
                } catch {
                    // 忽略并走下面统一错误
                }
            }
            loadError = error.localizedDescription
        }
    }

    private func fetchCompetitionsPage(
        page: Int,
        size: Int,
        keyword: String?,
        college: String?,
        category: String?,
        level: String?
    ) async throws -> [CompetitionListDTO] {
        guard let url = CompetitionAPI.competitionsURL(
            keyword: keyword,
            college: college,
            category: category,
            level: level,
            startDate: nil,
            endDate: nil,
            page: page,
            size: size
        ) else {
            throw URLError(.badURL)
        }
        let data = try await requestData(url: url)
        return try JSONDecoder().decode([CompetitionListDTO].self, from: data)
    }

    private func fetchAllCompetitionsFallback() async throws -> [CompetitionListItem] {
        guard let url = CompetitionAPI.allCompetitionsURL else {
            throw URLError(.badURL)
        }
        let data = try await requestData(url: url)
        let dtos = try JSONDecoder().decode([CompetitionListDTO].self, from: data)
        return dtos.map(\.asListItem)
    }

    private func fetchOptionValues(url: URL?) async throws -> [String] {
        guard let url else { throw URLError(.badURL) }
        let data = try await requestData(url: url)
        let values = try JSONDecoder().decode([CompetitionOptionDTO].self, from: data)
            .map(\.value)
            .filter { !$0.isEmpty }
        return Array(Set(values)).sorted()
    }

    private func requestData(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("CCZUHelper/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private func applyLocalFilter(_ source: [CompetitionListItem]) -> [CompetitionListItem] {
        source.filter { item in
            let keywordOk: Bool = {
                guard let keyword = normalizedKeyword(searchText) else { return true }
                return item.title.localizedCaseInsensitiveContains(keyword) ||
                    item.college.localizedCaseInsensitiveContains(keyword) ||
                    item.category.localizedCaseInsensitiveContains(keyword) ||
                    (item.level ?? "").localizedCaseInsensitiveContains(keyword) ||
                    (item.organizer ?? "").localizedCaseInsensitiveContains(keyword)
            }()

            let collegeOk = selectedCollege.isEmpty || item.college == selectedCollege
            let categoryOk = selectedCategory.isEmpty || item.category == selectedCategory
            let levelOk = selectedLevel.isEmpty || item.level == selectedLevel

            return keywordOk && collegeOk && categoryOk && levelOk
        }
        .sorted { $0.publishDate > $1.publishDate }
    }

    private func normalizedKeyword(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func emptyToNil(_ value: String) -> String? {
        value.isEmpty ? nil : value
    }
}

private struct CompetitionRow: View {
    let item: CompetitionListItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)

            HStack(spacing: 8) {
                CompetitionTag(text: item.college, color: .blue)
                CompetitionTag(text: item.category, color: .orange)
                if let level = item.level, !level.isEmpty {
                    CompetitionTag(text: level, color: .purple)
                }
            }

            HStack(spacing: 12) {
                Label(item.publishDate, systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let deadline = item.deadline, !deadline.isEmpty {
                    Label(deadline, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct CompetitionDetailView: View {
    @Environment(\.openURL) private var openURL

    let item: CompetitionListItem

    @State private var detail: CompetitionDetailDTO?
    @State private var isLoading = false
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(item.title)
                    .font(.title3)
                    .fontWeight(.semibold)

                HStack(spacing: 8) {
                    CompetitionTag(text: item.college, color: .blue)
                    CompetitionTag(text: item.category, color: .orange)
                    if let level = item.level, !level.isEmpty {
                        CompetitionTag(text: level, color: .purple)
                    }
                }

                Group {
                    Text("competition.publish_date".localized + ": " + item.publishDate)
                    if let deadline = item.deadline, !deadline.isEmpty {
                        Text("competition.deadline".localized + ": " + deadline)
                    }
                    if let organizer = item.organizer, !organizer.isEmpty {
                        Text("competition.organizer".localized + ": " + organizer)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Divider()

                if isLoading {
                    ProgressView("loading".localized)
                } else if let errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if let content = detail?.content, !content.isEmpty {
                    Text(content)
                        .font(.body)
                        .foregroundStyle(.primary)
                } else {
                    Text("competition.detail.no_content".localized)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Button {
                    if let url = URL(string: item.url) {
                        openURL(url)
                    }
                } label: {
                    Label("competition.open_original".localized, systemImage: "safari")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }
            .padding(16)
        }
        .background(Color(.systemBackground))
        .navigationTitle("competition.detail.title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDetail()
        }
    }

    private func loadDetail() async {
        guard detail == nil else { return }
        guard let url = CompetitionAPI.competitionDetailURL(id: item.id) else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 20
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }

            detail = try JSONDecoder().decode(CompetitionDetailDTO.self, from: data)
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }
}

private struct CompetitionTag: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

private struct CompetitionListItem: Identifiable, Hashable {
    let id: Int
    let title: String
    let url: String
    let publishDate: String
    let college: String
    let category: String
    let level: String?
    let deadline: String?
    let organizer: String?
}

private struct CompetitionListDTO: Decodable {
    let id: Int?
    let title: String?
    let url: String?
    let publishDate: String?
    let college: String?
    let category: String?
    let level: String?
    let deadline: String?
    let organizer: String?

    var asListItem: CompetitionListItem {
        let fallbackSeed = (url ?? "") + (title ?? "") + (publishDate ?? "")
        let fallbackID = abs(fallbackSeed.hashValue)

        return CompetitionListItem(
            id: id ?? fallbackID,
            title: title ?? "-",
            url: url ?? "",
            publishDate: publishDate ?? "-",
            college: college ?? "-",
            category: category ?? "-",
            level: level,
            deadline: deadline,
            organizer: organizer
        )
    }
}

private struct CompetitionDetailDTO: Decodable {
    let id: Int?
    let title: String?
    let url: String?
    let content: String?
    let publishDate: String?
    let crawlTime: String?
    let college: String?
    let category: String?
    let level: String?
    let deadline: String?
    let organizer: String?
}

private struct CompetitionOptionDTO: Decodable {
    let value: String

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(), let text = try? single.decode(String.self) {
            value = text
            return
        }

        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        for key in ["name", "value", "label", "title"] {
            guard let codingKey = DynamicCodingKey(stringValue: key) else { continue }
            if let decoded = try container.decodeIfPresent(String.self, forKey: codingKey) {
                value = decoded
                return
            }
        }

        value = ""
    }
}

private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

#Preview {
    CompetitionQueryView()
}
