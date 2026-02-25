import Foundation

#if canImport(WatchConnectivity)
import WatchConnectivity

extension Notification.Name {
    static let watchCoursesDidUpdate = Notification.Name("watchCoursesDidUpdate")
}

final class WatchConnectivityReceiver: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityReceiver()

    private let appGroupIdentifier = AppGroupIdentifiers.watch
    private let coursesFileName = "widget_courses.json"
    private var lastSyncRequestAt: Date?

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            print("Watch receiver activate failed: \(error)")
        } else if activationState == .activated {
            requestCoursesSyncFromPhone()
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        persistCourses(from: applicationContext)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        persistCourses(from: userInfo)
    }

    private func persistCourses(from payload: [String: Any]) {
        guard let rawCourses = payload["courses"] as? [[String: Any]] else { return }

        let courses: [WatchDataManager.WatchCourse] = rawCourses.compactMap { item in
            guard
                let name = item["name"] as? String,
                let teacher = item["teacher"] as? String,
                let location = item["location"] as? String,
                let timeSlot = item["timeSlot"] as? Int,
                let duration = item["duration"] as? Int,
                let color = item["color"] as? String,
                let dayOfWeek = item["dayOfWeek"] as? Int
            else {
                return nil
            }
            return WatchDataManager.WatchCourse(
                name: name,
                teacher: teacher,
                location: location,
                timeSlot: timeSlot,
                duration: duration,
                color: color,
                dayOfWeek: dayOfWeek
            )
        }

        guard
            let containerURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupIdentifier
            )
        else {
            print("Watch receiver: unable to access app group container")
            return
        }

        let fileURL = containerURL.appendingPathComponent(coursesFileName)
        do {
            let data = try JSONEncoder().encode(courses)
            try data.write(to: fileURL, options: .atomic)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .watchCoursesDidUpdate, object: nil)
            }
        } catch {
            print("Watch receiver persist failed: \(error)")
        }
    }

    func requestCoursesSyncFromPhone(force: Bool = false) {
        guard WCSession.isSupported() else { return }
        let now = Date()
        if !force, let last = lastSyncRequestAt, now.timeIntervalSince(last) < 5 {
            return
        }
        lastSyncRequestAt = now

        let session = WCSession.default
        let payload: [String: Any] = [
            "type": "request_courses_sync",
            "timestamp": now.timeIntervalSince1970
        ]

        if session.activationState == .activated, session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        } else {
            session.transferUserInfo(payload)
        }
    }
}
#endif
