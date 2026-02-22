//
//  CompetitionDetailView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2026/2/19.
//
import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

struct CompetitionDetailView: View {
    @Environment(\.openURL) private var openURL

    let item: CompetitionListItem

    @State private var detail: CompetitionDetailDTO?
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var htmlContentHeight: CGFloat = 200
    @State private var isSummarizing = false
    @State private var summaryText: String? = nil
    @State private var showSummarySheet = false
    @State private var summarizeError: String? = nil
    @State private var canSummarizeOnDevice = false
    @State private var isCheckingSummaryAvailability = false

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
                    ProgressView("common.loading".localized)
                } else if let errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if let content = detail?.content, !content.isEmpty {
                    CompetitionHTMLWebView(html: content, height: $htmlContentHeight)
                        .frame(height: max(160, htmlContentHeight))
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
        .toolbar {
            #if os(iOS)
            if #available(iOS 26.0, *) {
                if canSummarizeOnDevice {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: { Task { await summarizeCompetition() } }) {
                            if isSummarizing {
                                ProgressView()
                            } else {
                                Image(systemName: "text.line.3.summary")
                            }
                        }
                        .disabled(isSummarizing)
                        .accessibilityLabel(Text("competition.summary.button".localized))
                    }
                }
            }
            #endif
        }
        .task {
            await loadDetail()
            updateSummarizationAvailability()
        }
        .sheet(isPresented: $showSummarySheet) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if let text = summaryText {
                            Text(text)
                                .font(.body)
                                .foregroundStyle(.primary)
                        } else if let err = summarizeError {
                            Text("competition.summary.failed".localized(with: err))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("competition.summary.no_content".localized)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                }
                .navigationTitle("competition.summary.sheet_title".localized)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common.close".localized) { showSummarySheet = false }
                    }
                }
            }
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

    private func updateSummarizationAvailability() {
        if let cached = OnDeviceSummaryAvailabilityCache.cachedAvailability() {
            self.canSummarizeOnDevice = cached
            if !OnDeviceSummaryAvailabilityCache.shouldRefresh() { return }
        }
        if isCheckingSummaryAvailability { return }
        isCheckingSummaryAvailability = true

        Task { @MainActor in
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                let instructions = "competition.summary.instructions".localized
                let session = LanguageModelSession(instructions: instructions)

                // Use a lightweight probe to avoid reflection on FoundationModels internals.
                do {
                    _ = try await session.respond(to: "ping")
                    canSummarizeOnDevice = true
                    OnDeviceSummaryAvailabilityCache.save(true)
                } catch {
                    canSummarizeOnDevice = false
                    OnDeviceSummaryAvailabilityCache.save(false)
                }
            } else {
                canSummarizeOnDevice = false
                OnDeviceSummaryAvailabilityCache.save(false)
            }
            #else
            canSummarizeOnDevice = false
            OnDeviceSummaryAvailabilityCache.save(false)
            #endif
            isCheckingSummaryAvailability = false
        }
    }

    @MainActor
    private func summarizeCompetition() async {
        guard !isSummarizing else { return }
        isSummarizing = true
        summarizeError = nil
        summaryText = nil

        let content = detail?.content ?? ""
        let prompt = "competition.summary.prompt".localized(with: item.title, content)

        if #available(iOS 26.0, *) {
            #if canImport(FoundationModels)
            do {
                let generator = try await TextGenerator.makeDefault()
                let request = TextGenerationRequest(prompt: prompt, maxTokens: 220)
                let response = try await generator.generate(request)
                summaryText = response.text
            } catch {
                summarizeError = error.localizedDescription
            }
            #else
            summaryText = "competition.summary.fallback_prefix".localized + String(prompt.prefix(140))
            #endif
            showSummarySheet = true
        } else {
            summarizeError = "competition.summary.unsupported_system".localized
            showSummarySheet = true
        }
        isSummarizing = false
    }
}
