//
//  CompetitionDetailView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2026/2/19.
//
import SwiftUI

struct CompetitionDetailView: View {
    @Environment(\.openURL) private var openURL

    let item: CompetitionListItem

    @State private var detail: CompetitionDetailDTO?
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var htmlContentHeight: CGFloat = 200

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
