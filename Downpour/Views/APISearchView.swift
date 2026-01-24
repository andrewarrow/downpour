//
//  APISearchView.swift
//  Downpour
//

import SwiftUI
import AppKit

struct APISearchView: View {
    let allSubsFiles: [URL]

    @State private var searchText: String = ""
    @State private var searchResults: [SearchResult] = []
    @State private var isSearching: Bool = false
    @State private var errorText: String = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search YouTube and press Enter", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 18))
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .disabled(isSearching)
                .focused($isTextFieldFocused)
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
                            .contextMenu {
                                Button("Copy YouTube URL") {
                                    copyVideoURL(result)
                                }
                                Menu("Add to") {
                                    ForEach(allSubsFiles, id: \.self) { targetFile in
                                        Button(targetFile.deletingPathExtension().lastPathComponent) {
                                            addChannelToCategory(result, to: targetFile)
                                        }
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
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
        var channelId: String? = nil
        if let channelObj = renderer["ownerText"] as? [String: Any],
           let runs = channelObj["runs"] as? [[String: Any]],
           let firstRun = runs.first,
           let text = firstRun["text"] as? String {
            channelName = text
            if let navEndpoint = firstRun["navigationEndpoint"] as? [String: Any],
               let browseEndpoint = navEndpoint["browseEndpoint"] as? [String: Any],
               let browseId = browseEndpoint["browseId"] as? String {
                channelId = browseId
            }
        } else {
            channelName = ""
        }

        var channelThumbnailURL: String? = nil
        if let channelThumbnailRenderer = renderer["channelThumbnailSupportedRenderers"] as? [String: Any],
           let channelThumbnailWithLink = channelThumbnailRenderer["channelThumbnailWithLinkRenderer"] as? [String: Any],
           let thumbnail = channelThumbnailWithLink["thumbnail"] as? [String: Any],
           let thumbnails = thumbnail["thumbnails"] as? [[String: Any]],
           let firstThumb = thumbnails.first,
           let urlString = firstThumb["url"] as? String {
            channelThumbnailURL = urlString
        }

        let viewCount: String
        if let viewCountObj = renderer["viewCountText"] as? [String: Any],
           let text = viewCountObj["simpleText"] as? String {
            viewCount = text
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
            channelId: channelId,
            channelThumbnailURL: channelThumbnailURL,
            channelName: channelName,
            viewCount: viewCount,
            publishedText: publishedText
        )
    }

    private func copyVideoURL(_ result: SearchResult) {
        let url = "https://www.youtube.com/watch?v=\(result.id)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
    }

    private func addChannelToCategory(_ result: SearchResult, to targetFile: URL) {
        print("[DEBUG] addChannelToCategory called")
        print("[DEBUG] result.channelId: \(String(describing: result.channelId))")
        print("[DEBUG] result.channelName: \(result.channelName)")
        print("[DEBUG] result.channelThumbnailURL: \(String(describing: result.channelThumbnailURL))")
        print("[DEBUG] targetFile: \(targetFile.path)")

        guard let channelId = result.channelId else {
            print("[DEBUG] ERROR: channelId is nil, returning early")
            return
        }

        do {
            var subscriptions: [Subscription] = []
            if let data = try? Data(contentsOf: targetFile) {
                print("[DEBUG] Read \(data.count) bytes from file")
                if let decoded = try? JSONDecoder().decode([Subscription].self, from: data) {
                    subscriptions = decoded
                    print("[DEBUG] Decoded \(subscriptions.count) existing subscriptions")
                } else {
                    print("[DEBUG] ERROR: Failed to decode existing subscriptions")
                }
            } else {
                print("[DEBUG] No existing file or failed to read")
            }

            // Check if channel already exists
            if subscriptions.contains(where: { $0.id == channelId }) {
                print("[DEBUG] Channel already exists, returning early")
                return
            }

            // Create new subscription from search result
            let thumbnailURL = result.channelThumbnailURL ?? ""
            let newSubscription = Subscription(
                snippet: SubscriptionSnippet(
                    channelId: channelId,
                    title: result.channelName,
                    resourceId: ResourceId(channelId: channelId),
                    thumbnails: Thumbnails(default: ThumbnailInfo(url: thumbnailURL))
                )
            )
            print("[DEBUG] Created new subscription with id: \(newSubscription.id), thumbnailURL: \(thumbnailURL)")

            subscriptions.append(newSubscription)
            print("[DEBUG] Total subscriptions after append: \(subscriptions.count)")

            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(subscriptions)
            print("[DEBUG] Encoded data size: \(data.count) bytes")

            try data.write(to: targetFile)
            print("[DEBUG] Successfully wrote to file: \(targetFile.path)")
        } catch {
            print("[DEBUG] ERROR: Failed to add channel to category: \(error)")
        }
    }
}
