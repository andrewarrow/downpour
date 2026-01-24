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
    @State private var subtitleCues: [SubtitleCue] = []
    @State private var currentSubtitle: String = ""
    @State private var timeObserver: Any?

    private var videoId: String {
        videoURL.deletingPathExtension().lastPathComponent
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AVPlayerViewWrapper(player: player)

            if !currentSubtitle.isEmpty {
                Text(currentSubtitle)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
                    .shadow(color: .black, radius: 2, x: 1, y: 1)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                    .padding(.bottom, 80)
            }
        }
        .onAppear {
            loadSubtitles()
            setupPlayer()
        }
        .onDisappear {
            if let observer = timeObserver {
                player?.removeTimeObserver(observer)
            }
            player?.pause()
        }
    }

    private func loadSubtitles() {
        let subtitleURL = Paths.dataDirectory.appendingPathComponent("\(videoId).vtt")
        if FileManager.default.fileExists(atPath: subtitleURL.path) {
            subtitleCues = VTTParser.parse(url: subtitleURL)
            print("[VideoPlayerView] Loaded \(subtitleCues.count) subtitle cues")
        }
    }

    private func setupPlayer() {
        player = AVPlayer(url: videoURL)
        player?.play()
        player?.rate = 2.0

        // Add time observer for subtitles
        if !subtitleCues.isEmpty {
            let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
                let currentTime = CMTimeGetSeconds(time)
                updateSubtitle(for: currentTime)
            }
        }
    }

    private func updateSubtitle(for time: TimeInterval) {
        // Find the cue that matches the current time
        if let cue = subtitleCues.first(where: { time >= $0.startTime && time < $0.endTime }) {
            if currentSubtitle != cue.text {
                currentSubtitle = cue.text
            }
        } else {
            if !currentSubtitle.isEmpty {
                currentSubtitle = ""
            }
        }
    }
}
