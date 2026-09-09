import Foundation
import CryptoKit

@MainActor
final class ICloudMediaSync {
    private let store: NSUbiquitousKeyValueStore
    private let defaults: UserDefaults
    private var task: Task<Void, Never>?
    private var query: NSMetadataQuery?
    private var observers: [NSObjectProtocol] = []
    private weak var settings: AppSettings?
    private var generation = 0
    private var needsSync = false

    init(store: NSUbiquitousKeyValueStore, defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults
    }

    func start(settings: AppSettings) {
        self.settings = settings
        if query == nil {
            let query = NSMetadataQuery()
            query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
            query.predicate = NSPredicate(format: "%K BEGINSWITH %@ OR %K BEGINSWITH %@",
                NSMetadataItemFSNameKey, "background-", NSMetadataItemFSNameKey, "avatar-")
            for name in [Notification.Name.NSMetadataQueryDidFinishGathering, Notification.Name.NSMetadataQueryDidUpdate] {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: query, queue: .main) { [weak self] _ in
                    Task { @MainActor in self?.sync() }
                })
            }
            self.query = query
            query.start()
        }
        sync()
    }

    func stop() {
        generation += 1
        needsSync = false
        task?.cancel()
        task = nil
        query?.stop()
        query = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
    }

    func sync() {
        guard let settings, settings.hasPurchase, settings.enableICloudDataSync else { return }
        guard task == nil else { needsSync = true; return }
        needsSync = false
        let currentGeneration = generation
        task = Task { [weak self] in
            guard let self else { return }
            let directory = await Task.detached(priority: .utility) {
                FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.com.stuwang.edupal")?
                    .appendingPathComponent("Documents/SettingsMedia", isDirectory: true)
            }.value
            if let directory, !Task.isCancelled {
                await self.sync(kind: "background", key: "media.background", directory: directory, settings: settings)
                if let username = settings.username, !username.isEmpty, !Task.isCancelled {
                    let account = SHA256.hash(data: Data(username.utf8)).map { String(format: "%02x", $0) }.joined()
                    await self.sync(kind: "avatar", key: "media.avatar.\(account)", directory: directory, settings: settings)
                }
            }
            if self.generation == currentGeneration {
                self.task = nil
                if self.needsSync { self.sync() }
            }
        }
    }

    private func sync(kind: String, key: String, directory: URL, settings: AppSettings) async {
        func path() -> String? { kind == "background" ? settings.backgroundImagePath : settings.userAvatarPath }
        func setPath(_ value: String?) {
            if kind == "background" { settings.backgroundImagePath = value }
            else { settings.userAvatarPath = value }
        }
        let originalPath = path()
        let originalUsername = settings.username
        let pathKey = "local.\(key).path"
        let referenceKey = "local.\(key).reference"
        let initializedKey = "local.\(key).initialized"
        if !defaults.bool(forKey: initializedKey) {
            defaults.set(originalPath, forKey: pathKey)
            defaults.set(true, forKey: initializedKey)
        }
        let previousPath = defaults.string(forKey: pathKey)
        let previousReference = defaults.string(forKey: referenceKey)
        let remote = store.string(forKey: key)
        let locallyChanged = originalPath != previousPath
        do {
            if locallyChanged || (remote == nil && originalPath != nil) {
                let reference: String
                if let originalPath {
                    reference = try await Task.detached(priority: .utility) {
                        try ICloudMediaFiles.publish(path: originalPath, kind: kind, directory: directory)
                    }.value
                } else {
                    reference = "" // Tombstone: another device must also clear the image.
                }
                guard !Task.isCancelled, settings.hasPurchase, settings.enableICloudDataSync,
                      path() == originalPath, settings.username == originalUsername else { return }
                store.set(reference, forKey: key)
                defaults.set(originalPath, forKey: pathKey)
                defaults.set(reference, forKey: referenceKey)
            } else if let remote, remote != previousReference || (!remote.isEmpty && !FileManager.default.fileExists(atPath: originalPath ?? "")) {
                let restoredPath: String?
                if remote.isEmpty { restoredPath = nil }
                else {
                    let localDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent("SyncedMedia", isDirectory: true)
                    restoredPath = try await Task.detached(priority: .utility) {
                        try ICloudMediaFiles.restore(reference: remote, directory: directory, localDirectory: localDirectory)
                    }.value
                    guard restoredPath != nil else { return }
                }
                guard !Task.isCancelled, settings.hasPurchase, settings.enableICloudDataSync,
                      path() == originalPath, settings.username == originalUsername, store.string(forKey: key) == remote else { return }
                // Record first, so delayed defaults notifications cannot upload a downloaded image again.
                defaults.set(restoredPath, forKey: pathKey)
                defaults.set(remote, forKey: referenceKey)
                setPath(restoredPath)
            }
        } catch {
            // Keep local image and reference on transient Drive/download failures; retry on metadata/foreground events.
            print("iCloud \(kind) sync pending: \(type(of: error))")
        }
    }
}
