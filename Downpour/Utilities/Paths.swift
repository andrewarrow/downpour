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

    static var venvDirectory: URL {
        applicationSupport.appendingPathComponent("venv")
    }

    static var venvBinDirectory: URL {
        venvDirectory.appendingPathComponent("bin")
    }

    static var ytDlpExecutable: URL {
        venvBinDirectory.appendingPathComponent("yt-dlp")
    }

    static var pipExecutable: URL {
        venvBinDirectory.appendingPathComponent("pip")
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

    static var pythonExecutable: URL {
        // Check for python3 in common locations
        let possiblePaths = [
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3"
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }

        // Fallback - assume python3 is in PATH
        return URL(fileURLWithPath: "/usr/bin/python3")
    }

    static var pathEnvironment: String {
        let basePath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        return venvBinDirectory.path + ":/opt/homebrew/bin:/usr/local/bin:" + basePath
    }
}
