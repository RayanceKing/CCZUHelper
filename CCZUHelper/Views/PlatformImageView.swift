//
//  PlatformImageView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/06.
//

import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// A cross-platform SwiftUI View to display PlatformImage (UIImage or NSImage).
struct PlatformImageView: View {
    // Move the typealias inside the struct to scope it, avoiding global conflicts
    #if os(iOS)
    typealias PlatformImage = UIImage
    #elseif os(macOS)
    typealias PlatformImage = NSImage
    #else
    // Fallback for other platforms, though the project seems to target iOS/macOS
    typealias PlatformImage = Any
    #endif

    let platformImage: PlatformImage

    var body: some View {
        Group {
            #if os(iOS)
            // On iOS, platformImage is always UIImage, so no cast is needed.
            Image(uiImage: platformImage)
                .resizable()
            #elseif os(macOS)
            // On macOS, platformImage is always NSImage, so no cast is needed.
            Image(nsImage: platformImage)
                .resizable()
            #else
            // Generic fallback if PlatformImage is Any and not convertible
            Image(systemName: "photo.fill")
            #endif
        }
    }
}
