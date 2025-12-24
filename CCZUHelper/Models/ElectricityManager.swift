//
//  ElectricityManager.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/08.
//

import Foundation
import SwiftUI
import UserNotifications
import CCZUKit

/// 电费查询配置
struct ElectricityConfig: Codable, Identifiable {
    let id: UUID
    let areaId: String
    let areaName: String
    let buildingId: String
    let buildingName: String
    let roomId: String
    let displayName: String
    
    init(id: UUID = UUID(), areaId: String, areaName: String, buildingId: String, buildingName: String, roomId: String, displayName: String) {
        self.id = id
        self.areaId = areaId
        self.areaName = areaName
        self.buildingId = buildingId
        self.buildingName = buildingName
        self.roomId = roomId
        self.displayName = displayName
    }
}

/// 电费历史记录
struct ElectricityRecord: Codable {
    let timestamp: Date
    let balance: Double
    
    init(timestamp: Date = Date(), balance: Double) {
        self.timestamp = timestamp
        self.balance = balance
    }
}

/// 电费管理器
@Observable
class ElectricityManager {
    static let shared = ElectricityManager()
    
    // 存储键
    private enum Keys {
        static let configs = "electricity_configs"
        static let records = "electricity_records_"
        static let lastNotificationDate = "electricity_last_notification_"
    }
    
    // 配置列表
    var configs: [ElectricityConfig] = []
    
    // 每个配置的历史记录
    private var recordsCache: [UUID: [ElectricityRecord]] = [:]
    
    // 定时任务
    private var scheduledUpdateTask: Task<Void, Never>?
    
    private init() {
        loadConfigs()
    }
    
    // MARK: - 配置管理
    
    func addConfig(_ config: ElectricityConfig) {
        configs.append(config)
        saveConfigs()
    }
    
    func removeConfig(_ config: ElectricityConfig) {
        configs.removeAll { $0.id == config.id }
        // 同时删除相关历史记录
        UserDefaults.standard.removeObject(forKey: Keys.records + config.id.uuidString)
        recordsCache.removeValue(forKey: config.id)
        saveConfigs()
    }
    
    func updateConfig(_ config: ElectricityConfig) {
        if let index = configs.firstIndex(where: { $0.id == config.id }) {
            configs[index] = config
            saveConfigs()
        }
    }
    
    private func loadConfigs() {
        if let data = UserDefaults.standard.data(forKey: Keys.configs),
           let decoded = try? JSONDecoder().decode([ElectricityConfig].self, from: data) {
            configs = decoded
        }
    }
    
    private func saveConfigs() {
        if let encoded = try? JSONEncoder().encode(configs) {
            UserDefaults.standard.set(encoded, forKey: Keys.configs)
        }
    }
    
    // MARK: - 定时更新
    
    /// 设置电费定时更新任务（每天中午12点）
    func setupScheduledUpdate(with settings: AppSettings) {
        // 取消现有的定时任务
        scheduledUpdateTask?.cancel()
        
        scheduledUpdateTask = Task {
            while !Task.isCancelled {
                let now = Date()
                let calendar = Calendar.current
                
                // 计算下一个中午12点的时间
                var nextUpdate = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now
                
                // 如果当前时间已经过了今天的12点，则设置为明天的12点
                if nextUpdate <= now {
                    nextUpdate = calendar.date(byAdding: .day, value: 1, to: nextUpdate) ?? now
                }
                
                let waitInterval = nextUpdate.timeIntervalSince(now)
                
                do {
                    // 等待直到下一个更新时间
                    try await Task.sleep(nanoseconds: UInt64(waitInterval * 1_000_000_000))
                    
                    // 执行定时更新
                    if !Task.isCancelled {
                        await queryAllElectricity(with: settings)
                    }
                } catch {
                    // 任务被取消或其他错误
                    break
                }
            }
        }
    }
    
    /// 查询所有配置的电费
    @MainActor
    func queryAllElectricity(with settings: AppSettings) async {
        guard !configs.isEmpty else { return }
        guard let username = settings.username,
              let password = KeychainHelper.read(service: KeychainServices.localKeychain, account: username) else {
            return
        }
        
        do {
            let client = DefaultHTTPClient(username: username, password: password)
            let app = JwqywxApplication(client: client)
            
            for config in configs {
                let area = ElectricityArea(area: config.areaName, areaname: config.areaName, aid: config.areaId)
                let building = Building(building: config.buildingName, buildingid: config.buildingId)
                
                let response = try await app.queryElectricity(area: area, building: building, roomId: config.roomId)
                
                if let balance = parseBalance(from: response.errmsg) {
                    addRecord(for: config.id, balance: balance)
                }
            }
        } catch {
            print("定时查询电费失败: \(error)")
        }
    }
    
    private func parseBalance(from message: String) -> Double? {
        let pattern = "[0-9]+\\.?[0-9]*"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: message, options: [], range: NSRange(message.startIndex..., in: message)),
           let range = Range(match.range, in: message) {
            return Double(message[range])
        }
        return nil
    }
    
    // MARK: - 历史记录管理
    
    func addRecord(for configId: UUID, balance: Double) {
        var records = getRecords(for: configId)
        
        // 添加新记录
        let record = ElectricityRecord(balance: balance)
        records.append(record)
        
        // 只保留最近30天的记录
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        records = records.filter { $0.timestamp >= thirtyDaysAgo }
        
        // 保存
        recordsCache[configId] = records
        saveRecords(for: configId, records: records)
        
        // 检查是否需要发送通知
        checkAndNotify(configId: configId, balance: balance)
    }
    
    func getRecords(for configId: UUID) -> [ElectricityRecord] {
        // 先从缓存读取
        if let cached = recordsCache[configId] {
            return cached
        }
        
        // 从UserDefaults加载
        let key = Keys.records + configId.uuidString
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([ElectricityRecord].self, from: data) {
            recordsCache[configId] = decoded
            return decoded
        }
        
        return []
    }
    
    private func saveRecords(for configId: UUID, records: [ElectricityRecord]) {
        let key = Keys.records + configId.uuidString
        if let encoded = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
    
    func getLatestBalance(for configId: UUID) -> Double? {
        return getRecords(for: configId).last?.balance
    }
    
    // MARK: - 通知管理
    
    private func checkAndNotify(configId: UUID, balance: Double) {
        guard let config = configs.first(where: { $0.id == configId }) else { return }
        
        let lastNotifyKey = Keys.lastNotificationDate + configId.uuidString
        let lastNotifyDate = UserDefaults.standard.object(forKey: lastNotifyKey) as? Date
        
        // 每天最多通知一次
        if let last = lastNotifyDate, Calendar.current.isDateInToday(last) {
            return
        }
        
        // 判断电量等级并发送通知
        if balance < 15 {
            sendNotification(title: "⚠️ 电费余额不足", message: "\(config.displayName) 余额仅剩 \(String(format: "%.2f", balance)) 度，请尽快充值！")
            UserDefaults.standard.set(Date(), forKey: lastNotifyKey)
        } else if balance < 30 {
            sendNotification(title: "💡 电费余额预警", message: "\(config.displayName) 余额剩余 \(String(format: "%.2f", balance)) 度，建议充值。")
            UserDefaults.standard.set(Date(), forKey: lastNotifyKey)
        }
    }
    
    private func sendNotification(title: String, message: String) {
        Task {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = message
            content.sound = .default
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(
                identifier: "electricity_low_balance_\(UUID().uuidString)",
                content: content,
                trigger: trigger
            )
            
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                print("Failed to schedule electricity notification: \(error)")
            }
        }
    }
}
