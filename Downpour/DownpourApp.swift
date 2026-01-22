//
//  DownpourApp.swift
//  Downpour
//
//  Created by aa on 1/22/26.
//

import SwiftUI
import AVKit

@main
struct DownpourApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }

        WindowGroup(for: URL.self) { $url in
            if let url = url {
                VideoPlayerView(videoURL: url)
            }
        }
        .defaultSize(width: 800, height: 450)
    }
}

struct VideoPlayerView: View {
    let videoURL: URL
    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                player = AVPlayer(url: videoURL)
                player?.play()
            }
            .onDisappear {
                player?.pause()
            }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let window = NSApplication.shared.windows.first,
           let screen = NSScreen.main {
            window.setFrame(screen.visibleFrame, display: true)
        }
    }
}
