//
//  ThumbnailDownloader.swift
//  Downpour
//

import Foundation

enum ThumbnailDownloader {
    static func download(videoId: String) async {
        let process = Process()
        process.executableURL = Paths.ytDlpExecutable
        let outputTemplate = Paths.dataDirectory.appendingPathComponent("%(id)s.%(ext)s").path
        process.arguments = [
            "--write-thumbnail",
            "--skip-download",
            "--convert-thumbnails", "jpg",
            "-o", outputTemplate,
            "https://www.youtube.com/watch?v=\(videoId)"
        ]

        var env = ProcessInfo.processInfo.environment
        env["PATH"] = Paths.pathEnvironment
        process.environment = env

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            // Thumbnail download is best-effort, don't fail the whole operation
        }
    }
}
