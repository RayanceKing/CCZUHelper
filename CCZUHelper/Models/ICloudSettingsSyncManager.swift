//
//  ICloudSettingsSyncManager.swift
//  CCZUHelper
//

import Foundation

final class ICloudSettingsSyncManager {
    static let shared = ICloudSettingsSyncManager()

    private let store = NSUbiquitousKeyValueStore.default
    private var cloudObserver: NSObjectProtocol?
    private var defaultsObserver: NSObjectProtocol?
    private weak var settingsRef: AppSettings?
    private var isApplyingRemote = false

    private init() {}

    func bootstrap(settings: AppSettings) {
        settingsRef = settings
        guard settings.enableICloudDataSync else {
            stopObserving()
            return
        }

        _ = store.synchronize()
        pullFromCloud(into: settings)
        pushToCloud(from: settings)
        startObserving(settings: settings)
    }

    func handleToggleChange(enabled: Bool, settings: AppSettings) {
        if enabled {
            bootstrap(settings: settings)
        } else {
            stopObserving()
        }
    }

    func pushToCloud(from settings: AppSettings) {
        guard settings.enableICloudDataSync else { return }
        let payload = settings.makeICloudSyncPayload()
        for (key, value) in payload {
            store.set(value, forKey: key)
        }
        _ = store.synchronize()
    }

    func pullFromCloud(into settings: AppSettings) {
        guard settings.enableICloudDataSync else { return }
        isApplyingRemote = true
        settings.applyICloudSyncPayload(store.dictionaryRepresentation)
        isApplyingRemote = false
    }

    private func startObserving(settings: AppSettings) {
        if cloudObserver == nil {
            cloudObserver = NotificationCenter.default.addObserver(
                forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: store,
                queue: .main
            ) { [weak self] _ in
                guard let self, let currentSettings = self.settingsRef else { return }
                self.pullFromCloud(into: currentSettings)
            }
        }

        if defaultsObserver == nil {
            defaultsObserver = NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification,
                object: UserDefaults.standard,
                queue: .main
            ) { [weak self] _ in
                guard let self,
                      let currentSettings = self.settingsRef,
                      currentSettings.enableICloudDataSync,
                      !self.isApplyingRemote else { return }
                self.pushToCloud(from: currentSettings)
            }
        }
    }

    private func stopObserving() {
        if let cloudObserver {
            NotificationCenter.default.removeObserver(cloudObserver)
            self.cloudObserver = nil
        }
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
            self.defaultsObserver = nil
        }
    }
}
