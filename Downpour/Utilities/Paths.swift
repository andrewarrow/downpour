//
//  Paths.swift
//  Downpour
//

import Foundation

enum Paths {
    static var applicationSupport: URL {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("Downpour")
        try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir
    }

    static var dataDirectory: URL {
        let dataDir = applicationSupport.appendingPathComponent("data")
        try? FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)
        return dataDir
    }

    static var ytDlpExecutable: URL {
        // Check common locations for yt-dlp
        let possiblePaths = [
            "/opt/homebrew/bin/yt-dlp",
            "/usr/local/bin/yt-dlp",
            "/usr/bin/yt-dlp"
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }

        // Fallback to homebrew location
        return URL(fileURLWithPath: "/opt/homebrew/bin/yt-dlp")
    }

    static var ffmpegExecutable: URL {
        let possiblePaths = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg"
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }

        return URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
    }

    static var pathEnvironment: String {
        let basePath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        return "/opt/homebrew/bin:/usr/local/bin:" + basePath
    }
}
