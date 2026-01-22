//
//  DownpourApp.swift
//  Downpour
//
//  Created by aa on 1/22/26.
//

import SwiftUI
import AVKit

struct StreamingVideo: Hashable, Codable {
    let videoId: String
    let title: String
}

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

        WindowGroup(for: StreamingVideo.self) { $video in
            if let video = video {
                StreamingVideoView(videoId: video.videoId, title: video.title)
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

struct StreamingVideoView: View {
    let videoId: String
    let title: String
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var errorText: String?

    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
            }

            if isLoading {
                ProgressView("Loading stream...")
            }

            if let error = errorText {
                VStack {
                    Text("Failed to load video")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle(title)
        .onAppear {
            loadStream()
        }
        .onDisappear {
            player?.pause()
        }
    }

    private func loadStream() {
        Task {
            do {
                let streamURL = try await fetchStreamURL(videoId: videoId)
                await MainActor.run {
                    player = AVPlayer(url: streamURL)
                    player?.play()
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorText = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func fetchStreamURL(videoId: String) async throws -> URL {
        print("[DEBUG] Fetching stream URL via yt-dlp for videoId: \(videoId)")

        // Use yt-dlp to get the stream URL - it handles poToken/signatures
        // Use format 18 (360p mp4 with audio) which is a single combined stream
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/Users/aa/venv/bin/yt-dlp")
        process.arguments = [
            "-f", "18/22/best[ext=mp4]",  // 18=360p, 22=720p - combined streams
            "-g",  // Just print the URL, don't download
            "https://www.youtube.com/watch?v=\(videoId)"
        ]

        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/Users/aa/venv/bin:" + (env["PATH"] ?? "")
        env["VIRTUAL_ENV"] = "/Users/aa/venv"
        process.environment = env

        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        if let errorStr = String(data: errorData, encoding: .utf8), !errorStr.isEmpty {
            print("[DEBUG] yt-dlp stderr: \(errorStr)")
        }

        guard process.terminationStatus == 0,
              let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !output.isEmpty,
              let streamURL = URL(string: output) else {
            print("[DEBUG] yt-dlp failed with status: \(process.terminationStatus)")
            throw URLError(.resourceUnavailable)
        }

        print("[DEBUG] Got stream URL: \(streamURL.absoluteString.prefix(100))...")
        return streamURL
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
