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
    @State private var navigationStack: [(title: String, results: [SearchResult])] = []
    @State private var currentTitle: String = ""

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

            if !navigationStack.isEmpty {
                HStack {
                    Button(action: goBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)

                    Spacer()

                    Text(currentTitle)
                        .font(.headline)

                    Spacer()

                    // Invisible balance element
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .opacity(0)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor))
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
                                Divider()
                                Button("Related to video") {
                                    fetchRelatedToVideo(result)
                                }
                                if result.channelId != nil {
                                    Button("Related to channel") {
                                        fetchRelatedToChannel(result)
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
        navigationStack = []
        currentTitle = ""

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

    private func goBack() {
        guard !navigationStack.isEmpty else { return }
        let previous = navigationStack.removeLast()
        searchResults = previous.results
        currentTitle = navigationStack.last?.title ?? ""
    }

    private func fetchRelatedToVideo(_ result: SearchResult) {
        isSearching = true
        errorText = ""

        Task {
            do {
                let related = try await getRelatedVideos(videoId: result.id, excludeChannelId: result.channelId)
                await MainActor.run {
                    navigationStack.append((title: currentTitle, results: searchResults))
                    currentTitle = "Related to: \(result.title)"
                    searchResults = related
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    errorText = "Failed to fetch related videos: \(error.localizedDescription)"
                    isSearching = false
                }
            }
        }
    }

    private func fetchRelatedToChannel(_ result: SearchResult) {
        guard let channelId = result.channelId else { return }

        isSearching = true
        errorText = ""

        Task {
            do {
                let channelVideos = try await getChannelVideos(channelId: channelId)
                await MainActor.run {
                    navigationStack.append((title: currentTitle, results: searchResults))
                    currentTitle = "Videos from: \(result.channelName)"
                    searchResults = channelVideos
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    errorText = "Failed to fetch channel videos: \(error.localizedDescription)"
                    isSearching = false
                }
            }
        }
    }

    private func getRelatedVideos(videoId: String, excludeChannelId: String?) async throws -> [SearchResult] {
        let apiKey = "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"
        let urlString = "https://www.youtube.com/youtubei/v1/next?key=\(apiKey)"

        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var allResults: [SearchResult] = []
        var continuationToken: String? = nil
        let maxPages = 3  // Fetch up to 3 pages for diversity

        // First request
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
            "videoId": videoId
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("[DEBUG] Related to video API call: \(urlString)")
        print("[DEBUG] Request body: \(body)")
        print("[DEBUG] Excluding channel ID: \(excludeChannelId ?? "none")")

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }

        if let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("[DEBUG] Related to video JSON response:\n\(jsonString)")
        }

        let (results, token) = parseRelatedVideosWithContinuation(json: json)
        allResults.append(contentsOf: results)
        continuationToken = token

        print("[DEBUG] First page: \(results.count) results, continuation: \(token != nil)")

        // Fetch continuation pages for more diversity
        var pagesFetched = 1
        while let token = continuationToken, pagesFetched < maxPages, allResults.count < 100 {
            print("[DEBUG] Fetching continuation page \(pagesFetched + 1)")

            let continuationResults = try await fetchContinuation(token: token)
            let (moreResults, nextToken) = continuationResults
            allResults.append(contentsOf: moreResults)
            continuationToken = nextToken
            pagesFetched += 1

            print("[DEBUG] Page \(pagesFetched): \(moreResults.count) results, total: \(allResults.count)")
        }

        // Apply diversity logic
        let diverseResults = applyDiversityFilter(results: allResults, excludeChannelId: excludeChannelId)

        print("[DEBUG] After diversity filter: \(diverseResults.count) results (from \(allResults.count) total)")

        return diverseResults
    }

    private func fetchContinuation(token: String) async throws -> ([SearchResult], String?) {
        let apiKey = "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"
        let urlString = "https://www.youtube.com/youtubei/v1/next?key=\(apiKey)"

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
            "continuation": token
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }

        return parseContinuationResponse(json: json)
    }

    private func parseContinuationResponse(json: [String: Any]) -> ([SearchResult], String?) {
        var results: [SearchResult] = []
        var continuationToken: String? = nil

        // Continuation responses have a different structure
        if let onResponseReceivedEndpoints = json["onResponseReceivedEndpoints"] as? [[String: Any]] {
            for endpoint in onResponseReceivedEndpoints {
                if let appendAction = endpoint["appendContinuationItemsAction"] as? [String: Any],
                   let items = appendAction["continuationItems"] as? [[String: Any]] {
                    for item in items {
                        if let lockupViewModel = item["lockupViewModel"] as? [String: Any] {
                            if let result = parseLockupViewModel(lockupViewModel) {
                                results.append(result)
                            }
                        } else if let compactVideoRenderer = item["compactVideoRenderer"] as? [String: Any] {
                            if let result = parseCompactVideoRenderer(compactVideoRenderer) {
                                results.append(result)
                            }
                        } else if let continuationItemRenderer = item["continuationItemRenderer"] as? [String: Any],
                                  let continuationEndpoint = continuationItemRenderer["continuationEndpoint"] as? [String: Any],
                                  let continuationCommand = continuationEndpoint["continuationCommand"] as? [String: Any],
                                  let token = continuationCommand["token"] as? String {
                            continuationToken = token
                        }
                    }
                }
            }
        }

        return (results, continuationToken)
    }

    private func applyDiversityFilter(results: [SearchResult], excludeChannelId: String?) -> [SearchResult] {
        // Step 1: Filter out videos from the excluded channel (same channel as source video)
        var filtered = results
        if let excludeId = excludeChannelId {
            filtered = results.filter { $0.channelId != excludeId }
            print("[DEBUG] After excluding source channel: \(filtered.count) results")
        }

        // Step 2: Group by channel and keep max 1 video per channel for diversity
        var byChannel: [String: [SearchResult]] = [:]
        var noChannelResults: [SearchResult] = []

        for result in filtered {
            if let channelId = result.channelId {
                if byChannel[channelId] == nil {
                    byChannel[channelId] = []
                }
                byChannel[channelId]?.append(result)
            } else {
                noChannelResults.append(result)
            }
        }

        print("[DEBUG] Found \(byChannel.count) unique channels")

        // Step 3: Sort channels by frequency (most videos = most relevant channel)
        // Take 1 video per channel, ranked by channel frequency
        let sortedChannels = byChannel.sorted { $0.value.count > $1.value.count }

        var diverseResults: [SearchResult] = []
        for (_, videos) in sortedChannels {
            if let firstVideo = videos.first {
                diverseResults.append(firstVideo)
            }
        }

        // Add results without channel ID at the end
        diverseResults.append(contentsOf: noChannelResults)

        // Limit to reasonable number
        return Array(diverseResults.prefix(30))
    }

    private func parseRelatedVideosWithContinuation(json: [String: Any]) -> ([SearchResult], String?) {
        var results: [SearchResult] = []
        var continuationToken: String? = nil

        // Navigate to secondary results
        guard let contents = json["contents"] as? [String: Any],
              let twoColumnWatchNextResults = contents["twoColumnWatchNextResults"] as? [String: Any],
              let secondaryResults = twoColumnWatchNextResults["secondaryResults"] as? [String: Any],
              let secondaryResultsRenderer = secondaryResults["secondaryResults"] as? [String: Any],
              let resultsList = secondaryResultsRenderer["results"] as? [[String: Any]] else {
            print("[DEBUG] parseRelatedVideos: Failed to navigate to results list")
            return (results, nil)
        }

        print("[DEBUG] parseRelatedVideos: Found \(resultsList.count) items in results list")

        for item in resultsList {
            // Try new lockupViewModel format first
            if let lockupViewModel = item["lockupViewModel"] as? [String: Any] {
                if let result = parseLockupViewModel(lockupViewModel) {
                    results.append(result)
                }
            }
            // Fall back to old compactVideoRenderer format
            else if let compactVideoRenderer = item["compactVideoRenderer"] as? [String: Any] {
                if let result = parseCompactVideoRenderer(compactVideoRenderer) {
                    results.append(result)
                }
            }
            // Check for continuation token
            else if let continuationItemRenderer = item["continuationItemRenderer"] as? [String: Any],
                    let continuationEndpoint = continuationItemRenderer["continuationEndpoint"] as? [String: Any],
                    let continuationCommand = continuationEndpoint["continuationCommand"] as? [String: Any],
                    let token = continuationCommand["token"] as? String {
                continuationToken = token
            }
        }

        print("[DEBUG] parseRelatedVideos: Parsed \(results.count) videos, continuation: \(continuationToken != nil)")
        return (results, continuationToken)
    }

    private func parseLockupViewModel(_ viewModel: [String: Any]) -> SearchResult? {
        // Get video ID from contentId
        guard let videoId = viewModel["contentId"] as? String else {
            print("[DEBUG] parseLockupViewModel: No contentId found")
            return nil
        }

        // Get metadata
        guard let metadata = viewModel["metadata"] as? [String: Any],
              let lockupMetadataViewModel = metadata["lockupMetadataViewModel"] as? [String: Any] else {
            print("[DEBUG] parseLockupViewModel: No lockupMetadataViewModel found")
            return nil
        }

        // Get title
        let title: String
        if let titleObj = lockupMetadataViewModel["title"] as? [String: Any],
           let content = titleObj["content"] as? String {
            title = content
        } else {
            title = "Unknown"
        }

        // Get channel name and other metadata
        var channelName = ""
        var viewCount = ""
        var channelId: String? = nil

        if let metadataContent = lockupMetadataViewModel["metadata"] as? [String: Any],
           let contentMetadataViewModel = metadataContent["contentMetadataViewModel"] as? [String: Any],
           let metadataRows = contentMetadataViewModel["metadataRows"] as? [[String: Any]] {

            // First row usually has channel name
            if let firstRow = metadataRows.first,
               let metadataParts = firstRow["metadataParts"] as? [[String: Any]],
               let firstPart = metadataParts.first,
               let text = firstPart["text"] as? [String: Any],
               let content = text["content"] as? String {
                channelName = content
            }

            // Second row usually has view count and time
            if metadataRows.count > 1,
               let secondRow = metadataRows[1] as? [String: Any],
               let metadataParts = secondRow["metadataParts"] as? [[String: Any]],
               let firstPart = metadataParts.first,
               let text = firstPart["text"] as? [String: Any],
               let content = text["content"] as? String {
                viewCount = content
            }
        }

        // Get channel ID from avatar navigation endpoint
        if let image = lockupMetadataViewModel["image"] as? [String: Any],
           let decoratedAvatarViewModel = image["decoratedAvatarViewModel"] as? [String: Any],
           let rendererContext = decoratedAvatarViewModel["rendererContext"] as? [String: Any],
           let commandContext = rendererContext["commandContext"] as? [String: Any],
           let onTap = commandContext["onTap"] as? [String: Any],
           let innertubeCommand = onTap["innertubeCommand"] as? [String: Any],
           let browseEndpoint = innertubeCommand["browseEndpoint"] as? [String: Any],
           let browseId = browseEndpoint["browseId"] as? String {
            channelId = browseId
        }

        // Get thumbnail URL
        var thumbnailURL: URL? = nil
        if let contentImage = viewModel["contentImage"] as? [String: Any],
           let thumbnailViewModel = contentImage["thumbnailViewModel"] as? [String: Any],
           let imageObj = thumbnailViewModel["image"] as? [String: Any],
           let sources = imageObj["sources"] as? [[String: Any]],
           let lastSource = sources.last,
           let urlString = lastSource["url"] as? String {
            thumbnailURL = URL(string: urlString)
        }

        return SearchResult(
            id: videoId,
            title: title,
            thumbnailURL: thumbnailURL,
            channelId: channelId,
            channelThumbnailURL: nil,
            channelName: channelName,
            viewCount: viewCount,
            publishedText: nil
        )
    }

    private func parseCompactVideoRenderer(_ renderer: [String: Any]) -> SearchResult? {
        guard let videoId = renderer["videoId"] as? String else {
            return nil
        }

        let title: String
        if let titleObj = renderer["title"] as? [String: Any],
           let text = titleObj["simpleText"] as? String {
            title = text
        } else if let titleObj = renderer["title"] as? [String: Any],
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
        if let channelObj = renderer["longBylineText"] as? [String: Any],
           let runs = channelObj["runs"] as? [[String: Any]],
           let firstRun = runs.first,
           let text = firstRun["text"] as? String {
            channelName = text
            if let navEndpoint = firstRun["navigationEndpoint"] as? [String: Any],
               let browseEndpoint = navEndpoint["browseEndpoint"] as? [String: Any],
               let browseId = browseEndpoint["browseId"] as? String {
                channelId = browseId
            }
        } else if let channelObj = renderer["shortBylineText"] as? [String: Any],
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
        if let channelThumbnail = renderer["channelThumbnail"] as? [String: Any],
           let thumbnails = channelThumbnail["thumbnails"] as? [[String: Any]],
           let firstThumb = thumbnails.first,
           let urlString = firstThumb["url"] as? String {
            channelThumbnailURL = urlString
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
            channelId: channelId,
            channelThumbnailURL: channelThumbnailURL,
            channelName: channelName,
            viewCount: viewCount,
            publishedText: publishedText
        )
    }

    private func getChannelVideos(channelId: String) async throws -> [SearchResult] {
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
            "browseId": channelId
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("[DEBUG] Related to channel API call: \(urlString)")
        print("[DEBUG] Request body: \(body)")

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }

        if let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("[DEBUG] Related to channel JSON response:\n\(jsonString)")
        }

        return parseChannelVideos(json: json)
    }

    private func parseChannelVideos(json: [String: Any]) -> [SearchResult] {
        var results: [SearchResult] = []

        // Try to find videos in the channel home page
        guard let contents = json["contents"] as? [String: Any],
              let twoColumnBrowseResultsRenderer = contents["twoColumnBrowseResultsRenderer"] as? [String: Any],
              let tabs = twoColumnBrowseResultsRenderer["tabs"] as? [[String: Any]] else {
            return results
        }

        // Extract channel name from header
        var defaultChannelName = ""
        var defaultChannelId: String? = nil
        if let header = json["header"] as? [String: Any],
           let c4Header = header["c4TabbedHeaderRenderer"] as? [String: Any],
           let title = c4Header["title"] as? String {
            defaultChannelName = title
            defaultChannelId = c4Header["channelId"] as? String
        }

        for tab in tabs {
            guard let tabRenderer = tab["tabRenderer"] as? [String: Any],
                  let tabContent = tabRenderer["content"] as? [String: Any] else {
                continue
            }

            // Check sectionListRenderer for shelves
            if let sectionListRenderer = tabContent["sectionListRenderer"] as? [String: Any],
               let sectionContents = sectionListRenderer["contents"] as? [[String: Any]] {
                for section in sectionContents {
                    if let itemSectionRenderer = section["itemSectionRenderer"] as? [String: Any],
                       let items = itemSectionRenderer["contents"] as? [[String: Any]] {
                        for item in items {
                            // Check for shelfRenderer containing videos
                            if let shelfRenderer = item["shelfRenderer"] as? [String: Any],
                               let shelfContent = shelfRenderer["content"] as? [String: Any] {
                                if let horizontalListRenderer = shelfContent["horizontalListRenderer"] as? [String: Any],
                                   let shelfItems = horizontalListRenderer["items"] as? [[String: Any]] {
                                    for shelfItem in shelfItems {
                                        if let gridVideoRenderer = shelfItem["gridVideoRenderer"] as? [String: Any] {
                                            if let result = parseGridVideoRenderer(gridVideoRenderer, channelName: defaultChannelName, channelId: defaultChannelId) {
                                                results.append(result)
                                            }
                                        }
                                    }
                                }
                            }
                            // Also check for richItemRenderer in rich grid
                            if let richItemRenderer = item["richItemRenderer"] as? [String: Any],
                               let richContent = richItemRenderer["content"] as? [String: Any],
                               let videoRenderer = richContent["videoRenderer"] as? [String: Any] {
                                if let result = parseVideoRenderer(videoRenderer) {
                                    results.append(result)
                                }
                            }
                        }
                    }
                }
            }

            // Check richGridRenderer for videos tab
            if let richGridRenderer = tabContent["richGridRenderer"] as? [String: Any],
               let gridContents = richGridRenderer["contents"] as? [[String: Any]] {
                for gridItem in gridContents {
                    if let richItemRenderer = gridItem["richItemRenderer"] as? [String: Any],
                       let content = richItemRenderer["content"] as? [String: Any],
                       let videoRenderer = content["videoRenderer"] as? [String: Any] {
                        if let result = parseVideoRenderer(videoRenderer) {
                            results.append(result)
                        }
                    }
                }
            }
        }

        return results
    }

    private func parseGridVideoRenderer(_ renderer: [String: Any], channelName: String, channelId: String?) -> SearchResult? {
        guard let videoId = renderer["videoId"] as? String else {
            return nil
        }

        let title: String
        if let titleObj = renderer["title"] as? [String: Any],
           let runs = titleObj["runs"] as? [[String: Any]],
           let firstRun = runs.first,
           let text = firstRun["text"] as? String {
            title = text
        } else if let titleObj = renderer["title"] as? [String: Any],
                  let text = titleObj["simpleText"] as? String {
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
            channelId: channelId,
            channelThumbnailURL: nil,
            channelName: channelName,
            viewCount: viewCount,
            publishedText: publishedText
        )
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
