//
//  YouTubeAPIView.swift
//  Downpour
//

import SwiftUI
import AppKit

// MARK: - Enums for Picker Options

enum VideoListFilter: String, CaseIterable {
    case chart = "Chart"
    case id = "Video IDs"
}

enum VideoPart: String, CaseIterable, Identifiable {
    case snippet
    case contentDetails
    case statistics
    case status
    case player
    case topicDetails
    case recordingDetails
    case liveStreamingDetails
    case localizations
    case paidProductPlacementDetails
    case id

    var id: String { rawValue }

    var label: String {
        switch self {
        case .snippet: return "snippet"
        case .contentDetails: return "contentDetails"
        case .statistics: return "statistics"
        case .status: return "status"
        case .player: return "player"
        case .topicDetails: return "topicDetails"
        case .recordingDetails: return "recordingDetails"
        case .liveStreamingDetails: return "liveStreamingDetails"
        case .localizations: return "localizations"
        case .paidProductPlacementDetails: return "paidProductPlacement"
        case .id: return "id"
        }
    }
}

enum RegionCode: String, CaseIterable {
    case none = ""
    case us = "US"
    case gb = "GB"
    case ca = "CA"
    case au = "AU"
    case de = "DE"
    case fr = "FR"
    case jp = "JP"
    case kr = "KR"
    case br = "BR"
    case `in` = "IN"
    case mx = "MX"
    case ru = "RU"
    case es = "ES"
    case it = "IT"
    case nl = "NL"
    case se = "SE"
    case no = "NO"
    case dk = "DK"
    case fi = "FI"
    case pl = "PL"
    case ar = "AR"
    case za = "ZA"
    case ng = "NG"
    case eg = "EG"
    case tw = "TW"
    case hk = "HK"
    case sg = "SG"
    case ph = "PH"
    case id_ = "ID"
    case th = "TH"
    case vn = "VN"

    var label: String {
        switch self {
        case .none: return "Any"
        case .us: return "US"
        case .gb: return "UK"
        case .ca: return "Canada"
        case .au: return "Australia"
        case .de: return "Germany"
        case .fr: return "France"
        case .jp: return "Japan"
        case .kr: return "South Korea"
        case .br: return "Brazil"
        case .in: return "India"
        case .mx: return "Mexico"
        case .ru: return "Russia"
        case .es: return "Spain"
        case .it: return "Italy"
        case .nl: return "Netherlands"
        case .se: return "Sweden"
        case .no: return "Norway"
        case .dk: return "Denmark"
        case .fi: return "Finland"
        case .pl: return "Poland"
        case .ar: return "Argentina"
        case .za: return "South Africa"
        case .ng: return "Nigeria"
        case .eg: return "Egypt"
        case .tw: return "Taiwan"
        case .hk: return "Hong Kong"
        case .sg: return "Singapore"
        case .ph: return "Philippines"
        case .id_: return "Indonesia"
        case .th: return "Thailand"
        case .vn: return "Vietnam"
        }
    }
}

struct VideoCategory: Identifiable {
    let id: String
    let name: String
}

let videoCategories: [VideoCategory] = [
    VideoCategory(id: "", name: "Any"),
    VideoCategory(id: "1", name: "Film & Animation"),
    VideoCategory(id: "2", name: "Autos & Vehicles"),
    VideoCategory(id: "10", name: "Music"),
    VideoCategory(id: "15", name: "Pets & Animals"),
    VideoCategory(id: "17", name: "Sports"),
    VideoCategory(id: "18", name: "Short Movies"),
    VideoCategory(id: "19", name: "Travel & Events"),
    VideoCategory(id: "20", name: "Gaming"),
    VideoCategory(id: "21", name: "Videoblogging"),
    VideoCategory(id: "22", name: "People & Blogs"),
    VideoCategory(id: "23", name: "Comedy"),
    VideoCategory(id: "24", name: "Entertainment"),
    VideoCategory(id: "25", name: "News & Politics"),
    VideoCategory(id: "26", name: "Howto & Style"),
    VideoCategory(id: "27", name: "Education"),
    VideoCategory(id: "28", name: "Science & Technology"),
    VideoCategory(id: "29", name: "Nonprofits & Activism"),
    VideoCategory(id: "30", name: "Movies"),
    VideoCategory(id: "31", name: "Anime/Animation"),
    VideoCategory(id: "32", name: "Action/Adventure"),
    VideoCategory(id: "33", name: "Classics"),
    VideoCategory(id: "34", name: "Comedy (Film)"),
    VideoCategory(id: "35", name: "Documentary"),
    VideoCategory(id: "36", name: "Drama"),
    VideoCategory(id: "37", name: "Family"),
    VideoCategory(id: "38", name: "Foreign"),
    VideoCategory(id: "39", name: "Horror"),
    VideoCategory(id: "40", name: "Sci-Fi/Fantasy"),
    VideoCategory(id: "41", name: "Thriller"),
    VideoCategory(id: "42", name: "Shorts"),
    VideoCategory(id: "43", name: "Shows"),
    VideoCategory(id: "44", name: "Trailers"),
]

// MARK: - Video Result Model

struct YouTubeVideoResult: Identifiable {
    let id: String
    let raw: [String: Any]

    // snippet
    var title: String { nested("snippet.title") ?? id }
    var channelTitle: String { nested("snippet.channelTitle") ?? "" }
    var channelId: String { nested("snippet.channelId") ?? "" }
    var description: String { nested("snippet.description") ?? "" }
    var publishedAt: String { nested("snippet.publishedAt") ?? "" }
    var categoryId: String { nested("snippet.categoryId") ?? "" }
    var tags: [String] { (raw["snippet"] as? [String: Any])?["tags"] as? [String] ?? [] }
    var defaultLanguage: String { nested("snippet.defaultLanguage") ?? "" }
    var defaultAudioLanguage: String { nested("snippet.defaultAudioLanguage") ?? "" }
    var liveBroadcastContent: String { nested("snippet.liveBroadcastContent") ?? "" }
    var thumbnailURL: URL? {
        if let thumbs = (raw["snippet"] as? [String: Any])?["thumbnails"] as? [String: Any] {
            for key in ["maxres", "high", "medium", "default"] {
                if let t = thumbs[key] as? [String: Any], let url = t["url"] as? String {
                    return URL(string: url)
                }
            }
        }
        return nil
    }

    // statistics
    var viewCount: String { nested("statistics.viewCount") ?? "" }
    var likeCount: String { nested("statistics.likeCount") ?? "" }
    var commentCount: String { nested("statistics.commentCount") ?? "" }

    // contentDetails
    var duration: String { nested("contentDetails.duration") ?? "" }
    var dimension: String { nested("contentDetails.dimension") ?? "" }
    var definition: String { nested("contentDetails.definition") ?? "" }
    var caption: String { nested("contentDetails.caption") ?? "" }
    var licensedContent: String {
        if let cd = raw["contentDetails"] as? [String: Any], let v = cd["licensedContent"] as? Bool {
            return v ? "Yes" : "No"
        }
        return ""
    }
    var projection: String { nested("contentDetails.projection") ?? "" }

    // status
    var uploadStatus: String { nested("status.uploadStatus") ?? "" }
    var privacyStatus: String { nested("status.privacyStatus") ?? "" }
    var license: String { nested("status.license") ?? "" }
    var embeddable: String {
        if let s = raw["status"] as? [String: Any], let v = s["embeddable"] as? Bool {
            return v ? "Yes" : "No"
        }
        return ""
    }
    var madeForKids: String {
        if let s = raw["status"] as? [String: Any], let v = s["madeForKids"] as? Bool {
            return v ? "Yes" : "No"
        }
        return ""
    }

    // topicDetails
    var topicCategories: [String] {
        (raw["topicDetails"] as? [String: Any])?["topicCategories"] as? [String] ?? []
    }

    // liveStreamingDetails
    var actualStartTime: String { nested("liveStreamingDetails.actualStartTime") ?? "" }
    var actualEndTime: String { nested("liveStreamingDetails.actualEndTime") ?? "" }
    var scheduledStartTime: String { nested("liveStreamingDetails.scheduledStartTime") ?? "" }
    var concurrentViewers: String { nested("liveStreamingDetails.concurrentViewers") ?? "" }

    // recordingDetails
    var recordingDate: String { nested("recordingDetails.recordingDate") ?? "" }

    var formattedDuration: String {
        let iso = duration
        guard iso.hasPrefix("PT") else { return iso }
        var remaining = String(iso.dropFirst(2))
        var parts: [String] = []

        for (suffix, label) in [("H", "h"), ("M", "m"), ("S", "s")] {
            if let range = remaining.range(of: suffix) {
                parts.append(String(remaining[remaining.startIndex..<range.lowerBound]) + label)
                remaining = String(remaining[range.upperBound...])
            }
        }
        return parts.joined(separator: " ")
    }

    var formattedViewCount: String {
        guard let n = Int(viewCount) else { return viewCount }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: n)) ?? viewCount
    }

    var formattedLikeCount: String {
        guard let n = Int(likeCount) else { return likeCount }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: n)) ?? likeCount
    }

    var formattedCommentCount: String {
        guard let n = Int(commentCount) else { return commentCount }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: n)) ?? commentCount
    }

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

struct YouTubeAPIView: View {
    @Environment(\.openWindow) private var openWindow

    // Filter type
    @State private var filterType: VideoListFilter = .chart
    @State private var videoIds: String = ""

    // Part selection
    @State private var selectedParts: Set<VideoPart> = [.snippet, .statistics, .contentDetails]

    // Optional params
    @State private var regionCode: RegionCode = .us
    @State private var selectedCategoryId: String = ""
    @State private var maxResults: Double = 10
    @State private var hlLanguage: String = "en"
    @State private var pageToken: String = ""

    // Results
    @State private var results: [YouTubeVideoResult] = []
    @State private var isLoading = false
    @State private var errorText = ""
    @State private var nextPageToken: String?
    @State private var prevPageToken: String?
    @State private var totalResults: Int?
    @State private var resultsPerPage: Int?

    // Detail sheet
    @State private var selectedVideo: YouTubeVideoResult?
    @State private var rawJSON: String = ""
    @State private var showRawJSON = false

    private var apiKey: String {
        Bundle.main.object(forInfoDictionaryKey: "DownpourYouTubeAPIKey") as? String ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            // Controls area
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    // Row 1: Filter type & main input
                    HStack(spacing: 12) {
                        Picker("Mode", selection: $filterType) {
                            ForEach(VideoListFilter.allCases, id: \.self) { f in
                                Text(f.rawValue).tag(f)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)

                        if filterType == .id {
                            TextField("Video IDs (comma-separated)", text: $videoIds)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 13, design: .monospaced))
                        } else {
                            Text("mostPopular")
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: fetchVideos) {
                            HStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                Text("Fetch")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isLoading || apiKey.isEmpty)
                        .keyboardShortcut(.return, modifiers: .command)
                    }

                    // Row 2: Part selection
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Parts:")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("All") {
                                selectedParts = Set(VideoPart.allCases)
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11))
                            .foregroundColor(.accentColor)

                            Button("Default") {
                                selectedParts = [.snippet, .statistics, .contentDetails]
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11))
                            .foregroundColor(.accentColor)
                        }

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 6), spacing: 4) {
                            ForEach(VideoPart.allCases) { part in
                                Toggle(part.label, isOn: Binding(
                                    get: { selectedParts.contains(part) },
                                    set: { isOn in
                                        if isOn { selectedParts.insert(part) }
                                        else { selectedParts.remove(part) }
                                    }
                                ))
                                .toggleStyle(.checkbox)
                                .font(.system(size: 11))
                            }
                        }
                    }

                    // Row 3: Region, Category, Max Results, Language
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
                            Text("Category:")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                            Picker("", selection: $selectedCategoryId) {
                                ForEach(videoCategories) { cat in
                                    Text(cat.name).tag(cat.id)
                                }
                            }
                            .frame(width: 160)
                        }

                        HStack(spacing: 4) {
                            Text("Max:")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                            Slider(value: $maxResults, in: 1...50, step: 1)
                                .frame(width: 100)
                            Text("\(Int(maxResults))")
                                .font(.system(size: 12, design: .monospaced))
                                .frame(width: 24, alignment: .trailing)
                        }

                        HStack(spacing: 4) {
                            Text("Lang:")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                            TextField("hl", text: $hlLanguage)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 50)
                                .font(.system(size: 12, design: .monospaced))
                        }

                        Spacer()
                    }

                    // Row 4: Pagination & API key status
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Text("Page Token:")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                            TextField("(auto or paste)", text: $pageToken)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 180)
                                .font(.system(size: 11, design: .monospaced))
                        }

                        if let prev = prevPageToken {
                            Button("Prev Page") {
                                pageToken = prev
                                fetchVideos()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        if let next = nextPageToken {
                            Button("Next Page") {
                                pageToken = next
                                fetchVideos()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        if let total = totalResults {
                            Text("\(total) total results")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if apiKey.isEmpty {
                            Label("DOWNPOUR_YOUTUBE env var not set", systemImage: "exclamationmark.triangle.fill")
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
                ProgressView("Fetching videos...")
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
                    Image(systemName: "video.badge.waveform")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("YouTube Data API v3 — videos.list")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Choose a mode, configure parts & filters, then click Fetch")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280))], spacing: 16) {
                        ForEach(results) { video in
                            VideoResultCard(video: video, selectedParts: selectedParts)
                                .contextMenu {
                                    Button("Copy Video URL") {
                                        copyToClipboard("https://www.youtube.com/watch?v=\(video.id)")
                                    }
                                    Button("Copy Video ID") {
                                        copyToClipboard(video.id)
                                    }
                                    if !video.channelId.isEmpty {
                                        Button("Copy Channel ID") {
                                            copyToClipboard(video.channelId)
                                        }
                                    }
                                    Divider()
                                    Button("View Raw JSON") {
                                        showRawJSONFor(video)
                                    }
                                    Divider()
                                    Button("Open in Browser") {
                                        if let url = URL(string: "https://www.youtube.com/watch?v=\(video.id)") {
                                            NSWorkspace.shared.open(url)
                                        }
                                    }
                                }
                                .onTapGesture {
                                    let sv = StreamingVideo(videoId: video.id, title: video.title)
                                    openWindow(value: sv)
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
                    Button("Copy") {
                        copyToClipboard(rawJSON)
                    }
                    Button("Close") {
                        showRawJSON = false
                    }
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

    private func fetchVideos() {
        guard !apiKey.isEmpty else {
            errorText = "Set DOWNPOUR_YOUTUBE environment variable with your YouTube Data API v3 key"
            return
        }

        guard !selectedParts.isEmpty else {
            errorText = "Select at least one part"
            return
        }

        if filterType == .id && videoIds.trimmingCharacters(in: .whitespaces).isEmpty {
            errorText = "Enter at least one video ID"
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
                var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/videos")!
                var queryItems: [URLQueryItem] = [
                    URLQueryItem(name: "key", value: apiKey),
                    URLQueryItem(name: "part", value: selectedParts.map(\.rawValue).joined(separator: ",")),
                ]

                switch filterType {
                case .chart:
                    queryItems.append(URLQueryItem(name: "chart", value: "mostPopular"))
                case .id:
                    let ids = videoIds
                        .components(separatedBy: CharacterSet(charactersIn: ", \n"))
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                        .joined(separator: ",")
                    queryItems.append(URLQueryItem(name: "id", value: ids))
                }

                if regionCode != .none {
                    queryItems.append(URLQueryItem(name: "regionCode", value: regionCode.rawValue))
                }
                if !selectedCategoryId.isEmpty {
                    queryItems.append(URLQueryItem(name: "videoCategoryId", value: selectedCategoryId))
                }
                if filterType == .chart {
                    queryItems.append(URLQueryItem(name: "maxResults", value: String(Int(maxResults))))
                }
                if !hlLanguage.trimmingCharacters(in: .whitespaces).isEmpty {
                    queryItems.append(URLQueryItem(name: "hl", value: hlLanguage.trimmingCharacters(in: .whitespaces)))
                }
                if !pageToken.trimmingCharacters(in: .whitespaces).isEmpty {
                    queryItems.append(URLQueryItem(name: "pageToken", value: pageToken.trimmingCharacters(in: .whitespaces)))
                }

                components.queryItems = queryItems

                guard let url = components.url else {
                    throw URLError(.badURL)
                }

                print("[DEBUG] YouTube API v3 URL: \(url.absoluteString)")

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
                let perPage = pageInfo?["resultsPerPage"] as? Int

                let items = json["items"] as? [[String: Any]] ?? []
                let videoResults = items.compactMap { item -> YouTubeVideoResult? in
                    guard let videoId = item["id"] as? String else { return nil }
                    return YouTubeVideoResult(id: videoId, raw: item)
                }

                await MainActor.run {
                    results = videoResults
                    nextPageToken = nextToken
                    prevPageToken = prevToken
                    totalResults = total
                    resultsPerPage = perPage
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

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func showRawJSONFor(_ video: YouTubeVideoResult) {
        if let data = try? JSONSerialization.data(withJSONObject: video.raw, options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: data, encoding: .utf8) {
            rawJSON = str
        } else {
            rawJSON = "Failed to serialize JSON"
        }
        showRawJSON = true
    }
}

// MARK: - Video Result Card

struct VideoResultCard: View {
    @Environment(\.openWindow) private var openWindow
    let video: YouTubeVideoResult
    let selectedParts: Set<VideoPart>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            if selectedParts.contains(.snippet) {
                AsyncImage(url: video.thumbnailURL) { image in
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

                Text(video.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)

                if !video.channelTitle.isEmpty {
                    Text(video.channelTitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                if !video.publishedAt.isEmpty {
                    Text(video.formattedPublishedAt)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            } else {
                Text(video.id)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
            }

            // Stats row
            if selectedParts.contains(.statistics) && !video.viewCount.isEmpty {
                HStack(spacing: 12) {
                    Label(video.formattedViewCount, systemImage: "eye")
                    if !video.likeCount.isEmpty {
                        Label(video.formattedLikeCount, systemImage: "hand.thumbsup")
                    }
                    if !video.commentCount.isEmpty {
                        Label(video.formattedCommentCount, systemImage: "bubble.right")
                    }
                }
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            }

            // Content details
            if selectedParts.contains(.contentDetails) && !video.duration.isEmpty {
                HStack(spacing: 8) {
                    Label(video.formattedDuration, systemImage: "clock")
                    if !video.definition.isEmpty {
                        Text(video.definition.uppercased())
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.15))
                            .cornerRadius(3)
                    }
                    if !video.dimension.isEmpty {
                        Text(video.dimension)
                    }
                    if video.caption == "true" {
                        Image(systemName: "captions.bubble")
                    }
                }
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            }

            // Status
            if selectedParts.contains(.status) && !video.privacyStatus.isEmpty {
                HStack(spacing: 8) {
                    Label(video.privacyStatus, systemImage: "lock")
                    if !video.license.isEmpty {
                        Label(video.license, systemImage: "doc.text")
                    }
                    if !video.embeddable.isEmpty {
                        Label("Embed: \(video.embeddable)", systemImage: "rectangle.on.rectangle")
                    }
                    if !video.madeForKids.isEmpty {
                        Label("Kids: \(video.madeForKids)", systemImage: "figure.child")
                    }
                }
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            }

            // Topic details
            if selectedParts.contains(.topicDetails) && !video.topicCategories.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Topics:")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    ForEach(video.topicCategories, id: \.self) { topic in
                        Text(topic.replacingOccurrences(of: "https://en.wikipedia.org/wiki/", with: "")
                            .replacingOccurrences(of: "_", with: " "))
                            .font(.system(size: 10))
                            .foregroundColor(.accentColor)
                    }
                }
            }

            // Live streaming
            if selectedParts.contains(.liveStreamingDetails) && !video.actualStartTime.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    if !video.scheduledStartTime.isEmpty {
                        Label("Scheduled: \(video.scheduledStartTime)", systemImage: "calendar")
                    }
                    if !video.actualStartTime.isEmpty {
                        Label("Started: \(video.actualStartTime)", systemImage: "play.circle")
                    }
                    if !video.actualEndTime.isEmpty {
                        Label("Ended: \(video.actualEndTime)", systemImage: "stop.circle")
                    }
                    if !video.concurrentViewers.isEmpty {
                        Label("Concurrent: \(video.concurrentViewers)", systemImage: "person.2")
                    }
                }
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            }

            // Recording details
            if selectedParts.contains(.recordingDetails) && !video.recordingDate.isEmpty {
                Label("Recorded: \(video.recordingDate)", systemImage: "calendar.badge.clock")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            // Snippet extras
            if selectedParts.contains(.snippet) {
                if !video.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(video.tags.prefix(8), id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 9))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.15))
                                    .cornerRadius(4)
                            }
                            if video.tags.count > 8 {
                                Text("+\(video.tags.count - 8)")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                if !video.description.isEmpty {
                    Text(video.description)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
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
