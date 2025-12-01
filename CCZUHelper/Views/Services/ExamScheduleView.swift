//
//  ExamScheduleView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/1.
//

import SwiftUI

/// 考试安排视图
struct ExamScheduleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    
    @State private var exams: [ExamItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    ProgressView("加载中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    ContentUnavailableView {
                        Label("加载失败", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("重试") {
                            loadExams()
                        }
                    }
                } else if exams.isEmpty {
                    ContentUnavailableView {
                        Label("暂无考试安排", systemImage: "calendar.badge.clock")
                    } description: {
                        Text("当前学期还没有考试安排")
                    }
                } else {
                    List {
                        ForEach(exams) { exam in
                            ExamRow(exam: exam)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("考试安排")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear {
                if exams.isEmpty {
                    loadExams()
                }
            }
        }
    }
    
    private func loadExams() {
        guard settings.isLoggedIn else {
            errorMessage = "请先登录"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // TODO: 使用CCZUKit获取真实考试安排
                try await Task.sleep(nanoseconds: 1_000_000_000)
                
                await MainActor.run {
                    exams = [
                        ExamItem(courseName: "高等数学A(1)", date: "2025年1月10日", time: "09:00-11:00", location: "教学楼A101", seatNumber: "15"),
                        ExamItem(courseName: "大学英语(1)", date: "2025年1月12日", time: "14:00-16:00", location: "外语楼B203", seatNumber: "28"),
                        ExamItem(courseName: "程序设计基础", date: "2025年1月15日", time: "09:00-11:00", location: "计算机楼C301", seatNumber: "42"),
                        ExamItem(courseName: "线性代数", date: "2025年1月17日", time: "14:00-16:00", location: "教学楼A205", seatNumber: "33"),
                    ]
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

/// 考试项模型
struct ExamItem: Identifiable {
    let id = UUID()
    let courseName: String
    let date: String
    let time: String
    let location: String
    let seatNumber: String
}

/// 考试行视图
struct ExamRow: View {
    let exam: ExamItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(exam.courseName)
                .font(.headline)
            
            HStack {
                Label(exam.date, systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Label(exam.time, systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                Label(exam.location, systemImage: "mappin.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("座位号: \(exam.seatNumber)")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    ExamScheduleView()
        .environment(AppSettings())
}
