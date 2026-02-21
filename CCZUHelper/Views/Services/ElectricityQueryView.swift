//
//  ElectricityQueryView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/08.
//

import SwiftUI
import CCZUKit
import Charts

/// 电费查询视图
struct ElectricityQueryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @State private var manager = ElectricityManager.shared
    @State private var showAddSheet = false
    
    var body: some View {
        NavigationStack {
            Group {
                if manager.configs.isEmpty {
                    emptyView
                } else {
                    configListView
                }
            }
            .navigationTitle("electricity.title".localized)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("close".localized) { dismiss() }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddElectricityConfigView()
                    .environment(settings)
            }
            .task {
                await refreshAllConfigs()
            }
        }
    }
    
    // MARK: - 空视图
    
    private var emptyView: some View {
        ContentUnavailableView {
            Label("electricity.empty".localized, systemImage: "bolt.slash")
        } description: {
            Text("electricity.empty_desc".localized)
        } actions: {
            Button("electricity.add_config".localized) {
                showAddSheet = true
            }
        }
    }
    
    // MARK: - 配置列表
    
    private var configListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(manager.configs) { config in
                    ElectricityCard(config: config)
                        .environment(settings)
                }
            }
            .padding()
        }
    }
    
    // MARK: - 刷新所有配置
    
    private func refreshAllConfigs() async {
        guard !manager.configs.isEmpty else { return }
        
        for config in manager.configs {
            await queryElectricity(for: config)
        }
    }
    
    private func queryElectricity(for config: ElectricityConfig) async {
        guard let username = settings.username,
              let password = KeychainHelper.read(service: KeychainServices.localKeychain, account: username) else {
            return
        }
        
        do {
            let area = ElectricityArea(area: config.areaName, areaname: config.areaName, aid: config.areaId)
            let building = Building(building: config.buildingName, buildingid: config.buildingId)
            
            let client = DefaultHTTPClient(username: username, password: password)
            let app = JwqywxApplication(client: client)
            let response = try await app.queryElectricity(area: area, building: building, roomId: config.roomId)
            
            // 解析电量
            if let balance = ElectricityMessageParser.parseBalance(from: response.errmsg) {
                manager.addRecord(for: config.id, balance: balance)
            }
        } catch {
            print("查询电费失败: \(error)")
        }
    }
}

/// 电费卡片
struct ElectricityCard: View {
    let config: ElectricityConfig
    @Environment(AppSettings.self) private var settings
    @State private var manager = ElectricityManager.shared
    @State private var isRefreshing = false
    @State private var showDeleteAlert = false
    
    private var records: [ElectricityRecord] {
        manager.getRecords(for: config.id)
    }
    
    private var latestBalance: Double {
        manager.getLatestBalance(for: config.id) ?? 0
    }
    
    private var balanceColor: Color {
        if latestBalance < 15 {
            return .red
        } else if latestBalance < 30 {
            return .orange
        } else {
            return .green
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ElectricityCardHeader(
                config: config,
                balanceColor: balanceColor,
                isRefreshing: isRefreshing,
                onRefresh: {
                    Task { await refreshElectricity() }
                },
                onDelete: {
                    showDeleteAlert = true
                }
            )

            ElectricityBalanceSection(
                latestBalance: latestBalance,
                balanceColor: balanceColor,
                records: records
            )

            if let lastRecord = records.last {
                ElectricityLastUpdateRow(formattedDate: formatDate(lastRecord.timestamp))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .alert("electricity.delete_confirm".localized, isPresented: $showDeleteAlert) {
            Button("common.cancel".localized, role: .cancel) {}
            Button("common.delete".localized, role: .destructive) {
                manager.removeConfig(config)
            }
        } message: {
            Text("electricity.delete_message".localized(with: config.displayName))
        }
    }
    
    // 刷新电量
    private func refreshElectricity() async {
        guard let username = settings.username,
              let password = KeychainHelper.read(service: KeychainServices.localKeychain, account: username) else {
            return
        }
        
        isRefreshing = true
        defer { isRefreshing = false }
        
        do {
            let area = ElectricityArea(area: config.areaName, areaname: config.areaName, aid: config.areaId)
            let building = Building(building: config.buildingName, buildingid: config.buildingId)
            
            let client = DefaultHTTPClient(username: username, password: password)
            let app = JwqywxApplication(client: client)
            let response = try await app.queryElectricity(area: area, building: building, roomId: config.roomId)
            
            if let balance = ElectricityMessageParser.parseBalance(from: response.errmsg) {
                manager.addRecord(for: config.id, balance: balance)
            }
        } catch {
            print("刷新电费失败: \(error)")
        }
    }
    
    // 电量趋势图
    private func formatDate(_ date: Date) -> String {
        AppDateFormatting.monthDayHourMinuteString(from: date)
    }
}

private struct ElectricityCardHeader: View {
    let config: ElectricityConfig
    let balanceColor: Color
    let isRefreshing: Bool
    let onRefresh: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(balanceColor)
                    Text(config.displayName)
                        .font(.headline)
                }

                Text("\(config.areaName) - \(config.buildingName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 12) {
                Button(action: onRefresh) {
                    Image(systemName: "arrow.trianglehead.2.clockwise")
                        .foregroundStyle(.blue)
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                        .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                }
                .disabled(isRefreshing)

                Menu {
                    Button(role: .destructive, action: onDelete) {
                        Label("common.delete".localized, systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct ElectricityBalanceSection: View {
    let latestBalance: Double
    let balanceColor: Color
    let records: [ElectricityRecord]

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "%.0f", latestBalance))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(balanceColor)

                Text("kWh")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if records.count >= 2 {
                ElectricityTrendChart(records: records)
                    .frame(width: 120, height: 60)
            }
        }
    }
}

private struct ElectricityTrendChart: View {
    let records: [ElectricityRecord]

    var body: some View {
        Chart {
            ForEach(Array(records.enumerated()), id: \.offset) { _, record in
                LineMark(
                    x: .value("Time", record.timestamp),
                    y: .value("Balance", record.balance)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(.green)
                .lineStyle(StrokeStyle(lineWidth: 2))

                AreaMark(
                    x: .value("Time", record.timestamp),
                    y: .value("Balance", record.balance)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.green.opacity(0.2))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }
}

private struct ElectricityLastUpdateRow: View {
    let formattedDate: String

    var body: some View {
        HStack {
            Image(systemName: "clock")
                .font(.caption2)
            Text("electricity.last_update".localized(with: formattedDate))
                .font(.caption2)
        }
        .foregroundStyle(.secondary)
    }
}

/// 添加电费配置视图
struct AddElectricityConfigView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @State private var manager = ElectricityManager.shared
    
    @State private var selectedAreaIndex: Int?
    @State private var selectedBuildingIndex: Int?
    @State private var roomId: String = ""
    @State private var displayName: String = ""
    
    @State private var areas: [ElectricityArea] = []
    @State private var buildings: [Building] = []
    
    @State private var isLoadingAreas = false
    @State private var isLoadingBuildings = false
    @State private var errorMessage: String?
    
    private var selectedArea: ElectricityArea? {
        guard let index = selectedAreaIndex, areas.indices.contains(index) else { return nil }
        return areas[index]
    }
    
    private var selectedBuilding: Building? {
        guard let index = selectedBuildingIndex, buildings.indices.contains(index) else { return nil }
        return buildings[index]
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("electricity.select_area".localized) {
                    if isLoadingAreas {
                        ProgressView()
                    } else {
                        Picker("electricity.area".localized, selection: $selectedAreaIndex) {
                            Text("electricity.please_select".localized).tag(nil as Int?)
                            ForEach(areas.indices, id: \.self) { index in
                                Text(areas[index].areaname).tag(index as Int?)
                            }
                        }
                        .onChange(of: selectedAreaIndex) { _, newValue in
                            if newValue != nil {
                                selectedBuildingIndex = nil
                                buildings = []
                                Task {
                                    await loadBuildings()
                                }
                            }
                        }
                    }
                }
                
                if selectedAreaIndex != nil {
                    Section("electricity.select_building".localized) {
                        if isLoadingBuildings {
                            ProgressView()
                        } else {
                            Picker("electricity.building".localized, selection: $selectedBuildingIndex) {
                                Text("electricity.please_select".localized).tag(nil as Int?)
                                ForEach(buildings.indices, id: \.self) { index in
                                    Text(buildings[index].building).tag(index as Int?)
                                }
                            }
                        }
                    }
                }
                
                if selectedBuilding != nil {
                    Section("electricity.room_info".localized) {
                        TextField("electricity.room_id".localized, text: $roomId)
                            .keyboardType(.default)
                        
                        TextField("electricity.display_name".localized, text: $displayName)
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("electricity.add_config".localized)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("add".localized) {
                        addConfig()
                    }
                    .disabled(!canAdd)
                }
            }
            .task {
                await loadAreas()
            }
        }
    }
    
    private var canAdd: Bool {
        selectedArea != nil && selectedBuilding != nil && !roomId.isEmpty && !displayName.isEmpty
    }
    
    private func loadAreas() async {
        isLoadingAreas = true
        defer { isLoadingAreas = false }
        
        guard let username = settings.username,
              let password = KeychainHelper.read(service: KeychainServices.localKeychain, account: username) else {
            errorMessage = "electricity.error_not_logged_in".localized
            return
        }
        
        do {
            let client = DefaultHTTPClient(username: username, password: password)
            let app = JwqywxApplication(client: client)
            areas = try await app.getElectricityAreas()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func loadBuildings() async {
        guard let area = selectedArea else { return }
        
        isLoadingBuildings = true
        defer { isLoadingBuildings = false }
        
        guard let username = settings.username,
              let password = KeychainHelper.read(service: KeychainServices.localKeychain, account: username) else {
            errorMessage = "electricity.error_not_logged_in".localized
            return
        }
        
        do {
            let client = DefaultHTTPClient(username: username, password: password)
            let app = JwqywxApplication(client: client)
            buildings = try await app.getBuildings(area: area)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func addConfig() {
        guard let area = selectedArea, let building = selectedBuilding else { return }
        
        let config = ElectricityConfig(
            areaId: area.aid,
            areaName: area.areaname,
            buildingId: building.buildingid,
            buildingName: building.building,
            roomId: roomId,
            displayName: displayName
        )
        
        manager.addConfig(config)
        
        // 添加后立即查询电量，避免显示为0
        Task {
            await queryElectricityForNewConfig(config)
        }
        
        dismiss()
    }
    
    // 为新添加的配置查询电量
    private func queryElectricityForNewConfig(_ config: ElectricityConfig) async {
        guard let username = settings.username,
              let password = KeychainHelper.read(service: KeychainServices.localKeychain, account: username) else {
            return
        }
        
        do {
            let area = ElectricityArea(area: config.areaName, areaname: config.areaName, aid: config.areaId)
            let building = Building(building: config.buildingName, buildingid: config.buildingId)
            
            let client = DefaultHTTPClient(username: username, password: password)
            let app = JwqywxApplication(client: client)
            let response = try await app.queryElectricity(area: area, building: building, roomId: config.roomId)
            
            if let balance = ElectricityMessageParser.parseBalance(from: response.errmsg) {
                manager.addRecord(for: config.id, balance: balance)
            }
        } catch {
            print("查询新配置电费失败: \(error)")
        }
    }
}

#Preview {
    ElectricityQueryView()
        .environment(AppSettings())
}
