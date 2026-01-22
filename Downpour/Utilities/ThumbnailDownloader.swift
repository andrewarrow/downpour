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
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                process.terminationHandler = { _ in
                    continuation.resume()
                }
                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        } catch {
            // Thumbnail download is best-effort, don't fail the whole operation
        }
    }
}
