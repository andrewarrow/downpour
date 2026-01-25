//
//  YtDlpView.swift
//  Downpour
//

import SwiftUI
import AppKit
import Vision

struct FrameGroup: Identifiable {
    let id = UUID()
    var frames: [URL]
    var representativeFrame: URL { frames.first! }
}

struct YtDlpView: View {
    @Environment(\.openWindow) private var openWindow
    @State private var urlText: String = ""
    @State private var outputText: String = ""
    @State private var isDownloading: Bool = false
    @State private var progress: Double = 0.0
    @State private var progressText: String = ""
    @State private var thumbnails: [URL] = []
    @FocusState private var isTextFieldFocused: Bool
    @State private var showingFramesForVideoId: String? = nil
    @State private var extractedFrames: [URL] = []
    @State private var isExtractingFrames: Bool = false
    @State private var frameGroups: [FrameGroup] = []
    @State private var isGroupingFrames: Bool = false
    @State private var showGrouped: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            if let videoId = showingFramesForVideoId {
                // Frames navigation view
                HStack {
                    Button(action: goBackFromFrames) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)

                    Spacer()

                    Text("Scene Changes: \(videoId)")
                        .font(.headline)

                    Spacer()

                    if isGroupingFrames {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else if !extractedFrames.isEmpty {
                        Button(showGrouped ? "Show Timeline" : "Group Similar") {
                            if showGrouped {
                                showGrouped = false
                            } else {
                                groupFramesBySimilarity()
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor))

                if isExtractingFrames {
                    ProgressView("Detecting scene changes...")
                        .padding()
                }

                ScrollView {
                    if showGrouped && !frameGroups.isEmpty {
                        // Grouped view
                        LazyVStack(alignment: .leading, spacing: 20) {
                            ForEach(Array(frameGroups.enumerated()), id: \.element.id) { index, group in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Group \(index + 1) (\(group.frames.count) frames)")
                                        .font(.headline)
                                        .padding(.horizontal)

                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 12) {
                                        ForEach(group.frames, id: \.self) { frameURL in
                                            if let nsImage = NSImage(contentsOf: frameURL) {
                                                VStack(spacing: 4) {
                                                    Image(nsImage: nsImage)
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fit)
                                                        .frame(height: 90)
                                                        .cornerRadius(4)
                                                    Text("\(frameURL.deletingPathExtension().lastPathComponent)s")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }

                                if index < frameGroups.count - 1 {
                                    Divider()
                                        .padding(.vertical, 8)
                                }
                            }
                        }
                        .padding(.vertical)
                    } else {
                        // Timeline view
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 12) {
                            ForEach(extractedFrames, id: \.self) { frameURL in
                                if let nsImage = NSImage(contentsOf: frameURL) {
                                    VStack(spacing: 4) {
                                        Image(nsImage: nsImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(height: 90)
                                            .cornerRadius(4)
                                        Text("\(frameURL.deletingPathExtension().lastPathComponent)s")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
            } else {
                // Main view
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
                                    .contextMenu {
                                        Button("Copy YouTube URL") {
                                            copyYouTubeURL(for: url)
                                        }
                                        Divider()
                                        Button("Extract Scene Changes") {
                                            extractIDRFrames(for: url)
                                        }
                                    }
                            }
                        }
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            loadThumbnails()
            isTextFieldFocused = true
        }
    }

    private func goBackFromFrames() {
        showingFramesForVideoId = nil
        extractedFrames = []
        frameGroups = []
        showGrouped = false
    }

    private func groupFramesBySimilarity() {
        guard !extractedFrames.isEmpty else { return }

        isGroupingFrames = true

        Task.detached(priority: .userInitiated) {
            // Two-stage clustering:
            // 1. First group by face composition (number of faces + positions)
            // 2. Then sub-cluster by visual similarity within each composition

            var frameData: [(url: URL, composition: String, featurePrint: VNFeaturePrintObservation)] = []

            for frameURL in await self.extractedFrames {
                let composition = detectComposition(for: frameURL)
                if let featurePrint = computeFeaturePrint(for: frameURL) {
                    frameData.append((url: frameURL, composition: composition, featurePrint: featurePrint))
                }
            }

            // Group by composition first
            var compositionGroups: [String: [(url: URL, featurePrint: VNFeaturePrintObservation)]] = [:]
            for frame in frameData {
                compositionGroups[frame.composition, default: []].append((url: frame.url, featurePrint: frame.featurePrint))
            }

            // Within each composition group, cluster by feature print similarity
            var allGroups: [FrameGroup] = []
            for (_, frames) in compositionGroups {
                let subGroups = clusterFrames(frames, threshold: 0.45)
                allGroups.append(contentsOf: subGroups)
            }

            // Sort by group size (largest first)
            allGroups.sort { $0.frames.count > $1.frames.count }

            await MainActor.run {
                self.frameGroups = allGroups
                self.showGrouped = true
                self.isGroupingFrames = false
            }
        }
    }

    // Detect face composition: number of faces and their horizontal positions
    nonisolated private func detectComposition(for imageURL: URL) -> String {
        guard let image = CIImage(contentsOf: imageURL) else { return "unknown" }

        let requestHandler = VNImageRequestHandler(ciImage: image, options: [:])
        let request = VNDetectFaceRectanglesRequest()

        do {
            try requestHandler.perform([request])
            guard let faces = request.results, !faces.isEmpty else {
                return "0faces"
            }

            let faceCount = faces.count

            // Categorize face positions (normalized x: 0=left, 1=right)
            // Split into thirds: left (0-0.33), center (0.33-0.66), right (0.66-1)
            var positions: Set<String> = []
            for face in faces {
                let centerX = face.boundingBox.midX
                if centerX < 0.33 {
                    positions.insert("L")
                } else if centerX > 0.66 {
                    positions.insert("R")
                } else {
                    positions.insert("C")
                }
            }

            let positionStr = positions.sorted().joined()
            return "\(faceCount)faces_\(positionStr)"
        } catch {
            return "unknown"
        }
    }

    nonisolated private func computeFeaturePrint(for imageURL: URL) -> VNFeaturePrintObservation? {
        guard let image = CIImage(contentsOf: imageURL) else { return nil }

        let requestHandler = VNImageRequestHandler(ciImage: image, options: [:])
        let request = VNGenerateImageFeaturePrintRequest()

        do {
            try requestHandler.perform([request])
            return request.results?.first as? VNFeaturePrintObservation
        } catch {
            return nil
        }
    }

    nonisolated private func clusterFrames(_ frames: [(url: URL, featurePrint: VNFeaturePrintObservation)], threshold: Float) -> [FrameGroup] {
        guard !frames.isEmpty else { return [] }

        var groups: [[(url: URL, featurePrint: VNFeaturePrintObservation)]] = []

        for frame in frames {
            var addedToGroup = false

            // Try to find an existing group this frame belongs to
            for i in 0..<groups.count {
                // Compare with the representative (first) frame of the group
                let representative = groups[i][0]
                var distance: Float = 0

                do {
                    try representative.featurePrint.computeDistance(&distance, to: frame.featurePrint)

                    // Lower distance = more similar. Threshold determines grouping sensitivity.
                    if distance < threshold {
                        groups[i].append(frame)
                        addedToGroup = true
                        break
                    }
                } catch {
                    continue
                }
            }

            // If no matching group found, create a new one
            if !addedToGroup {
                groups.append([frame])
            }
        }

        // Convert to FrameGroup structs
        return groups.map { FrameGroup(frames: $0.map { $0.url }) }
    }

    private func copyYouTubeURL(for thumbnailURL: URL) {
        let videoId = thumbnailURL.deletingPathExtension().lastPathComponent
        let url = "https://www.youtube.com/watch?v=\(videoId)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
    }

    private func extractIDRFrames(for thumbnailURL: URL) {
        let videoId = thumbnailURL.deletingPathExtension().lastPathComponent
        let videoURL = thumbnailURL.deletingPathExtension().appendingPathExtension("mp4")
        let framesDir = Paths.dataDirectory.appendingPathComponent(videoId)

        // Check if frames already exist
        let existingFrames = (try? FileManager.default.contentsOfDirectory(at: framesDir, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension == "jpg" } ?? []

        if !existingFrames.isEmpty {
            // Frames already extracted, just load and show grouped view
            showingFramesForVideoId = videoId
            extractedFrames = existingFrames.sorted { url1, url2 in
                let num1 = Int(url1.deletingPathExtension().lastPathComponent) ?? 0
                let num2 = Int(url2.deletingPathExtension().lastPathComponent) ?? 0
                return num1 < num2
            }
            groupFramesBySimilarity()
            return
        }

        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            outputText = "Video file not found: \(videoURL.lastPathComponent)"
            return
        }

        showingFramesForVideoId = videoId
        isExtractingFrames = true
        extractedFrames = []

        // Start polling for new frames
        Task {
            while isExtractingFrames {
                await loadExtractedFrames(framesDir: framesDir)
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
        }

        Task.detached(priority: .userInitiated) {
            await runFFmpegExtractIDR(videoId: videoId, videoURL: videoURL)
        }
    }

    nonisolated private func runFFmpegExtractIDR(videoId: String, videoURL: URL) async {
        let framesDir = Paths.dataDirectory.appendingPathComponent(videoId)

        // Create directory
        try? FileManager.default.createDirectory(at: framesDir, withIntermediateDirectories: true)

        // Use ffmpeg scene detection to extract frames with significant visual changes
        // gt(scene,0.3) triggers when >30% of pixels change significantly
        // -frame_pts 1 names output files with PTS values (converted to seconds later)

        let process = Process()
        process.executableURL = Paths.ffmpegExecutable
        process.arguments = [
            "-i", videoURL.path,
            "-vf", "select='gt(scene,0.3)'",
            "-vsync", "vfr",
            "-frame_pts", "1",
            "-q:v", "2",
            framesDir.appendingPathComponent("%d.jpg").path
        ]

        var env = ProcessInfo.processInfo.environment
        env["PATH"] = Paths.pathEnvironment
        process.environment = env

        // Discard output to prevent pipe buffer from filling and blocking
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                // Now we need to rename files from frame PTS to seconds
                // The %d gives us PTS values, we need to convert to seconds
                // We need to get the video timebase first
                await renameFramesToSeconds(framesDir: framesDir, videoURL: videoURL)
            }

            // Load the extracted frames
            await loadExtractedFrames(framesDir: framesDir)

            await MainActor.run {
                self.isExtractingFrames = false
            }
        } catch {
            await MainActor.run {
                self.isExtractingFrames = false
                self.outputText = "Failed to extract frames: \(error.localizedDescription)"
            }
        }
    }

    nonisolated private func renameFramesToSeconds(framesDir: URL, videoURL: URL) async {
        // Get video timebase using ffprobe
        let probeProcess = Process()
        probeProcess.executableURL = Paths.ffmpegExecutable.deletingLastPathComponent().appendingPathComponent("ffprobe")
        probeProcess.arguments = [
            "-v", "error",
            "-select_streams", "v:0",
            "-show_entries", "stream=time_base",
            "-of", "csv=p=0",
            videoURL.path
        ]

        var env = ProcessInfo.processInfo.environment
        env["PATH"] = Paths.pathEnvironment
        probeProcess.environment = env

        let probePipe = Pipe()
        probeProcess.standardOutput = probePipe
        probeProcess.standardError = Pipe()

        var timebaseNum = 1
        var timebaseDen = 1000

        do {
            try probeProcess.run()
            probeProcess.waitUntilExit()

            let data = probePipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                let parts = output.split(separator: "/")
                if parts.count == 2, let num = Int(parts[0]), let den = Int(parts[1]) {
                    timebaseNum = num
                    timebaseDen = den
                }
            }
        } catch {
            // Use default timebase
        }

        // Rename files from PTS to seconds
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: framesDir, includingPropertiesForKeys: nil) else {
            return
        }

        for file in files where file.pathExtension == "jpg" {
            let filename = file.deletingPathExtension().lastPathComponent
            if let pts = Int(filename) {
                let seconds = Double(pts) * Double(timebaseNum) / Double(timebaseDen)
                let secondsInt = Int(seconds)
                let newURL = framesDir.appendingPathComponent("\(secondsInt).jpg")
                if file != newURL {
                    try? fileManager.moveItem(at: file, to: newURL)
                }
            }
        }
    }

    nonisolated private func loadExtractedFrames(framesDir: URL) async {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: framesDir, includingPropertiesForKeys: nil) else {
            return
        }

        let sortedFrames = files
            .filter { $0.pathExtension == "jpg" }
            .sorted { url1, url2 in
                let num1 = Int(url1.deletingPathExtension().lastPathComponent) ?? 0
                let num2 = Int(url2.deletingPathExtension().lastPathComponent) ?? 0
                return num1 < num2
            }

        await MainActor.run {
            self.extractedFrames = sortedFrames
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
            let terminationStatus = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int32, Error>) in
                process.terminationHandler = { proc in
                    continuation.resume(returning: proc.terminationStatus)
                }
                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            pipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil

            if terminationStatus == 0 {
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
                    self.outputText = "Download failed (exit code: \(terminationStatus))"
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
