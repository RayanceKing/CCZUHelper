//
//  BackgroundVideoPlayerView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/11/30.
//

import SwiftUI
import AVFoundation

struct BackgroundVideoPlayerView: View {
    private var player: AVQueuePlayer
    private var playerLooper: AVPlayerLooper

    init?(videoURL: URL) {
        guard FileManager.default.fileExists(atPath: videoURL.path) else { return nil }
        
        // Use AVURLAsset(url:) instead of AVAsset(url:) to address the deprecation warning.
        let asset = AVURLAsset(url: videoURL)
        let playerItem = AVPlayerItem(asset: asset)
        self.player = AVQueuePlayer(playerItem: playerItem)
        self.playerLooper = AVPlayerLooper(player: player, templateItem: playerItem)
        self.player.isMuted = true
    }

    var body: some View {
        #if canImport(UIKit)
        PlayerContainerView_iOS(player: player)
            .onAppear { player.play() }
            .onDisappear { player.pause() }
        #elseif canImport(AppKit)
        PlayerContainerView_macOS(player: player)
            .onAppear { player.play() }
            .onDisappear { player.pause() }
        #endif
    }
}

#if canImport(UIKit)
private struct PlayerContainerView_iOS: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.frame = view.bounds
        view.layer.addSublayer(playerLayer)
        context.coordinator.playerLayer = playerLayer
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.playerLayer?.frame = uiView.bounds
    }
    
    func makeCoordinator() -> Coordinator { Coordinator() }
    
    class Coordinator { var playerLayer: AVPlayerLayer? }
}
#endif

#if canImport(AppKit)
private struct PlayerContainerView_macOS: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.frame = view.bounds
        view.layer?.addSublayer(playerLayer)
        context.coordinator.playerLayer = playerLayer
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.playerLayer?.frame = nsView.bounds
    }
    
    func makeCoordinator() -> Coordinator { Coordinator() }
    
    class Coordinator { var playerLayer: AVPlayerLayer? }
}
#endif
