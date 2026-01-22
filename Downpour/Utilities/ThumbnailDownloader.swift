//
//  ThumbnailDownloader.swift
//  Downpour
//

import Foundation

enum ThumbnailDownloader {
    static func download(videoId: String) async {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/Users/aa/venv/bin/yt-dlp")
        process.arguments = [
            "--write-thumbnail",
            "--skip-download",
            "--convert-thumbnails", "jpg",
            "-o", "./data/%(id)s.%(ext)s",
            "https://www.youtube.com/watch?v=\(videoId)"
        ]
        let projectDir = "/Users/aa/dev/Downpour"
        process.currentDirectoryURL = URL(fileURLWithPath: projectDir)

        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/Users/aa/venv/bin:" + (env["PATH"] ?? "")
        env["VIRTUAL_ENV"] = "/Users/aa/venv"
        process.environment = env

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            // Thumbnail download is best-effort, don't fail the whole operation
        }
    }
}
