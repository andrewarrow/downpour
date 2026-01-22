//
//  ContentView.swift
//  Downpour
//
//  Created by aa on 1/22/26.
//

import SwiftUI

struct SearchResult: Identifiable {
    let id: String
    let title: String
    let thumbnailURL: URL?
    let channelName: String
    let viewCount: String
}

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                TabButton(title: "yt-dlp", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                TabButton(title: "api", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
                Spacer()
            }
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Tab content
            if selectedTab == 0 {
                YtDlpView()
            } else {
                APISearchView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color(nsColor: .controlBackgroundColor) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

struct YtDlpView: View {
    @Environment(\.openWindow) private var openWindow
    @State private var urlText: String = ""
    @State private var outputText: String = ""
    @State private var isDownloading: Bool = false
    @State private var progress: Double = 0.0
    @State private var progressText: String = ""
    @State private var thumbnails: [URL] = []

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
        }
    }

    private func loadThumbnails() {
        let dataDir = URL(fileURLWithPath: "/Users/aa/dev/Downpour/data")
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
        process.executableURL = URL(fileURLWithPath: "/Users/aa/venv/bin/yt-dlp")
        process.arguments = [
            "-o", "./data/%(id)s.%(ext)s",
            "--paths", "temp:/tmp",
            "--ffmpeg-location", "/opt/homebrew/bin/ffmpeg",
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
        let dataDir = URL(fileURLWithPath: "/Users/aa/dev/Downpour/data")
        let fileManager = FileManager.default

        guard let files = try? fileManager.contentsOfDirectory(at: dataDir, includingPropertiesForKeys: nil) else {
            return
        }

        for file in files where file.pathExtension == "m4a" || file.pathExtension == "webp" {
            try? fileManager.removeItem(at: file)
        }
    }

    nonisolated private func downloadThumbnail(url: String) async {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/Users/aa/venv/bin/yt-dlp")
        process.arguments = [
            "--write-thumbnail",
            "--skip-download",
            "--convert-thumbnails", "jpg",
            "-o", "./data/%(id)s.%(ext)s",
            url
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

struct APISearchView: View {
    @State private var searchText: String = ""
    @State private var searchResults: [SearchResult] = []
    @State private var isSearching: Bool = false
    @State private var errorText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search YouTube and press Enter", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 18))
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .disabled(isSearching)
                .onSubmit {
                    performSearch()
                }

            if isSearching {
                ProgressView()
                    .padding()
            }

            if !errorText.isEmpty {
                Text(errorText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.red)
                    .padding()
            }

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 16) {
                    ForEach(searchResults) { result in
                        SearchResultCell(result: result)
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func performSearch() {
        guard !searchText.isEmpty else { return }

        isSearching = true
        errorText = ""
        searchResults = []

        Task {
            do {
                let results = try await searchYouTube(query: searchText)
                await MainActor.run {
                    searchResults = results
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    errorText = "Search failed: \(error.localizedDescription)"
                    isSearching = false
                }
            }
        }
    }

    private func searchYouTube(query: String) async throws -> [SearchResult] {
        let apiKey = "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"
        let urlString = "https://www.youtube.com/youtubei/v1/search?key=\(apiKey)"

        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB",
                    "clientVersion": "2.20240101.00.00",
                    "hl": "en",
                    "gl": "US"
                ]
            ],
            "query": query
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }

        return parseSearchResults(json: json)
    }

    private func parseSearchResults(json: [String: Any]) -> [SearchResult] {
        var results: [SearchResult] = []

        guard let contents = json["contents"] as? [String: Any],
              let twoColumnResults = contents["twoColumnSearchResultsRenderer"] as? [String: Any],
              let primaryContents = twoColumnResults["primaryContents"] as? [String: Any],
              let sectionList = primaryContents["sectionListRenderer"] as? [String: Any],
              let sectionContents = sectionList["contents"] as? [[String: Any]] else {
            return results
        }

        for section in sectionContents {
            guard let itemSection = section["itemSectionRenderer"] as? [String: Any],
                  let items = itemSection["contents"] as? [[String: Any]] else {
                continue
            }

            for item in items {
                if let videoRenderer = item["videoRenderer"] as? [String: Any] {
                    if let result = parseVideoRenderer(videoRenderer) {
                        results.append(result)
                    }
                }
            }
        }

        return results
    }

    private func parseVideoRenderer(_ renderer: [String: Any]) -> SearchResult? {
        guard let videoId = renderer["videoId"] as? String else {
            return nil
        }

        let title: String
        if let titleObj = renderer["title"] as? [String: Any],
           let runs = titleObj["runs"] as? [[String: Any]],
           let firstRun = runs.first,
           let text = firstRun["text"] as? String {
            title = text
        } else {
            title = "Unknown"
        }

        let thumbnailURL: URL?
        if let thumbnail = renderer["thumbnail"] as? [String: Any],
           let thumbnails = thumbnail["thumbnails"] as? [[String: Any]],
           let lastThumb = thumbnails.last,
           let urlString = lastThumb["url"] as? String {
            thumbnailURL = URL(string: urlString)
        } else {
            thumbnailURL = nil
        }

        let channelName: String
        if let channelObj = renderer["ownerText"] as? [String: Any],
           let runs = channelObj["runs"] as? [[String: Any]],
           let firstRun = runs.first,
           let text = firstRun["text"] as? String {
            channelName = text
        } else {
            channelName = ""
        }

        let viewCount: String
        if let viewCountObj = renderer["viewCountText"] as? [String: Any],
           let text = viewCountObj["simpleText"] as? String {
            viewCount = text
        } else {
            viewCount = ""
        }

        return SearchResult(
            id: videoId,
            title: title,
            thumbnailURL: thumbnailURL,
            channelName: channelName,
            viewCount: viewCount
        )
    }
}

struct SearchResultCell: View {
    @Environment(\.openWindow) private var openWindow
    let result: SearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: result.thumbnailURL) { image in
                image
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fit)
                    .cornerRadius(8)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(16/9, contentMode: .fit)
                    .cornerRadius(8)
            }

            Text(result.title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(2)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.channelName)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Text(result.viewCount)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .onTapGesture {
            let video = StreamingVideo(videoId: result.id, title: result.title)
            openWindow(value: video)
        }
    }
}

#Preview {
    ContentView()
}
