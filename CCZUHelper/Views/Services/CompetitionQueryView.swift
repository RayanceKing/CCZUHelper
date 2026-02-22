//
//  CompetitionQueryView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2026/2/18.
//

import SwiftUI

struct CompetitionQueryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.serviceEmbeddedNavigation) private var serviceEmbeddedNavigation

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
    
    private var chipBackgroundColor: Color {
        #if os(macOS)
        return Color(nsColor: .controlBackgroundColor)
        #else
        return Color(.secondarySystemBackground)
        #endif
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                content
            }
            .navigationTitle("services.competition_query".localized)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
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
                #if os(macOS)
                if !serviceEmbeddedNavigation {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common.close".localized) {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await reloadAll() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
                #else
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
                #endif
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
                .background(chipBackgroundColor)
                .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private var content: some View {
        Group {
            if isLoading && competitions.isEmpty {
                ProgressView("common.loading".localized)
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
                #if os(macOS)
                .listStyle(.inset)
                #else
                .listStyle(.insetGrouped)
                #endif
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
            .background(chipBackgroundColor)
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

#Preview {
    CompetitionQueryView()
}
