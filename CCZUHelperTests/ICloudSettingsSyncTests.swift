import XCTest
@testable import CCZUHelper

final class ICloudSettingsSyncTests: XCTestCase {
    func testIndependentEditsOnTwoDevicesAreMergedPerKey() {
        let original: [String: Any] = ["weekStartDay": 1, "backgroundOpacity": 0.3]
        var deviceA = ICloudSettingsMerge(baseline: original)
        var deviceB = ICloudSettingsMerge(baseline: original)
        let localA: [String: Any] = ["weekStartDay": 7, "backgroundOpacity": 0.3]
        let localB: [String: Any] = ["weekStartDay": 1, "backgroundOpacity": 0.8]
        let uploadA = deviceA.localChanges(in: localA)
        XCTAssertEqual(Set(uploadA.keys), ["weekStartDay"])
        var cloud = original
        cloud.merge(uploadA) { _, new in new }
        deviceA.record(localA)
        let resultB = deviceB.reconcile(local: localB, remote: cloud)
        XCTAssertEqual(resultB.apply["weekStartDay"] as? Int, 7)
        XCTAssertNil(resultB.apply["backgroundOpacity"])
        XCTAssertEqual(Set(resultB.upload.keys), ["backgroundOpacity"])
        cloud.merge(resultB.upload) { _, new in new }
        let resultA = deviceA.reconcile(local: localA, remote: cloud)
        XCTAssertEqual(resultA.apply["backgroundOpacity"] as? Double, 0.8)
        XCTAssertTrue(resultA.upload.isEmpty)
    }

    func testDelayedDefaultsNotificationDoesNotEchoRemoteValues() {
        var state = ICloudSettingsMerge(baseline: ["weekStartDay": 1])
        let remote: [String: Any] = ["weekStartDay": 7]
        let result = state.reconcile(local: ["weekStartDay": 1], remote: remote)
        XCTAssertEqual(result.apply["weekStartDay"] as? Int, 7)
        XCTAssertTrue(state.localChanges(in: remote).isEmpty)
    }

    func testNewDeviceDoesNotPublishDefaultsBeforeInitialCloudDelivery() {
        var state = ICloudSettingsMerge()
        let defaults: [String: Any] = ["weekStartDay": 1, "backgroundImageEnabled": false]
        XCTAssertTrue(state.reconcile(local: defaults, remote: [:]).upload.isEmpty)
        let result = state.reconcile(local: defaults, remote: ["weekStartDay": 7, "backgroundImageEnabled": true])
        XCTAssertEqual(result.apply["weekStartDay"] as? Int, 7)
        XCTAssertEqual(result.apply["backgroundImageEnabled"] as? Bool, true)
        XCTAssertTrue(result.upload.isEmpty)
    }

    func testOfflineEditSurvivesForegroundPull() {
        var state = ICloudSettingsMerge(baseline: ["semesterStartDate": 100.0])
        let result = state.reconcile(local: ["semesterStartDate": 200.0], remote: ["semesterStartDate": 100.0])
        XCTAssertNil(result.apply["semesterStartDate"])
        XCTAssertEqual(result.upload["semesterStartDate"] as? Double, 200.0)
    }

    func testOnlyRecognizedPreferencesAreApplied() {
        var state = ICloudSettingsMerge()
        let result = state.reconcile(local: ["weekStartDay": 1], remote: ["password": "not-a-real-password", "unknown": true])
        XCTAssertTrue(result.apply.isEmpty)
        XCTAssertTrue(result.upload.isEmpty)
    }

    func testEmptyRoomListPropagatesAsAnExplicitValue() {
        let old = Data("[{\"id\":\"example\"}]".utf8)
        let cleared = Data("[]".utf8)
        var state = ICloudSettingsMerge(baseline: ["electricity_configs": old])
        let result = state.reconcile(local: ["electricity_configs": cleared], remote: ["electricity_configs": old])
        XCTAssertEqual(result.upload["electricity_configs"] as? Data, cleared)
    }

    func testImageRoundTripUsesPortableReferenceAndStableContentHash() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("device-a-avatar.png")
        let bytes = Data([0, 1, 2, 3, 255])
        try bytes.write(to: source)
        let cloud = root.appendingPathComponent("cloud")
        let name = try ICloudMediaFiles.publish(path: source.path, kind: "avatar", directory: cloud)
        XCTAssertTrue(ICloudMediaFiles.validReference(name))
        XCTAssertFalse(name.contains(source.path))
        XCTAssertEqual(try ICloudMediaFiles.publish(path: source.path, kind: "avatar", directory: cloud), name)
        let restored = try XCTUnwrap(ICloudMediaFiles.restore(reference: name, directory: cloud, localDirectory: root.appendingPathComponent("device-b")))
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: restored)), bytes)
    }

    func testMissingOrCorruptCloudImageDoesNotOverwriteLocalImage() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let name = "background-" + String(repeating: "0", count: 64) + ".image"
        let local = root.appendingPathComponent("local")
        try FileManager.default.createDirectory(at: local, withIntermediateDirectories: true)
        let previous = local.appendingPathComponent(name)
        try Data("previous image".utf8).write(to: previous)
        XCTAssertThrowsError(try ICloudMediaFiles.restore(reference: name, directory: root, localDirectory: local))
        try Data("corrupt image".utf8).write(to: root.appendingPathComponent(name))
        XCTAssertThrowsError(try ICloudMediaFiles.restore(reference: name, directory: root, localDirectory: local))
        XCTAssertEqual(try Data(contentsOf: previous), Data("previous image".utf8))
    }

    func testImageReferenceCannotEscapeTheMediaDirectory() {
        for name in ["../../private.jpg", "/tmp/private.jpg", "background-old.jpg", "https://example.com/a.png"] {
            XCTAssertFalse(ICloudMediaFiles.validReference(name))
        }
    }
}
