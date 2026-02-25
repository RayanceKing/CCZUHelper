import Foundation

extension Notification.Name {
    static let watchSyncRequestReceived = Notification.Name("watchSyncRequestReceived")
}

#if canImport(WatchConnectivity) && os(iOS)
import WatchConnectivity

final class WatchConnectivitySyncManager: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivitySyncManager()

    private let appGroupIdentifier = AppGroupIdentifiers.main
    private let coursesFileName = "widget_courses.json"

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func pushLatestCoursesToWatch() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        guard session.isPaired, session.isWatchAppInstalled else { return }

        guard let payload = makePayload() else { return }
        do {
            try session.updateApplicationContext(payload)
        } catch {
            print("Watch sync updateApplicationContext failed: \(error)")
        }
        session.transferUserInfo(payload)
    }

    private func makePayload() -> [String: Any]? {
        guard
            let containerURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupIdentifier
            )
        else {
            return nil
        }

        let fileURL = containerURL.appendingPathComponent(coursesFileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let courses = try JSONDecoder().decode([WidgetDataManager.WidgetCourse].self, from: data)
            let coursePayload: [[String: Any]] = courses.map { course in
                [
                    "name": course.name,
                    "teacher": course.teacher,
                    "location": course.location,
                    "timeSlot": course.timeSlot,
                    "duration": course.duration,
                    "color": course.color,
                    "dayOfWeek": course.dayOfWeek
                ]
            }

            return [
                "type": "courses_sync",
                "timestamp": Date().timeIntervalSince1970,
                "courses": coursePayload
            ]
        } catch {
            print("Watch sync payload build failed: \(error)")
            return nil
        }
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            print("WatchConnectivity activate failed: \(error)")
        } else if activationState == .activated {
            pushLatestCoursesToWatch()
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) { }

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handleIncomingSyncRequestIfNeeded(message)
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String : Any]) -> Void
    ) {
        if handleIncomingSyncRequestIfNeeded(message) {
            replyHandler(["status": "accepted"])
        } else {
            replyHandler(["status": "ignored"])
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        _ = handleIncomingSyncRequestIfNeeded(userInfo)
    }

    @discardableResult
    private func handleIncomingSyncRequestIfNeeded(_ payload: [String: Any]) -> Bool {
        guard let type = payload["type"] as? String, type == "request_courses_sync" else {
            return false
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .watchSyncRequestReceived, object: nil)
        }
        return true
    }
}

#else

final class WatchConnectivitySyncManager {
    static let shared = WatchConnectivitySyncManager()
    private init() { }
    func activate() { }
    func pushLatestCoursesToWatch() { }
}

#endif
