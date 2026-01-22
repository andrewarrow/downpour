//
//  ContentView.swift
//  Downpour
//
//  Created by aa on 1/22/26.
//

import SwiftUI

struct ContentView: View {
    @State private var urlText: String = ""
    @State private var outputText: String = ""
    @State private var isDownloading: Bool = false
    @State private var progress: Double = 0.0
    @State private var progressText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            TextField("Paste URL and press Enter", text: $urlText)
                .textFieldStyle(.plain)
                .font(.system(size: 18))
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .disabled(isDownloading)
                .onSubmit {
                    startDownload()
                }

            if isDownloading {
                VStack(spacing: 4) {
                    ProgressView(value: progress, total: 100.0)
                    Text(progressText)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            ScrollView {
                Text(outputText)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func startDownload() {
        guard !urlText.isEmpty else { return }

        isDownloading = true
        progress = 0.0
        progressText = "Starting..."
        outputText = ""

        let url = urlText

        Task.detached(priority: .userInitiated) {
            await runYtDlp(url: url)
        }
    }

    private func parseProgress(from str: String) {
        // yt-dlp outputs: [download]  45.2% of 150.00MiB at 5.00MiB/s ETA 00:15
        if let range = str.range(of: #"(\d+\.?\d*)%"#, options: .regularExpression) {
            let percentStr = str[range].dropLast() // remove %
            if let percent = Double(percentStr) {
                Task { @MainActor in
                    progress = percent
                }
            }
        }
        // Extract the full progress line for display
        if str.contains("[download]") && str.contains("%") {
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            Task { @MainActor in
                progressText = trimmed
            }
        }
    }

    nonisolated private func runYtDlp(url: String) async {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/Users/aa/venv/bin/yt-dlp")
        process.arguments = [
            "-o", "./data/%(id)s.%(ext)s",
            "-f", "bv*[vcodec^=avc1][ext=mp4]+ba[acodec^=mp4a][ext=m4a]/best[ext=mp4][vcodec^=avc1]",
            "--merge-output-format", "mp4",
            "--newline",
            url
        ]
        let projectDir = "/Users/aa/dev/Downpour"
        process.currentDirectoryURL = URL(fileURLWithPath: projectDir)

        // Set up environment with venv activated
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/Users/aa/venv/bin:" + (env["PATH"] ?? "")
        env["VIRTUAL_ENV"] = "/Users/aa/venv"
        process.environment = env

        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                Task { @MainActor in
                    self.parseProgress(from: str)
                }
            }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                Task { @MainActor in
                    self.parseProgress(from: str)
                }
            }
        }

        do {
            try process.run()
            process.waitUntilExit()

            pipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil

            if process.terminationStatus == 0 {
                await MainActor.run {
                    self.progressText = "Downloading thumbnail..."
                }
                await downloadThumbnail(url: url)
                await MainActor.run {
                    self.outputText = "Download completed successfully."
                    self.isDownloading = false
                    self.urlText = ""
                    self.progress = 0.0
                    self.progressText = ""
                }
            } else {
                await MainActor.run {
                    self.outputText = "Download failed (exit code: \(process.terminationStatus))"
                    self.isDownloading = false
                    self.urlText = ""
                    self.progress = 0.0
                    self.progressText = ""
                }
            }
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            await MainActor.run {
                self.outputText = "Error: \(error.localizedDescription)"
                self.isDownloading = false
            }
        }
    }

    nonisolated private func downloadThumbnail(url: String) async {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/Users/aa/venv/bin/yt-dlp")
        process.arguments = [
            "--write-thumbnail",
            "--skip-download",
            "-o", "./data/%(id)s.%(ext)s",
            url
        ]
        let projectDir = "/Users/aa/dev/Downpour"
        process.currentDirectoryURL = URL(fileURLWithPath: projectDir)

        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/Users/aa/venv/bin:" + (env["PATH"] ?? "")
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

#Preview {
    ContentView()
}
