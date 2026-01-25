//
//  StreamingVideoView.swift
//  Downpour
//

import SwiftUI
import AVKit
import AVFoundation
import UniformTypeIdentifiers

// Resource loader that intercepts data, saves to disk, and feeds to AVPlayer
class StreamingResourceLoader: NSObject, AVAssetResourceLoaderDelegate, URLSessionDataDelegate {
    private let actualURL: URL
    private let saveURL: URL
    private var fileHandle: FileHandle?
    private var pendingRequests: [AVAssetResourceLoadingRequest] = []
    private var downloadedData = Data()
    private var contentLength: Int64 = 0
    private var contentType: String = "public.mpeg-4"
    private var session: URLSession?
    private var dataTask: URLSessionDataTask?
    private var isFinished = false
    private let queue = DispatchQueue(label: "StreamingResourceLoader")

    var onProgressUpdate: ((Double, Int64, Int64) -> Void)?  // (progress 0-1, downloaded, total)
    var onDownloadComplete: (() -> Void)?

    init(actualURL: URL, saveURL: URL) {
        self.actualURL = actualURL
        self.saveURL = saveURL
        super.init()

        // Create/truncate the file
        FileManager.default.createFile(atPath: saveURL.path, contents: nil)
        self.fileHandle = try? FileHandle(forWritingTo: saveURL)
    }

    func startDownload() {
        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
        dataTask = session?.dataTask(with: actualURL)
        dataTask?.resume()
    }

    func cancel() {
        dataTask?.cancel()
        session?.invalidateAndCancel()
        try? fileHandle?.close()
        print("[StreamingResourceLoader] Cancelled. Saved \(downloadedData.count) bytes to \(saveURL.lastPathComponent)")
    }

    // MARK: - AVAssetResourceLoaderDelegate

    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        pendingRequests.append(loadingRequest)
        processPendingRequests()
        return true
    }

    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        pendingRequests.removeAll { $0 === loadingRequest }
    }

    // MARK: - URLSessionDataDelegate

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        contentLength = response.expectedContentLength
        if let mimeType = response.mimeType,
           let uti = UTType(mimeType: mimeType)?.identifier {
            contentType = uti
        }
        print("[StreamingResourceLoader] Content length: \(contentLength), type: \(contentType)")
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        downloadedData.append(data)
        fileHandle?.write(data)
        processPendingRequests()

        // Report progress
        if contentLength > 0 {
            let progress = Double(downloadedData.count) / Double(contentLength)
            onProgressUpdate?(progress, Int64(downloadedData.count), contentLength)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        isFinished = true
        try? fileHandle?.close()
        fileHandle = nil

        if let error = error {
            print("[StreamingResourceLoader] Download error: \(error.localizedDescription)")
            for request in pendingRequests {
                request.finishLoading(with: error)
            }
        } else {
            print("[StreamingResourceLoader] Download complete. Total: \(downloadedData.count) bytes")
            processPendingRequests()
            onDownloadComplete?()
        }
    }

    private func processPendingRequests() {
        var completedRequests: [AVAssetResourceLoadingRequest] = []

        for request in pendingRequests {
            if request.isCancelled {
                completedRequests.append(request)
                continue
            }

            // Fill content information
            if let contentRequest = request.contentInformationRequest {
                contentRequest.contentType = contentType
                contentRequest.contentLength = contentLength
                contentRequest.isByteRangeAccessSupported = false
            }

            // Fill data
            if let dataRequest = request.dataRequest {
                let requestedOffset = Int(dataRequest.requestedOffset)
                let requestedLength = dataRequest.requestedLength
                let currentOffset = Int(dataRequest.currentOffset)

                if currentOffset < downloadedData.count {
                    let availableLength = downloadedData.count - currentOffset
                    let lengthToProvide = min(requestedLength - (currentOffset - requestedOffset), availableLength)
                    if lengthToProvide > 0 {
                        let endOffset = currentOffset + lengthToProvide
                        let chunk = downloadedData.subdata(in: currentOffset..<endOffset)
                        dataRequest.respond(with: chunk)
                    }
                }

                // Check if request is fully satisfied
                let endOffset = requestedOffset + requestedLength
                if downloadedData.count >= endOffset || isFinished {
                    request.finishLoading()
                    completedRequests.append(request)
                }
            } else {
                request.finishLoading()
                completedRequests.append(request)
            }
        }

        pendingRequests.removeAll { completedRequests.contains($0) }
    }
}

class StreamingCustomAVPlayerView: AVPlayerView {
    var keyEventMonitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        print("[StreamingCustomAVPlayerView] viewDidMoveToWindow - window: \(window != nil)")

        if window != nil && keyEventMonitor == nil {
            keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self, let player = self.player else {
                    return event
                }

                // Only handle if our window is key
                guard self.window?.isKeyWindow == true else {
                    return event
                }

                print("[StreamingCustomAVPlayerView] Local monitor keyDown: \(event.charactersIgnoringModifiers ?? "nil")")

                switch event.charactersIgnoringModifiers?.lowercased() {
                case "l":
                    print("[StreamingCustomAVPlayerView] L pressed - jumping forward 10s")
                    let currentTime = player.currentTime()
                    let newTime = CMTimeAdd(currentTime, CMTime(seconds: 10, preferredTimescale: 1))
                    player.seek(to: newTime, toleranceBefore: .zero, toleranceAfter: .zero)
                    return nil  // Consume the event
                case "j":
                    print("[StreamingCustomAVPlayerView] J pressed - jumping back 10s")
                    let currentTime = player.currentTime()
                    let newTime = CMTimeSubtract(currentTime, CMTime(seconds: 10, preferredTimescale: 1))
                    player.seek(to: newTime, toleranceBefore: .zero, toleranceAfter: .zero)
                    return nil  // Consume the event
                case "k":
                    print("[StreamingCustomAVPlayerView] K pressed - toggling pause")
                    if player.rate == 0 {
                        player.play()
                    } else {
                        player.pause()
                    }
                    return nil  // Consume the event
                default:
                    return event
                }
            }
            print("[StreamingCustomAVPlayerView] Installed local key event monitor")
        } else if window == nil, let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
            print("[StreamingCustomAVPlayerView] Removed local key event monitor")
        }
    }

    deinit {
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            print("[StreamingCustomAVPlayerView] deinit - removed monitor")
        }
    }
}

struct StreamingAVPlayerViewWrapper: NSViewRepresentable {
    let player: AVPlayer?

    func makeNSView(context: Context) -> StreamingCustomAVPlayerView {
        let view = StreamingCustomAVPlayerView()
        view.controlsStyle = .floating
        view.player = player
        return view
    }

    func updateNSView(_ nsView: StreamingCustomAVPlayerView, context: Context) {
        nsView.player = player
    }
}

struct StreamingVideoView: View {
    let videoId: String
    let title: String
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var errorText: String?
    @State private var resourceLoader: StreamingResourceLoader?
    @State private var bufferProgress: Double = 0
    @State private var downloadedBytes: Int64 = 0
    @State private var totalBytes: Int64 = 0
    @State private var videoDownloadComplete = false
    @State private var subtitlesDownloadComplete = false
    @State private var switchedToLocalPlayer = false
    @State private var resumeTime: Double = 0

    private var localVideoURL: URL {
        Paths.dataDirectory.appendingPathComponent("\(videoId).mp4")
    }

    var body: some View {
        ZStack {
            if switchedToLocalPlayer {
                VideoPlayerView(videoURL: localVideoURL, initialSeekTime: resumeTime)
            } else {
                if let player = player {
                    StreamingAVPlayerViewWrapper(player: player)
                }

                if isLoading {
                    ProgressView("Loading stream...")
                }

                if let error = errorText {
                    VStack {
                        Text("Failed to load video")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Buffer progress bar overlay
                if !isLoading && player != nil && bufferProgress < 1.0 {
                    VStack {
                        Spacer()
                        HStack {
                            ProgressView(value: bufferProgress, total: 1.0)
                                .progressViewStyle(.linear)
                                .tint(.blue)
                            Text("\(Int(bufferProgress * 100))%")
                                .font(.caption)
                                .monospacedDigit()
                            Text(formatBytes(downloadedBytes) + " / " + formatBytes(totalBytes))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .padding()
                    }
                }
            }
        }
        .navigationTitle(title)
        .onAppear {
            loadStream()
        }
        .onDisappear {
            if !switchedToLocalPlayer {
                player?.pause()
                resourceLoader?.cancel()
            }
        }
    }

    private func loadStream() {
        Task {
            do {
                let streamURL = try await fetchStreamURL(videoId: videoId)
                await MainActor.run {
                    setupPlayerWithResourceLoader(streamURL: streamURL)
                }
                // Download thumbnail in the background
                Task {
                    await ThumbnailDownloader.download(videoId: videoId)
                }
                // Download subtitles and track completion
                Task {
                    await SubtitleDownloader.download(videoId: videoId)
                    await MainActor.run {
                        subtitlesDownloadComplete = true
                        checkAndSwitchToLocalPlayer()
                    }
                }
            } catch {
                await MainActor.run {
                    errorText = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func checkAndSwitchToLocalPlayer() {
        guard videoDownloadComplete && subtitlesDownloadComplete && !switchedToLocalPlayer else { return }
        guard let player = player else { return }

        // Get current playback time
        let currentTime = player.currentTime()
        resumeTime = CMTimeGetSeconds(currentTime)

        // Pause streaming player
        player.pause()

        // Clean up resource loader
        resourceLoader?.cancel()
        resourceLoader = nil

        print("[StreamingVideoView] Switching to local player at \(resumeTime)s")

        // Switch to local player
        switchedToLocalPlayer = true
    }

    private func setupPlayerWithResourceLoader(streamURL: URL) {
        let dataDir = Paths.dataDirectory
        let saveURL = dataDir.appendingPathComponent("\(videoId).mp4")

        // Create custom URL scheme for interception
        var components = URLComponents(url: streamURL, resolvingAgainstBaseURL: false)!
        components.scheme = "downpour"
        let customURL = components.url!

        // Setup resource loader
        let loader = StreamingResourceLoader(actualURL: streamURL, saveURL: saveURL)
        loader.onProgressUpdate = { progress, downloaded, total in
            self.bufferProgress = progress
            self.downloadedBytes = downloaded
            self.totalBytes = total
        }
        loader.onDownloadComplete = {
            self.videoDownloadComplete = true
            self.checkAndSwitchToLocalPlayer()
        }
        resourceLoader = loader

        // Create asset with custom scheme
        let asset = AVURLAsset(url: customURL)
        asset.resourceLoader.setDelegate(loader, queue: DispatchQueue.main)

        // Start background download
        loader.startDownload()

        // Create player
        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        player?.play()
        player?.rate = 2.0
        isLoading = false

        print("[StreamingVideoView] Streaming and saving to: \(saveURL.path)")
    }

    private func fetchStreamURL(videoId: String) async throws -> URL {
        print("[DEBUG] Fetching stream URL via yt-dlp for videoId: \(videoId)")

        let process = Process()
        process.executableURL = Paths.ytDlpExecutable
        process.arguments = [
            "-f", "18/22/best[ext=mp4]",
            "-g",
            "https://www.youtube.com/watch?v=\(videoId)"
        ]

        var env = ProcessInfo.processInfo.environment
        env["PATH"] = Paths.pathEnvironment
        process.environment = env

        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe

        let (outputData, errorData) = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Data, Data), Error>) in
            process.terminationHandler = { _ in
                let output = pipe.fileHandleForReading.readDataToEndOfFile()
                let error = errorPipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: (output, error))
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }

        if let errorStr = String(data: errorData, encoding: .utf8), !errorStr.isEmpty {
            print("[DEBUG] yt-dlp stderr: \(errorStr)")
        }

        guard process.terminationStatus == 0,
              let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !output.isEmpty,
              let streamURL = URL(string: output) else {
            print("[DEBUG] yt-dlp failed with status: \(process.terminationStatus)")
            throw URLError(.resourceUnavailable)
        }

        print("[DEBUG] Got stream URL: \(streamURL.absoluteString.prefix(100))...")
        return streamURL
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
