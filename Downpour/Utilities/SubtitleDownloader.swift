//
//  SubtitleDownloader.swift
//  Downpour
//

import Foundation

enum SubtitleDownloader {
    static func download(videoId: String) async {
        let process = Process()
        process.executableURL = Paths.ytDlpExecutable
        let outputPath = Paths.dataDirectory.appendingPathComponent("\(videoId).vtt").path
        process.arguments = [
            "--write-auto-sub",
            "--sub-lang", "en",
            "--sub-format", "vtt",
            "--skip-download",
            "-o", outputPath.replacingOccurrences(of: ".vtt", with: ""),
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

            // yt-dlp saves as videoId.en.vtt, rename to videoId.vtt
            let ytdlpOutput = Paths.dataDirectory.appendingPathComponent("\(videoId).en.vtt")
            let finalOutput = Paths.dataDirectory.appendingPathComponent("\(videoId).vtt")
            if FileManager.default.fileExists(atPath: ytdlpOutput.path) {
                try? FileManager.default.removeItem(at: finalOutput)
                try? FileManager.default.moveItem(at: ytdlpOutput, to: finalOutput)
                print("[SubtitleDownloader] Saved subtitles to \(finalOutput.lastPathComponent)")
            }
        } catch {
            print("[SubtitleDownloader] Failed: \(error.localizedDescription)")
        }
    }
}
