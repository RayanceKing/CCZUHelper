//
//  AnimatedImageView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/11/30.
//

import SwiftUI
import ImageIO

#if canImport(UIKit)
import UIKit

struct AnimatedImageView: UIViewRepresentable {
    private let url: URL

    init(url: URL) {
        self.url = url
    }

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        
        if let images = UIImage.animatedImage(from: url) {
            imageView.animationImages = images.frames
            imageView.animationDuration = images.duration
            imageView.startAnimating()
        }
        
        return imageView
    }
    
    func updateUIView(_ uiView: UIImageView, context: Context) {}
}

extension UIImage {
    struct AnimatedImage {
        let frames: [UIImage]
        let duration: TimeInterval
    }

    static func animatedImage(from url: URL) -> AnimatedImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        
        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 1 else { return nil }

        var frames: [UIImage] = []
        var duration: TimeInterval = 0

        for i in 0..<frameCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            
            let frameDuration: TimeInterval
            if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
               let pngProperties = properties[kCGImagePropertyPNGDictionary as String] as? [String: Any] {
                
                if let unclampedDelayTime = pngProperties[kCGImagePropertyAPNGUnclampedDelayTime as String] as? TimeInterval, unclampedDelayTime > 0.01 {
                    frameDuration = unclampedDelayTime
                } else if let delayTime = pngProperties[kCGImagePropertyAPNGDelayTime as String] as? TimeInterval, delayTime > 0.01 {
                    frameDuration = delayTime
                } else {
                    frameDuration = 0.1
                }
            } else {
                frameDuration = 0.1
            }
            
            duration += frameDuration
            frames.append(UIImage(cgImage: cgImage))
        }

        return AnimatedImage(frames: frames, duration: duration)
    }
}
#elseif canImport(AppKit)
struct AnimatedImageView: NSViewRepresentable {
    private let url: URL

    init(url: URL) {
        self.url = url
    }

    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleAxesIndependently
        imageView.animates = true
        
        if let image = NSImage(contentsOf: url) {
             imageView.image = image
        }
        
        return imageView
    }
    
    func updateNSView(_ nsView: NSImageView, context: Context) {}
}
#endif
