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

struct StreamingVideoView: View {
    let videoId: String
    let title: String
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var errorText: String?
    @State private var resourceLoader: StreamingResourceLoader?

    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
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
        }
        .navigationTitle(title)
        .onAppear {
            loadStream()
        }
        .onDisappear {
            player?.pause()
            resourceLoader?.cancel()
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
                await ThumbnailDownloader.download(videoId: videoId)
            } catch {
                await MainActor.run {
                    errorText = error.localizedDescription
                    isLoading = false
                }
            }
        }
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
}
