//
//  PostDetailImageIO.swift
//  CCZUHelper
//
//  Created by Codex on 2026/2/23.
//

import Foundation
import Photos
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum PostDetailImageIO {
    static func loadImage(from url: URL) async throws -> PostDetailPlatformImage {
        let decodeDataFailedMessage = NSLocalizedString("teahouse.image.error.decode_data_failed", comment: "")
        let decodeRemoteFailedMessage = NSLocalizedString("teahouse.image.error.decode_remote_failed", comment: "")
        
        if url.isFileURL {
            let data = try Data(contentsOf: url)
            guard let image = PostDetailPlatformImage(data: data) else {
                throw NSError(
                    domain: "PostDetailView",
                    code: 101,
                    userInfo: [NSLocalizedDescriptionKey: decodeDataFailedMessage]
                )
            }
            return image
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let image = PostDetailPlatformImage(data: data) else {
            throw NSError(
                domain: "PostDetailView",
                code: 102,
                userInfo: [NSLocalizedDescriptionKey: decodeRemoteFailedMessage]
            )
        }
        return image
    }

    static func requestPhotoLibraryAuthorization() async throws {
        let permissionDeniedMessage = NSLocalizedString("teahouse.image.error.photo_permission_denied", comment: "")
        let permissionUnknownMessage = NSLocalizedString("teahouse.image.error.photo_permission_unknown", comment: "")
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                switch status {
                case .authorized, .limited:
                    continuation.resume(returning: ())
                case .denied, .restricted, .notDetermined:
                    continuation.resume(
                        throwing: NSError(
                            domain: "PostDetailView",
                            code: 103,
                            userInfo: [NSLocalizedDescriptionKey: permissionDeniedMessage]
                        )
                    )
                @unknown default:
                    continuation.resume(
                        throwing: NSError(
                            domain: "PostDetailView",
                            code: 104,
                            userInfo: [NSLocalizedDescriptionKey: permissionUnknownMessage]
                        )
                    )
                }
            }
        }
    }

    static func saveToPhotoLibrary(_ image: PostDetailPlatformImage) async throws {
        let saveFailedMessage = NSLocalizedString("teahouse.image.error.save_failed", comment: "")
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }, completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(
                        throwing: NSError(
                            domain: "PostDetailView",
                            code: 105,
                            userInfo: [NSLocalizedDescriptionKey: saveFailedMessage]
                        )
                    )
                }
            })
        }
    }
}
