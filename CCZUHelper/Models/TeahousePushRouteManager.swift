//
//  TeahousePushRouteManager.swift
//  CCZUHelper
//
//  Created by Codex on 2026/03/01.
//

import Foundation

extension Notification.Name {
    static let teahouseOpenPostFromPush = Notification.Name("TeahouseOpenPostFromPush")
}

enum TeahousePushRouteManager {
    private static let pendingPostIDKey = "teahouse.pending.post.id"

    static func extractPostID(from userInfo: [AnyHashable: Any]) -> String? {
        if let id = userInfo["post_id"] as? String, !id.isEmpty {
            return id
        }
        if let id = userInfo["post_id"] as? NSNumber {
            return id.stringValue
        }
        return nil
    }

    static func savePending(postID: String) {
        guard !postID.isEmpty else { return }
        UserDefaults.standard.set(postID, forKey: pendingPostIDKey)
    }

    static func consumePendingPostID() -> String? {
        guard let postID = UserDefaults.standard.string(forKey: pendingPostIDKey), !postID.isEmpty else {
            return nil
        }
        UserDefaults.standard.removeObject(forKey: pendingPostIDKey)
        return postID
    }

    static func hasPendingPostID() -> Bool {
        guard let postID = UserDefaults.standard.string(forKey: pendingPostIDKey) else {
            return false
        }
        return !postID.isEmpty
    }

    static func dispatchOpenPost(postID: String) {
        NotificationCenter.default.post(name: .teahouseOpenPostFromPush, object: postID)
    }

    static func handleIncomingPushUserInfo(_ userInfo: [AnyHashable: Any]) {
        guard let postID = extractPostID(from: userInfo) else { return }
        savePending(postID: postID)
        dispatchOpenPost(postID: postID)
    }
}
