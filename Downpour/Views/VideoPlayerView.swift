//
//  VideoPlayerView.swift
//  Downpour
//

import SwiftUI
import AVKit

struct AVPlayerViewWrapper: NSViewRepresentable {
    let player: AVPlayer?

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .floating
        view.player = player
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}

struct VideoPlayerView: View {
    let videoURL: URL
    @State private var player: AVPlayer?

    var body: some View {
        AVPlayerViewWrapper(player: player)
            .onAppear {
                player = AVPlayer(url: videoURL)
                player?.play()
                player?.rate = 2.0
            }
            .onDisappear {
                player?.pause()
            }
    }
}
