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
            Group {
                if let url = url {
                    VideoPlayerView(videoURL: url)
                        .onAppear {
                            print("[DownpourApp] VideoPlayerView window appeared with URL: \(url)")
                        }
                } else {
                    Color.clear
                        .onAppear {
                            print("[DownpourApp] VideoPlayerView window appeared with nil URL")
                        }
                }
            }
        }
        .defaultSize(width: 800, height: 450)
        .restorationBehavior(.disabled)

        WindowGroup(for: StreamingVideo.self) { $video in
            Group {
                if let video = video {
                    StreamingVideoView(videoId: video.videoId, title: video.title)
                        .onAppear {
                            print("[DownpourApp] StreamingVideoView window appeared with videoId: \(video.videoId), title: \(video.title)")
                        }
                } else {
                    Color.clear
                        .onAppear {
                            print("[DownpourApp] StreamingVideoView window appeared with nil video")
                        }
                }
            }
        }
        .defaultSize(width: 800, height: 450)
        .restorationBehavior(.disabled)
    }
}
