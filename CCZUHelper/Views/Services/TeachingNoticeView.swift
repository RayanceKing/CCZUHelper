//
//  TeachingNoticeView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/6.
//

import SwiftUI

/// 教务通知视图
struct TeachingNoticeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    
    @State private var notices: [NoticeItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedNotice: NoticeItem?
    @State private var showNoticeDetail = false
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("loading".localized)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    ContentUnavailableView {
                        Label("notice.loading_failed".localized, systemImage: "exclamationmark.triangle.fill")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("retry".localized) {
                            Task {
                                await loadNotices()
                            }
                        }
                    }
                } else if notices.isEmpty {
                    ContentUnavailableView {
                        Label("notice.no_notices".localized, systemImage: "bell.slash")
                    } description: {
                        Text("notice.no_notices_desc".localized)
                    }
                } else {
                    List {
                        ForEach(notices) { notice in
                            Button(action: {
                                selectedNotice = notice
                                showNoticeDetail = true
                            }) {
                                NoticeRow(notice: notice)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("notice.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("close".localized) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await loadNotices()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
            .sheet(isPresented: $showNoticeDetail) {
                if let notice = selectedNotice {
                    NoticeDetailView(notice: notice)
                }
            }
        }
        .onAppear {
            if notices.isEmpty {
                Task {
                    await loadNotices()
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadNotices() async {
        isLoading = true
        errorMessage = nil
        
        // 模拟加载延迟
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            // TODO: 实际从API加载通知
            // 临时使用示例数据
            self.notices = [
                NoticeItem(
                    id: "1",
                    title: "关于2024-2025学年第一学期期末考试安排的通知",
                    content: "各学院、各位同学：\n\n根据学校教学工作安排，现将2024-2025学年第一学期期末考试相关事宜通知如下...",
                    publishDate: Date().addingTimeInterval(-86400 * 2),
                    isImportant: true
                ),
                NoticeItem(
                    id: "2",
                    title: "关于开展2024-2025学年第二学期选课工作的通知",
                    content: "各学院、各位同学：\n\n为做好2024-2025学年第二学期选课工作，现将有关事项通知如下...",
                    publishDate: Date().addingTimeInterval(-86400 * 5),
                    isImportant: true
                ),
                NoticeItem(
                    id: "3",
                    title: "关于2024年大学生创新创业训练计划项目申报的通知",
                    content: "各学院：\n\n为进一步深化创新创业教育改革，培养学生创新精神和实践能力...",
                    publishDate: Date().addingTimeInterval(-86400 * 7),
                    isImportant: false
                ),
                NoticeItem(
                    id: "4",
                    title: "关于做好2024届毕业生学历学位审核工作的通知",
                    content: "各学院：\n\n为做好2024届毕业生学历学位审核工作，确保毕业生顺利毕业...",
                    publishDate: Date().addingTimeInterval(-86400 * 10),
                    isImportant: false
                ),
            ]
            self.isLoading = false
        }
    }
}

/// 通知项目模型
struct NoticeItem: Identifiable, Codable {
    let id: String
    let title: String
    let content: String
    let publishDate: Date
    var isImportant: Bool
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: publishDate)
    }
}

/// 通知行视图
struct NoticeRow: View {
    let notice: NoticeItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(notice.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                
                if notice.isImportant {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            
            HStack {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(notice.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// 通知详情视图
struct NoticeDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let notice: NoticeItem
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 标题
                    HStack {
                        Text(notice.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if notice.isImportant {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                    
                    // 发布日期
                    HStack {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(notice.formattedDate)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                    
                    // 内容
                    Text(notice.content)
                        .font(.body)
                        .foregroundStyle(.primary)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("close".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    TeachingNoticeView()
        .environment(AppSettings())
}
