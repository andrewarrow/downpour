//
//  ChannelsView.swift
//  Downpour
//

import SwiftUI

struct ChannelsView: View {
    @State private var subscriptions: [Subscription] = []
    @State private var errorText: String = ""
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                if !errorText.isEmpty {
                    Text(errorText)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.red)
                        .padding()
                }

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 16) {
                        ForEach(subscriptions) { sub in
                            ChannelCell(subscription: sub)
                                .onTapGesture {
                                    navigationPath.append(sub)
                                }
                        }
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationDestination(for: Subscription.self) { sub in
                ChannelVideosView(subscription: sub)
            }
        }
        .task {
            loadSubscriptions()
        }
    }

    private func loadSubscriptions() {
        do {
            guard let subsFile = Paths.getFirstSubsFile() else {
                throw NSError(domain: "ChannelsView", code: 1, userInfo: [NSLocalizedDescriptionKey: "No subscription files found in subs directory"])
            }

            let data = try Data(contentsOf: subsFile)
            subscriptions = try JSONDecoder().decode([Subscription].self, from: data)
        } catch {
            errorText = "Failed to load channels: \(error.localizedDescription)"
        }
    }
}

struct ChannelCell: View {
    let subscription: Subscription

    var body: some View {
        VStack(spacing: 8) {
            AsyncImage(url: URL(string: subscription.snippet.thumbnails.default.url)) { image in
                image
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(Circle())
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(1, contentMode: .fit)
            }
            .frame(width: 100, height: 100)

            Text(subscription.snippet.title)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

struct ChannelVideosView: View {
    @Environment(\.dismiss) private var dismiss
    let subscription: Subscription

    @State private var videos: [SearchResult] = []
    @State private var isLoading: Bool = false
    @State private var errorText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Channels")
                    }
                }
                .buttonStyle(.borderless)

                Spacer()

                Text(subscription.snippet.title)
                    .font(.headline)

                Spacer()

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

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
        .navigationBarBackButtonHidden(true)
        .task {
            await loadVideos()
        }
    }

    private func loadVideos() async {
        isLoading = true
        errorText = ""

        do {
            videos = try await fetchChannelVideos(channelId: subscription.id, limit: 20)
        } catch {
            errorText = "Failed to load videos: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func fetchChannelVideos(channelId: String, limit: Int) async throws -> [SearchResult] {
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
            "params": "EgZ2aWRlb3PyBgQKAjoA"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }

        return Array(parseChannelVideos(json: json).prefix(limit))
    }

    private func parseChannelVideos(json: [String: Any]) -> [SearchResult] {
        var results: [SearchResult] = []

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
            channelName = subscription.snippet.title
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

        let publishedText: String?
        if let publishedObj = renderer["publishedTimeText"] as? [String: Any],
           let text = publishedObj["simpleText"] as? String {
            publishedText = text
        } else {
            publishedText = nil
        }

        return SearchResult(
            id: videoId,
            title: title,
            thumbnailURL: thumbnailURL,
            channelName: channelName,
            viewCount: viewCount,
            publishedText: publishedText
        )
    }
}
