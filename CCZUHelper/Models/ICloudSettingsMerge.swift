import Foundation

/// Track values observed on this device, so receiving a remote change does not
/// echo every preference back to iCloud or overwrite unrelated remote edits.
nonisolated struct ICloudSettingsMerge {
    private(set) var baseline: [String: Any]

    init(baseline: [String: Any] = [:]) {
        self.baseline = baseline
    }

    static func equal(_ lhs: Any?, _ rhs: Any?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil): return true
        case (nil, _), (_, nil): return false
        default: return NSDictionary(dictionary: ["value": lhs!]).isEqual(to: ["value": rhs!])
        }
    }

    func localChanges(in local: [String: Any]) -> [String: Any] {
        local.filter { key, value in
            baseline[key] != nil && !Self.equal(baseline[key], value)
        }
    }

    mutating func reconcile(local: [String: Any], remote: [String: Any]) -> (apply: [String: Any], upload: [String: Any]) {
        let changed = localChanges(in: local)
        // Missing remote keys are deliberately not filled with defaults during
        // startup: synchronize() is asynchronous and cloud data may arrive later.
        let apply = remote.filter { local[$0.key] != nil && changed[$0.key] == nil }
        var merged = local
        for (key, value) in apply { merged[key] = value }
        baseline = merged
        return (apply, changed.filter { !Self.equal(remote[$0.key], $0.value) })
    }

    mutating func record(_ values: [String: Any]) {
        baseline = values
    }
}
