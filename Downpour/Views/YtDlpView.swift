//
//  YtDlpView.swift
//  Downpour
//

import SwiftUI

struct YtDlpView: View {
    @Environment(\.openWindow) private var openWindow
    @State private var urlText: String = ""
    @State private var outputText: String = ""
    @State private var isDownloading: Bool = false
    @State private var progress: Double = 0.0
    @State private var progressText: String = ""
    @State private var thumbnails: [URL] = []
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TextField("Paste URL and press Enter", text: $urlText)
                .textFieldStyle(.plain)
                .font(.system(size: 18))
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .disabled(isDownloading)
                .focused($isTextFieldFocused)
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

            if !outputText.isEmpty {
                Text(outputText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.red)
                    .padding()
            }

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 12) {
                    ForEach(thumbnails, id: \.self) { url in
                        if let nsImage = NSImage(contentsOf: url) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 90)
                                .cornerRadius(4)
                                .onTapGesture {
                                    let videoURL = url.deletingPathExtension().appendingPathExtension("mp4")
                                    openWindow(value: videoURL)
                                }
                        }
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            loadThumbnails()
            isTextFieldFocused = true
        }
    }

    private func loadThumbnails() {
        let dataDir = Paths.dataDirectory
        let fileManager = FileManager.default

        guard let files = try? fileManager.contentsOfDirectory(at: dataDir, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            thumbnails = []
            return
        }

        thumbnails = files
            .filter { $0.pathExtension.lowercased() == "jpg" }
            .sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                return date1 > date2
            }
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
        process.executableURL = Paths.ytDlpExecutable
        let outputTemplate = Paths.dataDirectory.appendingPathComponent("%(id)s.%(ext)s").path
        process.arguments = [
            "-o", outputTemplate,
            "--paths", "temp:/tmp",
            "--ffmpeg-location", Paths.ffmpegExecutable.path,
            "-f", "bv*[vcodec^=avc1][ext=mp4]+ba[acodec^=mp4a][ext=m4a]/best[ext=mp4][vcodec^=avc1]",
            "--merge-output-format", "mp4",
            "--newline",
            url
        ]

        var env = ProcessInfo.processInfo.environment
        env["PATH"] = Paths.pathEnvironment
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
                cleanupIntermediateFiles()
                await MainActor.run {
                    self.loadThumbnails()
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

    private func cleanupIntermediateFiles() {
        let dataDir = Paths.dataDirectory
        let fileManager = FileManager.default

        guard let files = try? fileManager.contentsOfDirectory(at: dataDir, includingPropertiesForKeys: nil) else {
            return
        }

        for file in files where file.pathExtension == "m4a" || file.pathExtension == "webp" {
            try? fileManager.removeItem(at: file)
        }
    }

    nonisolated private func downloadThumbnail(url: String) async {
        // Extract video ID from URL
        if let urlComponents = URLComponents(string: url),
           let videoId = urlComponents.queryItems?.first(where: { $0.name == "v" })?.value {
            await ThumbnailDownloader.download(videoId: videoId)
        }
    }
}
