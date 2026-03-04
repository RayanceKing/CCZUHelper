//
//  ReportUserView.swift
//  CCZUHelper
//
//  Created by Codex on 2026/3/1.
//

import SwiftUI

struct ReportUserView: View {
    @Environment(\.dismiss) private var dismiss

    let userId: String
    let username: String

    @StateObject private var teahouseService = TeahouseService()

    @State private var selectedReason = ""
    @State private var details = ""
    @State private var shouldBlockUser = false
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""

    private let reasons = [
        "report_user.reason.harassment".localized,
        "report_user.reason.spam".localized,
        "report.reason.misinformation".localized,
        "report.reason.pornography".localized,
        "report.reason.hate_speech".localized,
        "report.reason.other".localized
    ]

    private var isValid: Bool {
        !selectedReason.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("report_user.title".localized)
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("@\(username)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("report_user.subtitle".localized)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.clear)

                Section("report_user.reason.label".localized) {
                    ForEach(reasons, id: \.self) { reason in
                        Button {
                            selectedReason = reason
                        } label: {
                            HStack {
                                Text(reason)
                                Spacer()
                                if selectedReason == reason {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }

                Section("report_user.details.label".localized) {
                    TextField("report_user.details.placeholder".localized, text: $details, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Toggle("report_user.block_user".localized, isOn: $shouldBlockUser)
                }

                Section {
                    Button(action: submit) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(.circular)
                            } else {
                                Text("report.submit".localized)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .disabled(!isValid || isSubmitting)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .buttonBorderShape(.capsule)
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("report_user.title".localized)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if #available(iOS 26.0, macOS 26.0, visionOS 2, *) {
                        Button(role: .cancel) {
                            dismiss()
                        }
                        .disabled(isSubmitting)
                    } else {
                        Button("common.cancel".localized) {
                            dismiss()
                        }
                        .disabled(isSubmitting)
                    }
                }
            }
            .alert("report_user.error.submit_failed".localized, isPresented: $showError) {
                Button("common.confirm".localized, role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func submit() {
        guard isValid else { return }

        Task {
            isSubmitting = true
            defer { isSubmitting = false }

            do {
                try await teahouseService.reportUser(
                    reportedId: userId,
                    reason: selectedReason,
                    details: details
                )

                if shouldBlockUser {
                    try await teahouseService.blockUser(blockedId: userId)
                }

                dismiss()
            } catch AppError.notAuthenticated {
                errorMessage = "report_user.error.not_logged_in".localized
                showError = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

