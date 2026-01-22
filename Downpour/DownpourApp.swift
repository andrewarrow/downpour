//
//  DownpourApp.swift
//  Downpour
//
//  Created by aa on 1/22/26.
//

import SwiftUI

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
