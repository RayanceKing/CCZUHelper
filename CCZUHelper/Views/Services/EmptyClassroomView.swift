//
//  EmptyClassroomView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/1.
//

import SwiftUI

/// 空闲教室查询视图
struct EmptyClassroomView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedBuilding = "全部"
    @State private var selectedTime = "第1-2节"
    @State private var selectedWeekday = 1
    @State private var classrooms: [ClassroomItem] = []
    @State private var isLoading = false
    
    private let buildings = ["全部", "教学楼A", "教学楼B", "教学楼C", "实验楼D"]
    private let timeSlots = ["第1-2节", "第3-4节", "第5-6节", "第7-8节", "第9-10节"]
    private let weekdays = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 查询条件
                Form {
                    Section("查询条件") {
                        Picker("教学楼", selection: $selectedBuilding) {
                            ForEach(buildings, id: \.self) { building in
                                Text(building).tag(building)
                            }
                        }
                        
                        Picker("星期", selection: $selectedWeekday) {
                            ForEach(Array(weekdays.enumerated()), id: \.offset) { index, day in
                                Text(day).tag(index + 1)
                            }
                        }
                        
                        Picker("时间", selection: $selectedTime) {
                            ForEach(timeSlots, id: \.self) { slot in
                                Text(slot).tag(slot)
                            }
                        }
                        
                        Button(action: searchClassrooms) {
                            HStack {
                                Spacer()
                                if isLoading {
                                    ProgressView()
                                } else {
                                    Text("查询")
                                }
                                Spacer()
                            }
                        }
                    }
                }
                .frame(height: 280)
                
                // 查询结果
                if classrooms.isEmpty && !isLoading {
                    ContentUnavailableView {
                        Label("请选择查询条件", systemImage: "magnifyingglass")
                    } description: {
                        Text("选择教学楼、时间后点击查询按钮")
                    }
                } else {
                    List {
                        Section("空闲教室 (\(classrooms.count)间)") {
                            ForEach(classrooms) { classroom in
                                ClassroomRow(classroom: classroom)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("空闲教室")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
    
    private func searchClassrooms() {
        isLoading = true
        
        Task {
            do {
                // TODO: 使用CCZUKit获取真实空闲教室数据
                try await Task.sleep(nanoseconds: 1_000_000_000)
                
                await MainActor.run {
                    // 模拟数据
                    classrooms = [
                        ClassroomItem(name: "A101", capacity: 60, building: "教学楼A", floor: 1),
                        ClassroomItem(name: "A203", capacity: 80, building: "教学楼A", floor: 2),
                        ClassroomItem(name: "A305", capacity: 100, building: "教学楼A", floor: 3),
                        ClassroomItem(name: "B102", capacity: 50, building: "教学楼B", floor: 1),
                        ClassroomItem(name: "B204", capacity: 70, building: "教学楼B", floor: 2),
                    ]
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

/// 教室项模型
struct ClassroomItem: Identifiable {
    let id = UUID()
    let name: String
    let capacity: Int
    let building: String
    let floor: Int
}

/// 教室行视图
struct ClassroomRow: View {
    let classroom: ClassroomItem
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(classroom.building) \(classroom.name)")
                    .font(.headline)
                
                HStack {
                    Label("\(classroom.floor)楼", systemImage: "building.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Label("\(classroom.capacity)人", systemImage: "person.3")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    EmptyClassroomView()
}
