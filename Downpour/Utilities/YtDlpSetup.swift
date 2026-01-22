//
//  YtDlpSetup.swift
//  Downpour
//

import Foundation

enum YtDlpSetup {
    static func ensureYtDlpAvailable() {
        Task.detached(priority: .userInitiated) {
            await setup()
        }
    }

    private static func setup() async {
        let venvDir = Paths.venvDirectory

        // Create venv if it doesn't exist
        if !FileManager.default.fileExists(atPath: venvDir.path) {
            print("[YtDlpSetup] Creating Python venv at \(venvDir.path)")
            let success = await createVenv()
            if !success {
                print("[YtDlpSetup] Failed to create venv")
                return
            }
        }

        // Always run pip install to ensure latest version
        print("[YtDlpSetup] Installing/updating yt-dlp...")
        await installYtDlp()
    }

    private static func createVenv() async -> Bool {
        let process = Process()
        process.executableURL = Paths.pythonExecutable
        process.arguments = ["-m", "venv", Paths.venvDirectory.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    print("[YtDlpSetup] venv creation error: \(output)")
                }
                return false
            }
            print("[YtDlpSetup] venv created successfully")
            return true
        } catch {
            print("[YtDlpSetup] Failed to create venv: \(error)")
            return false
        }
    }

    private static func installYtDlp() async {
        let process = Process()
        process.executableURL = Paths.pipExecutable
        process.arguments = ["install", "--upgrade", "yt-dlp"]

        var env = ProcessInfo.processInfo.environment
        env["PATH"] = Paths.pathEnvironment
        env["VIRTUAL_ENV"] = Paths.venvDirectory.path
        process.environment = env

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                print("[YtDlpSetup] pip output: \(output)")
            }

            if process.terminationStatus == 0 {
                print("[YtDlpSetup] yt-dlp installed/updated successfully")
            } else {
                print("[YtDlpSetup] pip install failed with status \(process.terminationStatus)")
            }
        } catch {
            print("[YtDlpSetup] Failed to run pip: \(error)")
        }
    }
}
