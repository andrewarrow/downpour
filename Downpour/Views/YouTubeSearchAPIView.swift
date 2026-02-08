//
//  YouTubeSearchAPIView.swift
//  Downpour
//

import SwiftUI
import AppKit

// MARK: - Enums

enum V3SearchOrder: String, CaseIterable {
    case date
    case rating
    case relevance
    case title
    case viewCount

    var label: String {
        switch self {
        case .date: return "Upload Date"
        case .rating: return "Rating"
        case .relevance: return "Relevance"
        case .title: return "Title"
        case .viewCount: return "View Count"
        }
    }
}

enum V3SearchType: String, CaseIterable {
    case video
    case channel
    case playlist

    var label: String { rawValue.capitalized }
}

enum V3VideoDuration: String, CaseIterable {
    case any
    case short_
    case medium
    case long_

    var paramValue: String {
        switch self {
        case .any: return "any"
        case .short_: return "short"
        case .medium: return "medium"
        case .long_: return "long"
        }
    }

    var label: String {
        switch self {
        case .any: return "Any"
        case .short_: return "< 4 min"
        case .medium: return "4-20 min"
        case .long_: return "> 20 min"
        }
    }
}

enum V3VideoDefinition: String, CaseIterable {
    case any
    case high
    case standard

    var label: String {
        switch self {
        case .any: return "Any"
        case .high: return "HD"
        case .standard: return "SD"
        }
    }
}

enum V3VideoCaption: String, CaseIterable {
    case any
    case closedCaption
    case none

    var label: String {
        switch self {
        case .any: return "Any"
        case .closedCaption: return "Has Captions"
        case .none: return "No Captions"
        }
    }
}

enum V3VideoLicense: String, CaseIterable {
    case any
    case creativeCommon
    case youtube

    var label: String {
        switch self {
        case .any: return "Any"
        case .creativeCommon: return "Creative Commons"
        case .youtube: return "Standard"
        }
    }
}

enum V3EventType: String, CaseIterable {
    case none
    case completed
    case live
    case upcoming

    var label: String {
        switch self {
        case .none: return "Any"
        case .completed: return "Completed"
        case .live: return "Live"
        case .upcoming: return "Upcoming"
        }
    }
}

enum V3SafeSearch: String, CaseIterable {
    case moderate
    case none
    case strict

    var label: String { rawValue.capitalized }
}

// MARK: - Search Result Model

struct V3SearchResult: Identifiable {
    let id: String
    let kind: String // youtube#video, youtube#channel, youtube#playlist
    let raw: [String: Any]

    var title: String { nested("snippet.title") ?? id }
    var channelTitle: String { nested("snippet.channelTitle") ?? "" }
    var channelId: String { nested("snippet.channelId") ?? "" }
    var description: String { nested("snippet.description") ?? "" }
    var publishedAt: String { nested("snippet.publishedAt") ?? "" }
    var liveBroadcastContent: String { nested("snippet.liveBroadcastContent") ?? "" }
    var thumbnailURL: URL? {
        if let thumbs = (raw["snippet"] as? [String: Any])?["thumbnails"] as? [String: Any] {
            for key in ["high", "medium", "default"] {
                if let t = thumbs[key] as? [String: Any], let url = t["url"] as? String {
                    return URL(string: url)
                }
            }
        }
        return nil
    }

    var isVideo: Bool { kind == "youtube#video" }
    var isChannel: Bool { kind == "youtube#channel" }
    var isPlaylist: Bool { kind == "youtube#playlist" }

    var formattedPublishedAt: String {
        let iso = DateFormatter()
        iso.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        iso.timeZone = TimeZone(identifier: "UTC")
        guard let date = iso.date(from: publishedAt) else { return publishedAt }
        let display = DateFormatter()
        display.dateStyle = .medium
        display.timeStyle = .short
        return display.string(from: date)
    }

    var typeIcon: String {
        if isChannel { return "person.circle" }
        if isPlaylist { return "list.bullet.rectangle" }
        return "play.rectangle"
    }

    var typeLabel: String {
        if isChannel { return "Channel" }
        if isPlaylist { return "Playlist" }
        return "Video"
    }

    private func nested(_ keyPath: String) -> String? {
        let keys = keyPath.split(separator: ".").map(String.init)
        var current: Any = raw
        for key in keys {
            guard let dict = current as? [String: Any], let next = dict[key] else { return nil }
            current = next
        }
        if let s = current as? String { return s }
        if let n = current as? NSNumber { return n.stringValue }
        return nil
    }
}

// MARK: - Main View

struct YouTubeSearchAPIView: View {
    @Environment(\.openWindow) private var openWindow

    // Query
    @State private var query: String = ""

    // Sort & type
    @State private var order: V3SearchOrder = .relevance
    @State private var selectedTypes: Set<V3SearchType> = [.video]

    // Video filters
    @State private var videoDuration: V3VideoDuration = .any
    @State private var videoDefinition: V3VideoDefinition = .any
    @State private var videoCaption: V3VideoCaption = .any
    @State private var videoLicense: V3VideoLicense = .any
    @State private var videoEmbeddable: Bool = false
    @State private var videoSyndicated: Bool = false
    @State private var videoPaidProductPlacement: Bool = false

    // Channel / event
    @State private var channelId: String = ""
    @State private var eventType: V3EventType = .none

    // Region & language
    @State private var regionCode: RegionCode = .us
    @State private var relevanceLanguage: String = "en"
    @State private var safeSearch: V3SafeSearch = .moderate

    // Category & topic
    @State private var selectedCategoryId: String = ""
    @State private var topicId: String = ""

    // Date range
    @State private var usePublishedAfter: Bool = false
    @State private var publishedAfter: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var usePublishedBefore: Bool = false
    @State private var publishedBefore: Date = Date()

    // Pagination
    @State private var maxResults: Double = 25
    @State private var pageToken: String = ""

    // Results
    @State private var results: [V3SearchResult] = []
    @State private var isLoading = false
    @State private var errorText = ""
    @State private var nextPageToken: String?
    @State private var prevPageToken: String?
    @State private var totalResults: Int?

    // Raw JSON
    @State private var rawJSON: String = ""
    @State private var showRawJSON = false

    private var apiKey: String {
        Bundle.main.object(forInfoDictionaryKey: "DownpourYouTubeAPIKey") as? String ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            // Controls
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    // Row 1: Query & Order & Fetch
                    HStack(spacing: 12) {
                        TextField("Search query (supports - and | operators)", text: $query)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 14))
                            .onSubmit { performSearch() }

                        Picker("Order", selection: $order) {
                            ForEach(V3SearchOrder.allCases, id: \.self) { o in
                                Text(o.label).tag(o)
                            }
                        }
                        .frame(width: 140)

                        Button(action: performSearch) {
                            HStack(spacing: 4) {
                                Image(systemName: "magnifyingglass")
                                Text("Search")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isLoading || apiKey.isEmpty || query.trimmingCharacters(in: .whitespaces).isEmpty)
                        .keyboardShortcut(.return, modifiers: .command)
                    }

                    // Row 2: Type selection & video filters
                    HStack(spacing: 20) {
                        // Type toggles
                        HStack(spacing: 4) {
                            Text("Type:")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                            ForEach(V3SearchType.allCases, id: \.self) { type in
                                Toggle(type.label, isOn: Binding(
                                    get: { selectedTypes.contains(type) },
                                    set: { isOn in
                                        if isOn { selectedTypes.insert(type) }
                                        else if selectedTypes.count > 1 { selectedTypes.remove(type) }
                                    }
                                ))
                                .toggleStyle(.checkbox)
                                .font(.system(size: 11))
                            }
                        }

                        HStack(spacing: 4) {
                            Text("Duration:")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                            Picker("", selection: $videoDuration) {
                                ForEach(V3VideoDuration.allCases, id: \.self) { d in
                                    Text(d.label).tag(d)
                                }
                            }
                            .frame(width: 90)
                        }

                        HStack(spacing: 4) {
                            Text("Def:")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                            Picker("", selection: $videoDefinition) {
                                ForEach(V3VideoDefinition.allCases, id: \.self) { d in
                                    Text(d.label).tag(d)
                                }
                            }
                            .frame(width: 70)
                        }

                        HStack(spacing: 4) {
                            Text("Captions:")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                            Picker("", selection: $videoCaption) {
                                ForEach(V3VideoCaption.allCases, id: \.self) { c in
                                    Text(c.label).tag(c)
                                }
                            }
                            .frame(width: 110)
                        }

                        Spacer()
                    }

                    // Row 3: More video filters, license, event
                    HStack(spacing: 20) {
                        HStack(spacing: 4) {
                            Text("License:")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                            Picker("", selection: $videoLicense) {
                                ForEach(V3VideoLicense.allCases, id: \.self) { l in
                                    Text(l.label).tag(l)
                                }
                            }
                            .frame(width: 130)
                        }

                        HStack(spacing: 4) {
                            Text("Event:")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                            Picker("", selection: $eventType) {
                                ForEach(V3EventType.allCases, id: \.self) { e in
                                    Text(e.label).tag(e)
                                }
                            }
                            .frame(width: 100)
                        }

                        Toggle("Embeddable", isOn: $videoEmbeddable)
                            .toggleStyle(.checkbox)
                            .font(.system(size: 11))

                        Toggle("Syndicated", isOn: $videoSyndicated)
                            .toggleStyle(.checkbox)
                            .font(.system(size: 11))

                        Toggle("Paid Placement", isOn: $videoPaidProductPlacement)
                            .toggleStyle(.checkbox)
                            .font(.system(size: 11))

                        Spacer()
                    }

                    // Row 4: Region, language, safe search, category, channel
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Text("Region:")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                            Picker("", selection: $regionCode) {
                                ForEach(RegionCode.allCases, id: \.self) { r in
                                    Text(r.label).tag(r)
                                }
                            }
                            .frame(width: 120)
                        }

                        HStack(spacing: 4) {
                            Text("Lang:")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                            TextField("en", text: $relevanceLanguage)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 40)
                                .font(.system(size: 12, design: .monospaced))
                        }

                        HStack(spacing: 4) {
                            Text("Safe:")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                            Picker("", selection: $safeSearch) {
                                ForEach(V3SafeSearch.allCases, id: \.self) { s in
                                    Text(s.label).tag(s)
                                }
                            }
                            .frame(width: 90)
                        }

                        HStack(spacing: 4) {
                            Text("Category:")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                            Picker("", selection: $selectedCategoryId) {
                                ForEach(videoCategories) { cat in
                                    Text(cat.name).tag(cat.id)
                                }
                            }
                            .frame(width: 150)
                        }

                        HStack(spacing: 4) {
                            Text("Channel ID:")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                            TextField("(optional)", text: $channelId)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 140)
                                .font(.system(size: 11, design: .monospaced))
                        }

                        Spacer()
                    }

                    // Row 5: Date range, max results, pagination
                    HStack(spacing: 16) {
                        Toggle("After:", isOn: $usePublishedAfter)
                            .toggleStyle(.checkbox)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        if usePublishedAfter {
                            DatePicker("", selection: $publishedAfter, displayedComponents: [.date])
                                .labelsHidden()
                                .frame(width: 110)
                        }

                        Toggle("Before:", isOn: $usePublishedBefore)
                            .toggleStyle(.checkbox)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        if usePublishedBefore {
                            DatePicker("", selection: $publishedBefore, displayedComponents: [.date])
                                .labelsHidden()
                                .frame(width: 110)
                        }

                        HStack(spacing: 4) {
                            Text("Max:")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                            Slider(value: $maxResults, in: 1...50, step: 1)
                                .frame(width: 80)
                            Text("\(Int(maxResults))")
                                .font(.system(size: 12, design: .monospaced))
                                .frame(width: 24, alignment: .trailing)
                        }

                        if let prev = prevPageToken {
                            Button("Prev") {
                                pageToken = prev
                                performSearch()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        if let next = nextPageToken {
                            Button("Next") {
                                pageToken = next
                                performSearch()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        if let total = totalResults {
                            Text("\(total) total")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if apiKey.isEmpty {
                            Label("API key not set", systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                        } else {
                            Label("API key loaded", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .frame(maxHeight: 180)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Loading / Error
            if isLoading {
                ProgressView("Searching...")
                    .padding()
            }
            if !errorText.isEmpty {
                Text(errorText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.red)
                    .padding()
            }

            // Results
            if results.isEmpty && !isLoading && errorText.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("YouTube Data API v3 — search.list")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Enter a query, configure filters, then click Search")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 240))], spacing: 16) {
                        ForEach(results) { result in
                            V3SearchResultCard(result: result)
                                .contextMenu {
                                    if result.isVideo {
                                        Button("Copy Video URL") {
                                            copyToClipboard("https://www.youtube.com/watch?v=\(result.id)")
                                        }
                                    } else if result.isChannel {
                                        Button("Copy Channel URL") {
                                            copyToClipboard("https://www.youtube.com/channel/\(result.id)")
                                        }
                                    } else if result.isPlaylist {
                                        Button("Copy Playlist URL") {
                                            copyToClipboard("https://www.youtube.com/playlist?list=\(result.id)")
                                        }
                                    }
                                    Button("Copy ID") {
                                        copyToClipboard(result.id)
                                    }
                                    if !result.channelId.isEmpty {
                                        Button("Copy Channel ID") {
                                            copyToClipboard(result.channelId)
                                        }
                                        Button("Search this channel") {
                                            channelId = result.channelId
                                            performSearch()
                                        }
                                    }
                                    Divider()
                                    Button("View Raw JSON") {
                                        showRawJSONFor(result)
                                    }
                                    Divider()
                                    if result.isVideo {
                                        Button("Open in Browser") {
                                            if let url = URL(string: "https://www.youtube.com/watch?v=\(result.id)") {
                                                NSWorkspace.shared.open(url)
                                            }
                                        }
                                    } else if result.isChannel {
                                        Button("Open in Browser") {
                                            if let url = URL(string: "https://www.youtube.com/channel/\(result.id)") {
                                                NSWorkspace.shared.open(url)
                                            }
                                        }
                                    }
                                }
                                .onTapGesture {
                                    if result.isVideo {
                                        let sv = StreamingVideo(videoId: result.id, title: result.title)
                                        openWindow(value: sv)
                                    } else if result.isChannel {
                                        if let url = URL(string: "https://www.youtube.com/channel/\(result.id)") {
                                            NSWorkspace.shared.open(url)
                                        }
                                    } else if result.isPlaylist {
                                        if let url = URL(string: "https://www.youtube.com/playlist?list=\(result.id)") {
                                            NSWorkspace.shared.open(url)
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
        .sheet(isPresented: $showRawJSON) {
            VStack(spacing: 0) {
                HStack {
                    Text("Raw JSON Response")
                        .font(.headline)
                    Spacer()
                    Button("Copy") { copyToClipboard(rawJSON) }
                    Button("Close") { showRawJSON = false }
                }
                .padding()

                ScrollView {
                    Text(rawJSON)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
            .frame(minWidth: 600, minHeight: 500)
        }
    }

    // MARK: - API Call

    private func performSearch() {
        guard !apiKey.isEmpty else {
            errorText = "Set DOWNPOUR_YOUTUBE in Secrets.xcconfig"
            return
        }
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
        guard !trimmedQuery.isEmpty else {
            errorText = "Enter a search query"
            return
        }

        isLoading = true
        errorText = ""
        results = []
        nextPageToken = nil
        prevPageToken = nil
        totalResults = nil

        Task {
            do {
                var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/search")!
                var queryItems: [URLQueryItem] = [
                    URLQueryItem(name: "key", value: apiKey),
                    URLQueryItem(name: "part", value: "snippet"),
                    URLQueryItem(name: "q", value: trimmedQuery),
                    URLQueryItem(name: "order", value: order.rawValue),
                    URLQueryItem(name: "type", value: selectedTypes.map(\.rawValue).joined(separator: ",")),
                    URLQueryItem(name: "maxResults", value: String(Int(maxResults))),
                    URLQueryItem(name: "safeSearch", value: safeSearch.rawValue),
                ]

                // Video-specific filters (only apply when type includes video)
                let hasVideo = selectedTypes.contains(.video)

                if hasVideo && videoDuration != .any {
                    queryItems.append(URLQueryItem(name: "videoDuration", value: videoDuration.paramValue))
                }
                if hasVideo && videoDefinition != .any {
                    queryItems.append(URLQueryItem(name: "videoDefinition", value: videoDefinition.rawValue))
                }
                if hasVideo && videoCaption != .any {
                    queryItems.append(URLQueryItem(name: "videoCaption", value: videoCaption.rawValue))
                }
                if hasVideo && videoLicense != .any {
                    queryItems.append(URLQueryItem(name: "videoLicense", value: videoLicense.rawValue))
                }
                if hasVideo && videoEmbeddable {
                    queryItems.append(URLQueryItem(name: "videoEmbeddable", value: "true"))
                }
                if hasVideo && videoSyndicated {
                    queryItems.append(URLQueryItem(name: "videoSyndicated", value: "true"))
                }
                if hasVideo && videoPaidProductPlacement {
                    queryItems.append(URLQueryItem(name: "videoPaidProductPlacement", value: "true"))
                }
                if hasVideo && !selectedCategoryId.isEmpty {
                    queryItems.append(URLQueryItem(name: "videoCategoryId", value: selectedCategoryId))
                }

                // Event type
                if eventType != .none {
                    queryItems.append(URLQueryItem(name: "eventType", value: eventType.rawValue))
                }

                // Channel filter
                let trimmedChannel = channelId.trimmingCharacters(in: .whitespaces)
                if !trimmedChannel.isEmpty {
                    queryItems.append(URLQueryItem(name: "channelId", value: trimmedChannel))
                }

                // Region & language
                if regionCode != .none {
                    queryItems.append(URLQueryItem(name: "regionCode", value: regionCode.rawValue))
                }
                let trimmedLang = relevanceLanguage.trimmingCharacters(in: .whitespaces)
                if !trimmedLang.isEmpty {
                    queryItems.append(URLQueryItem(name: "relevanceLanguage", value: trimmedLang))
                }

                // Topic
                let trimmedTopic = topicId.trimmingCharacters(in: .whitespaces)
                if !trimmedTopic.isEmpty {
                    queryItems.append(URLQueryItem(name: "topicId", value: trimmedTopic))
                }

                // Date range
                if usePublishedAfter {
                    queryItems.append(URLQueryItem(name: "publishedAfter", value: iso8601(publishedAfter)))
                }
                if usePublishedBefore {
                    queryItems.append(URLQueryItem(name: "publishedBefore", value: iso8601(publishedBefore)))
                }

                // Pagination
                let trimmedToken = pageToken.trimmingCharacters(in: .whitespaces)
                if !trimmedToken.isEmpty {
                    queryItems.append(URLQueryItem(name: "pageToken", value: trimmedToken))
                }

                components.queryItems = queryItems

                guard let url = components.url else {
                    throw URLError(.badURL)
                }

                print("[DEBUG] YouTube search API v3 URL: \(url.absoluteString)")

                var request = URLRequest(url: url)
                request.httpMethod = "GET"

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }

                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw URLError(.cannotParseResponse)
                }

                if httpResponse.statusCode != 200 {
                    let errorMsg = (json["error"] as? [String: Any])?["message"] as? String
                        ?? "HTTP \(httpResponse.statusCode)"
                    throw NSError(domain: "YouTubeAPI", code: httpResponse.statusCode,
                                  userInfo: [NSLocalizedDescriptionKey: errorMsg])
                }

                let nextToken = json["nextPageToken"] as? String
                let prevToken = json["prevPageToken"] as? String
                let pageInfo = json["pageInfo"] as? [String: Any]
                let total = pageInfo?["totalResults"] as? Int

                let items = json["items"] as? [[String: Any]] ?? []
                let searchResults = items.compactMap { item -> V3SearchResult? in
                    guard let idObj = item["id"] as? [String: Any],
                          let kind = idObj["kind"] as? String else { return nil }

                    let resourceId: String
                    if let vid = idObj["videoId"] as? String {
                        resourceId = vid
                    } else if let cid = idObj["channelId"] as? String {
                        resourceId = cid
                    } else if let pid = idObj["playlistId"] as? String {
                        resourceId = pid
                    } else {
                        return nil
                    }

                    return V3SearchResult(id: resourceId, kind: kind, raw: item)
                }

                await MainActor.run {
                    results = searchResults
                    nextPageToken = nextToken
                    prevPageToken = prevToken
                    totalResults = total
                    isLoading = false
                    pageToken = ""
                }
            } catch {
                await MainActor.run {
                    errorText = "Error: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }

    // MARK: - Utilities

    private func iso8601(_ date: Date) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]
        return fmt.string(from: date)
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func showRawJSONFor(_ result: V3SearchResult) {
        if let data = try? JSONSerialization.data(withJSONObject: result.raw, options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: data, encoding: .utf8) {
            rawJSON = str
        } else {
            rawJSON = "Failed to serialize JSON"
        }
        showRawJSON = true
    }
}

// MARK: - Search Result Card

struct V3SearchResultCard: View {
    let result: V3SearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: result.thumbnailURL) { image in
                image
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fit)
                    .cornerRadius(6)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(16/9, contentMode: .fit)
                    .cornerRadius(6)
            }

            Text(result.title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(2)

            HStack(spacing: 6) {
                Label(result.typeLabel, systemImage: result.typeIcon)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .cornerRadius(4)

                if !result.channelTitle.isEmpty {
                    Text(result.channelTitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            if !result.publishedAt.isEmpty {
                Text(result.formattedPublishedAt)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            if result.liveBroadcastContent != "none" && !result.liveBroadcastContent.isEmpty {
                Label(result.liveBroadcastContent.capitalized, systemImage: "dot.radiowaves.left.and.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.red)
            }

            if !result.description.isEmpty {
                Text(result.description)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
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
