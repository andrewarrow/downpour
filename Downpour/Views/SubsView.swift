//
//  SubsView.swift
//  Downpour
//

import SwiftUI

struct SubsView: View {
    @State private var videos: [SearchResult] = []
    @State private var isLoading: Bool = false
    @State private var errorText: String = ""
    @State private var loadedChannels: Int = 0
    @State private var totalChannels: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Loading \(loadedChannels)/\(totalChannels) channels...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Refresh") {
                    Task {
                        await loadSubscriptionVideos()
                    }
                }
                .disabled(isLoading)
                .padding(.trailing, 8)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            if !errorText.isEmpty {
                Text(errorText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.red)
                    .padding()
            }

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 16) {
                    ForEach(videos) { video in
                        SearchResultCell(result: video)
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            if videos.isEmpty {
                await loadSubscriptionVideos()
            }
        }
    }

    private func loadSubscriptionVideos() async {
        isLoading = true
        errorText = ""
        videos = []
        loadedChannels = 0

        do {
            let subscriptions = try loadSubscriptions()
            totalChannels = subscriptions.count

            var allVideos: [SearchResult] = []

            await withTaskGroup(of: [SearchResult].self) { group in
                for subscription in subscriptions {
                    group.addTask {
                        do {
                            let channelVideos = try await fetchChannelVideos(channelId: subscription.id)
                            await MainActor.run {
                                loadedChannels += 1
                            }
                            return Array(channelVideos.prefix(5))
                        } catch {
                            await MainActor.run {
                                loadedChannels += 1
                            }
                            return []
                        }
                    }
                }

                for await channelVideos in group {
                    allVideos.append(contentsOf: channelVideos)
                }
            }

            // Sort by putting newest first (we don't have dates, so just shuffle to mix channels)
            allVideos.shuffle()

            await MainActor.run {
                videos = allVideos
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorText = "Failed to load subscriptions: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    private func loadSubscriptions() throws -> [Subscription] {
        // Try bundle first, then fall back to app support directory
        let url: URL
        if let bundleURL = Bundle.main.url(forResource: "subs", withExtension: "json") {
            url = bundleURL
        } else {
            // Fallback: try loading from Documents or a known path
            let fileManager = FileManager.default
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let appDir = appSupport.appendingPathComponent("Downpour")
            url = appDir.appendingPathComponent("subs.json")

            if !fileManager.fileExists(atPath: url.path) {
                throw NSError(domain: "SubsView", code: 1, userInfo: [NSLocalizedDescriptionKey: "subs.json not found"])
            }
        }

        let data = try Data(contentsOf: url)
        let subscriptions = try JSONDecoder().decode([Subscription].self, from: data)
        return subscriptions
    }

    private func fetchChannelVideos(channelId: String) async throws -> [SearchResult] {
        let apiKey = "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"
        let urlString = "https://www.youtube.com/youtubei/v1/browse?key=\(apiKey)"

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
            "browseId": channelId,
            "params": "EgZ2aWRlb3PyBgQKAjoA" // Videos tab
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }

        return parseChannelVideos(json: json)
    }

    private func parseChannelVideos(json: [String: Any]) -> [SearchResult] {
        var results: [SearchResult] = []

        // Try to find videos in the response
        if let contents = json["contents"] as? [String: Any],
           let twoColumnBrowse = contents["twoColumnBrowseResultsRenderer"] as? [String: Any],
           let tabs = twoColumnBrowse["tabs"] as? [[String: Any]] {

            for tab in tabs {
                if let tabRenderer = tab["tabRenderer"] as? [String: Any],
                   let content = tabRenderer["content"] as? [String: Any],
                   let richGrid = content["richGridRenderer"] as? [String: Any],
                   let gridContents = richGrid["contents"] as? [[String: Any]] {

                    for item in gridContents {
                        if let richItem = item["richItemRenderer"] as? [String: Any],
                           let itemContent = richItem["content"] as? [String: Any],
                           let videoRenderer = itemContent["videoRenderer"] as? [String: Any],
                           let result = parseVideoRenderer(videoRenderer) {
                            results.append(result)
                        }
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
        } else if let shortByline = renderer["shortBylineText"] as? [String: Any],
                  let runs = shortByline["runs"] as? [[String: Any]],
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
        } else if let viewCountObj = renderer["viewCountText"] as? [String: Any],
                  let runs = viewCountObj["runs"] as? [[String: Any]] {
            viewCount = runs.compactMap { $0["text"] as? String }.joined()
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
