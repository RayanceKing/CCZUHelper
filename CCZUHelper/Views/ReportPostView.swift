//
//  ReportPostView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/24.
//

import SwiftUI
import Supabase

/// 举报数据结构
struct ReportData: Encodable {
    let post_id: String
    let reporter_id: String
    let reason: String
    let created_at: String
}

/// 举报帖子视图
struct ReportPostView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    let postId: String
    let postTitle: String
    
    @State private var reason = ""
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    private let reasons = [
        "report.reason.ad".localized,
        "report.reason.pornography".localized,
        "report.reason.violence".localized,
        "report.reason.hate_speech".localized,
        "report.reason.misinformation".localized,
        "report.reason.copyright".localized,
        "report.reason.other".localized
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("report.title".localized)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("\"\(postTitle)\"")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        
                        Text("report.subtitle".localized)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)
                
                Section("report.reason.label".localized) {
                    ForEach(reasons, id: \.self) { reasonOption in
                        Button(action: {
                            reason = reasonOption
                        }) {
                            HStack {
                                Text(reasonOption)
                                Spacer()
                                if reason == reasonOption {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
                
                if reason == "report.reason.other".localized {
                    Section("report.reason.details".localized) {
                        TextField("report.reason.details.placeholder".localized, text: $reason, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }
                
                Section {
                    Button(action: submitReport) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            } else {
                                Text("report.submit".localized)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(reason.isEmpty || isSubmitting)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.large)
                    .buttonBorderShape(.automatic)
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("report.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }
            }
            .alert("report.error.title".localized, isPresented: $showError) {
                Button("ok".localized, role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func submitReport() {
        guard let userId = authViewModel.session?.user.id.uuidString else {
            errorMessage = "report.error.not_logged_in".localized
            showError = true
            return
        }
        
        guard !reason.isEmpty else {
            errorMessage = "report.error.select_reason".localized
            showError = true
            return
        }
        
        Task {
            isSubmitting = true
            defer { isSubmitting = false }
            
            do {
                let supabase = supabase
                
                // 插入举报记录
                let reportData = ReportData(
                    post_id: postId,
                    reporter_id: userId,
                    reason: reason,
                    created_at: Date().ISO8601Format()
                )
                
                let response = try await supabase
                    .from("reports")
                    .insert(reportData)
                    .execute()
                
                if response.status == 201 {
                    dismiss()
                } else {
                    errorMessage = "report.error.submit_failed".localized
                    showError = true
                }
            } catch {
                let message = String(format: "report.error.message".localized, error.localizedDescription)
                errorMessage = message
                showError = true
            }
        }
    }
}