//
//  VideoPlayerView.swift
//  Downpour
//

import SwiftUI
import AVKit
import AVFoundation

class CustomAVPlayerView: AVPlayerView {
    var keyEventMonitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        print("[CustomAVPlayerView] viewDidMoveToWindow - window: \(window != nil)")

        if window != nil && keyEventMonitor == nil {
            keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self, let player = self.player else {
                    return event
                }

                // Only handle if our window is key
                guard self.window?.isKeyWindow == true else {
                    return event
                }

                print("[CustomAVPlayerView] Local monitor keyDown: \(event.charactersIgnoringModifiers ?? "nil")")

                switch event.charactersIgnoringModifiers?.lowercased() {
                case "l":
                    print("[CustomAVPlayerView] L pressed - jumping forward 10s")
                    let currentTime = player.currentTime()
                    let newTime = CMTimeAdd(currentTime, CMTime(seconds: 10, preferredTimescale: 1))
                    player.seek(to: newTime, toleranceBefore: .zero, toleranceAfter: .zero)
                    return nil  // Consume the event
                case "j":
                    print("[CustomAVPlayerView] J pressed - jumping back 10s")
                    let currentTime = player.currentTime()
                    let newTime = CMTimeSubtract(currentTime, CMTime(seconds: 10, preferredTimescale: 1))
                    player.seek(to: newTime, toleranceBefore: .zero, toleranceAfter: .zero)
                    return nil  // Consume the event
                case "k":
                    print("[CustomAVPlayerView] K pressed - toggling pause")
                    if player.rate == 0 {
                        player.play()
                    } else {
                        player.pause()
                    }
                    return nil  // Consume the event
                default:
                    return event
                }
            }
            print("[CustomAVPlayerView] Installed local key event monitor")
        } else if window == nil, let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
            print("[CustomAVPlayerView] Removed local key event monitor")
        }
    }

    deinit {
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            print("[CustomAVPlayerView] deinit - removed monitor")
        }
    }
}

struct AVPlayerViewWrapper: NSViewRepresentable {
    let player: AVPlayer?

    func makeNSView(context: Context) -> CustomAVPlayerView {
        let view = CustomAVPlayerView()
        view.controlsStyle = .floating
        view.player = player
        return view
    }

    func updateNSView(_ nsView: CustomAVPlayerView, context: Context) {
        nsView.player = player
    }
}

struct VideoPlayerView: View {
    let videoURL: URL
    var initialSeekTime: Double = 0
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
                    .padding(.bottom, 20)
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

        // Seek to initial time if provided
        if initialSeekTime > 0 {
            let seekTime = CMTime(seconds: initialSeekTime, preferredTimescale: 1000)
            player?.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero)
            print("[VideoPlayerView] Seeking to initial time: \(initialSeekTime)s")
        }

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
