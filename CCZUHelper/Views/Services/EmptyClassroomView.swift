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
    
    private let buildings = ["classroom.building.all".localized, "classroom.building.a".localized, "classroom.building.b".localized, "classroom.building.c".localized, "classroom.building.d".localized]
    private let timeSlots = ["classroom.time_slot.1_2".localized, "classroom.time_slot.3_4".localized, "classroom.time_slot.5_6".localized, "classroom.time_slot.7_8".localized, "classroom.time_slot.9_10".localized]
    private let weekdays = ["classroom.weekday.monday".localized, "classroom.weekday.tuesday".localized, "classroom.weekday.wednesday".localized, "classroom.weekday.thursday".localized, "classroom.weekday.friday".localized, "classroom.weekday.saturday".localized, "classroom.weekday.sunday".localized]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 查询条件
                Form {
                    Section("classroom.search_conditions".localized) {
                        Picker("classroom.building".localized, selection: $selectedBuilding) {
                            ForEach(buildings, id: \.self) { building in
                                Text(building).tag(building)
                            }
                        }
                        
                        Picker("classroom.weekday".localized, selection: $selectedWeekday) {
                            ForEach(Array(weekdays.enumerated()), id: \.offset) { index, day in
                                Text(day).tag(index + 1)
                            }
                        }
                        
                        Picker("classroom.time".localized, selection: $selectedTime) {
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
                                    Text("classroom.query".localized)
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
                        Label("classroom.select_conditions".localized, systemImage: "magnifyingglass")
                    } description: {
                        Text("classroom.select_hint".localized)
                    }
                } else {
                    List {
                        Section("classroom.empty_rooms.format".localized(with: classrooms.count)) {
                            ForEach(classrooms) { classroom in
                                ClassroomRow(classroom: classroom)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("classroom.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("close".localized) { dismiss() }
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
                    Label("classroom.floor.format".localized(with: classroom.floor), systemImage: "building.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Label("classroom.capacity.format".localized(with: classroom.capacity), systemImage: "person.3")
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
