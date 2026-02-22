//
//  SwiftDataMigrationManager.swift
//  CCZUHelper
//

import Foundation
import SwiftData

enum SwiftDataMigrationManager {
    static func runPostMigrationIfNeeded(container: ModelContainer) {
        let defaults = UserDefaults.standard
        let migrationKey = "swiftdata.cloudkit.compat.v1.completed"
        guard defaults.bool(forKey: migrationKey) == false else { return }

        let context = ModelContext(container)
        var changed = false

        changed = dedupeSchedules(context: context) || changed
        changed = dedupeTeahousePosts(context: context) || changed
        changed = dedupeTeahouseComments(context: context) || changed
        changed = dedupeUserLikes(context: context) || changed

        if changed {
            try? context.save()
        }

        defaults.set(true, forKey: migrationKey)
    }

    private static func dedupeSchedules(context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<Schedule>()
        guard let all = try? context.fetch(descriptor), all.isEmpty == false else { return false }

        let grouped = Dictionary(grouping: all) { $0.id }
        var changed = false
        for (_, items) in grouped where items.count > 1 {
            let sorted = items.sorted {
                if $0.isActive != $1.isActive {
                    return $0.isActive && !$1.isActive
                }
                return $0.createdAt > $1.createdAt
            }
            for duplicate in sorted.dropFirst() {
                context.delete(duplicate)
                changed = true
            }
        }
        return changed
    }

    private static func dedupeTeahousePosts(context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<TeahousePost>()
        guard let all = try? context.fetch(descriptor), all.isEmpty == false else { return false }

        let grouped = Dictionary(grouping: all) { $0.id }
        var changed = false
        for (_, items) in grouped where items.count > 1 {
            let sorted = items.sorted { $0.createdAt > $1.createdAt }
            for duplicate in sorted.dropFirst() {
                context.delete(duplicate)
                changed = true
            }
        }
        return changed
    }

    private static func dedupeTeahouseComments(context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<TeahouseComment>()
        guard let all = try? context.fetch(descriptor), all.isEmpty == false else { return false }

        let grouped = Dictionary(grouping: all) { $0.id }
        var changed = false
        for (_, items) in grouped where items.count > 1 {
            let sorted = items.sorted { $0.createdAt > $1.createdAt }
            for duplicate in sorted.dropFirst() {
                context.delete(duplicate)
                changed = true
            }
        }
        return changed
    }

    private static func dedupeUserLikes(context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<UserLike>()
        guard let all = try? context.fetch(descriptor), all.isEmpty == false else { return false }

        let grouped = Dictionary(grouping: all) { $0.id }
        var changed = false
        for (_, items) in grouped where items.count > 1 {
            let sorted = items.sorted { $0.createdAt > $1.createdAt }
            for duplicate in sorted.dropFirst() {
                context.delete(duplicate)
                changed = true
            }
        }
        return changed
    }
}

