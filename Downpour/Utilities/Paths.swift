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

    static var subsDirectory: URL {
        let subsDir = applicationSupport.appendingPathComponent("subs")
        let fileManager = FileManager.default

        // Create directory if needed
        if !fileManager.fileExists(atPath: subsDir.path) {
            try? fileManager.createDirectory(at: subsDir, withIntermediateDirectories: true)
        }

        // Check if empty and copy from bundle if so
        let contents = (try? fileManager.contentsOfDirectory(atPath: subsDir.path)) ?? []
        if contents.isEmpty {
            copyBundleSubsFiles(to: subsDir)
        }

        return subsDir
    }

    static var cacheDirectory: URL {
        let cacheDir = applicationSupport.appendingPathComponent("cache")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        return cacheDir
    }

    private static func copyBundleSubsFiles(to destination: URL) {
        let fileManager = FileManager.default

        guard let resourceURL = Bundle.main.resourceURL else { return }
        let bundleSubsDir = resourceURL.appendingPathComponent("subs")

        guard let files = try? fileManager.contentsOfDirectory(at: bundleSubsDir, includingPropertiesForKeys: nil) else {
            return
        }

        for file in files where file.pathExtension == "json" {
            let destFile = destination.appendingPathComponent(file.lastPathComponent)
            try? fileManager.copyItem(at: file, to: destFile)
        }
    }

    static func getSubsFiles() -> [URL] {
        let fileManager = FileManager.default
        let subsDir = subsDirectory

        guard let files = try? fileManager.contentsOfDirectory(at: subsDir, includingPropertiesForKeys: nil) else {
            return []
        }

        return files
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    static func getFirstSubsFile() -> URL? {
        return getSubsFiles().first
    }

    static func cacheFileURL(forSubsFile subsFile: URL) -> URL {
        let baseName = subsFile.deletingPathExtension().lastPathComponent
        return cacheDirectory.appendingPathComponent("\(baseName)_videos.json")
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
