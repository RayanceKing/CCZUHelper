import Foundation
import Observation

@Observable
@MainActor
final class ICloudSettingsSyncManager {
    static let shared = ICloudSettingsSyncManager()

    enum ScheduleStorageMode {
        case checking, cloudConfigured, localOnly, temporary
    }
    var scheduleStorageMode: ScheduleStorageMode = .checking

    private let store: NSUbiquitousKeyValueStore
    private let defaults: UserDefaults
    private let baselineKey = "icloud.settings.lastObserved.v2"
    private let electricityKey = "electricity_configs"
    private let media: ICloudMediaSync
    private var merge: ICloudSettingsMerge
    private var cloudObserver: NSObjectProtocol?
    private var defaultsObserver: NSObjectProtocol?
    private weak var settingsRef: AppSettings?

    private init() {
        store = .default
        defaults = .standard
        media = ICloudMediaSync(store: .default)
        merge = ICloudSettingsMerge(baseline: UserDefaults.standard.dictionary(forKey: "icloud.settings.lastObserved.v2") ?? [:])
    }

    func bootstrap(settings: AppSettings) {
        settingsRef = settings
        guard settings.hasPurchase, settings.enableICloudDataSync else {
            stopObserving()
            return
        }
        // Register before synchronize: initial cloud data may arrive asynchronously.
        startObserving()
        _ = store.synchronize()
        let local = payload(from: settings)
        let remote = store.dictionaryRepresentation
        // Upgrade existing installations using only explicitly persisted values.
        // A fresh device must never publish the default values from AppSettings().
        let seeds = local.filter { key, _ in
            merge.baseline[key] == nil && remote[key] == nil && defaults.object(forKey: key) != nil
        }
        pullFromCloud(into: settings)
        for (key, value) in seeds { store.set(value, forKey: key) }
        media.start(settings: settings)
    }

    func handleToggleChange(enabled: Bool, settings: AppSettings) {
        if enabled, settings.hasPurchase {
            bootstrap(settings: settings)
        } else {
            if enabled, !settings.hasPurchase { settings.enableICloudDataSync = false }
            stopObserving()
        }
    }

    private func payload(from settings: AppSettings) -> [String: Any] {
        var payload = settings.makeICloudSyncPayload()
        if let configs = ElectricityManager.shared.makeICloudSyncData() { payload[electricityKey] = configs }
        return payload
    }

    func pushToCloud(from settings: AppSettings) {
        guard settings.hasPurchase, settings.enableICloudDataSync else { return }
        let local = payload(from: settings)
        let changes = merge.localChanges(in: local)
        merge.record(local)
        persistBaseline()
        for (key, value) in changes where !ICloudSettingsMerge.equal(store.object(forKey: key), value) {
            store.set(value, forKey: key)
        }
        media.sync()
        // KVS schedules transmission itself. Do not force synchronize for every slider tick.
    }

    func pullFromCloud(into settings: AppSettings) {
        guard settings.hasPurchase, settings.enableICloudDataSync else { return }
        let result = merge.reconcile(local: payload(from: settings), remote: store.dictionaryRepresentation)
        settings.applyICloudSyncPayload(result.apply)
        if let data = result.apply[electricityKey] as? Data { ElectricityManager.shared.applyICloudSyncData(data) }
        merge.record(payload(from: settings))
        persistBaseline()
        for (key, value) in result.upload { store.set(value, forKey: key) }
        media.sync()
    }

    private func persistBaseline() {
        if !NSDictionary(dictionary: merge.baseline).isEqual(to: defaults.dictionary(forKey: baselineKey) ?? [:]) {
            defaults.set(merge.baseline, forKey: baselineKey)
        }
    }

    private func startObserving() {
        if cloudObserver == nil {
            cloudObserver = NotificationCenter.default.addObserver(
                forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: store, queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, let settings = self.settingsRef else { return }
                    self.pullFromCloud(into: settings)
                }
            }
        }
        if defaultsObserver == nil {
            defaultsObserver = NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification, object: defaults, queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, let settings = self.settingsRef else { return }
                    self.pushToCloud(from: settings)
                }
            }
        }
    }

    private func stopObserving() {
        for observer in [cloudObserver, defaultsObserver].compactMap({ $0 }) {
            NotificationCenter.default.removeObserver(observer)
        }
        cloudObserver = nil
        defaultsObserver = nil
        media.stop()
    }
}
