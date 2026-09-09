import Foundation
import CryptoKit

/// Immutable image files live in Drive; KVS contains only a portable filename.
/// Keeping old revisions avoids deleting an image another offline device still uses.
nonisolated enum ICloudMediaFiles {
    static func validReference(_ name: String) -> Bool {
        name.range(of: "^(background|avatar)-[a-f0-9]{64}\\.image$", options: .regularExpression) != nil
    }

    static func publish(path: String, kind: String, directory: URL) throws -> String {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let name = "\(kind)-\(hash).image"
        guard validReference(name) else { throw CocoaError(.fileWriteInvalidFileName) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent(name)
        var coordinationError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: destination, options: .forReplacing, error: &coordinationError) { url in
            do { try data.write(to: url, options: .atomic) } catch { writeError = error }
        }
        if let error = coordinationError ?? writeError as NSError? { throw error }
        return name
    }

    static func restore(reference: String, directory: URL, localDirectory: URL) throws -> String? {
        guard validReference(reference) else { throw CocoaError(.fileReadInvalidFileName) }
        let source = directory.appendingPathComponent(reference)
        if (try? source.resourceValues(forKeys: [.isUbiquitousItemKey]).isUbiquitousItem) == true {
            try FileManager.default.startDownloadingUbiquitousItem(at: source)
        }
        // A Drive placeholder may not be downloaded yet. The metadata observer retries.
        var coordinationError: NSError?
        var readError: Error?
        var data: Data?
        NSFileCoordinator().coordinate(readingItemAt: source, options: .withoutChanges, error: &coordinationError) { url in
            do { data = try Data(contentsOf: url) } catch { readError = error }
        }
        if let error = coordinationError ?? readError as NSError? { throw error }
        guard let data else { return nil }
        let expectedHash = reference.split(separator: "-").last!.replacingOccurrences(of: ".image", with: "")
        let actualHash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard expectedHash == actualHash else { throw CocoaError(.fileReadCorruptFile) }
        try FileManager.default.createDirectory(at: localDirectory, withIntermediateDirectories: true)
        let destination = localDirectory.appendingPathComponent(reference)
        try data.write(to: destination, options: .atomic)
        return destination.path
    }
}
