//
//  WeekSelectionView.swift
//  CCZUHelper
//
//  课程详情页的「生效周次」编辑器
//

import SwiftUI

/// 生效周次选择页：上方快捷操作（全选 / 单周 / 双周），下方 1...maxWeek 的周次网格。
struct WeekSelectionView: View {
    @Binding var selection: [Int]

    /// 与调课弹窗的周次范围保持一致。
    var maxWeek: Int = RescheduleSupport.maxWeek

    private enum QuickAction: Hashable {
        case all
        case odd
        case even
    }

    @State private var quickAction: QuickAction?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    private var selectedWeeks: Set<Int> {
        Set(selection)
    }

    var body: some View {
        Form {
            Section {
                Picker("", selection: $quickAction) {
                    Text(NSLocalizedString("schedule_component.weeks_quick_all", comment: ""))
                        .tag(QuickAction.all as QuickAction?)
                    Text(NSLocalizedString("schedule_component.weeks_quick_odd", comment: ""))
                        .tag(QuickAction.odd as QuickAction?)
                    Text(NSLocalizedString("schedule_component.weeks_quick_even", comment: ""))
                        .tag(QuickAction.even as QuickAction?)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: .infinity)
            } header: {
                Text(NSLocalizedString("schedule_component.weeks_quick_actions", comment: ""))
            }
            .onChange(of: quickAction) { _, newValue in
                applyQuickAction(newValue)
            }

            Section {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(1...maxWeek, id: \.self) { week in
                        weekCell(week)
                    }
                }
                .padding(.vertical, 4)
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            } header: {
                Text(NSLocalizedString("schedule_component.weeks_detail_selection", comment: ""))
            } footer: {
                Text(summary)
            }
        }
        .navigationTitle(NSLocalizedString("schedule_component.weeks_effective_title", comment: ""))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            // 进入时同步快捷操作的选中态，避免高亮与实际周次不一致。
            quickAction = matchingQuickAction(for: selection)
        }
        .onChange(of: selection) { _, _ in
            quickAction = matchingQuickAction(for: selection)
        }
    }

    private func weekCell(_ week: Int) -> some View {
        let isSelected = selectedWeeks.contains(week)

        return Button {
            toggle(week)
        } label: {
            Text("\(week)")
                .font(.callout)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? .white : Color.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(format: NSLocalizedString("schedule_component.week_format", comment: ""), week))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var summary: String {
        selection.isEmpty
            ? NSLocalizedString("schedule_component.weeks_not_set", comment: "")
            : formatWeeks(selection)
    }

    private func toggle(_ week: Int) {
        if let index = selection.firstIndex(of: week) {
            selection.remove(at: index)
        } else {
            selection.append(week)
            selection.sort()
        }
    }

    private func applyQuickAction(_ action: QuickAction?) {
        switch action {
        case .all:
            selection = Array(1...maxWeek)
        case .odd:
            selection = stride(from: 1, through: maxWeek, by: 2).map { $0 }
        case .even:
            selection = stride(from: 2, through: maxWeek, by: 2).map { $0 }
        case nil:
            break
        }
    }

    /// 当前周次与某个快捷操作的集合完全一致时才回填高亮，否则留空。
    private func matchingQuickAction(for weeks: [Int]) -> QuickAction? {
        let current = Set(weeks)
        guard !current.isEmpty else { return nil }
        if current == Set(1...maxWeek) { return .all }
        if current == Set(stride(from: 1, through: maxWeek, by: 2)) { return .odd }
        if current == Set(stride(from: 2, through: maxWeek, by: 2)) { return .even }
        return nil
    }

    private func formatWeeks(_ weeks: [Int]) -> String {
        let sorted = weeks.sorted()
        guard let first = sorted.first else {
            return NSLocalizedString("schedule_component.weeks_not_set", comment: "")
        }

        var result = ""
        var rangeStart = first
        var rangeEnd = first

        for week in sorted.dropFirst() {
            if week == rangeEnd + 1 {
                rangeEnd = week
            } else {
                result += (result.isEmpty ? "" : ", ") + formatRange(rangeStart, rangeEnd)
                rangeStart = week
                rangeEnd = week
            }
        }

        return result + (result.isEmpty ? "" : ", ") + formatRange(rangeStart, rangeEnd)
    }

    private func formatRange(_ start: Int, _ end: Int) -> String {
        if start == end {
            return String(format: NSLocalizedString("schedule_component.week_format", comment: ""), start)
        }
        return String(format: NSLocalizedString("schedule_component.week_range_format", comment: ""), start, end)
    }
}

#Preview {
    NavigationStack {
        WeekSelectionView(selection: .constant([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]))
    }
}
