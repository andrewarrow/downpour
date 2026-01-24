//
//  APISearchView.swift
//  Downpour
//

import SwiftUI
import AppKit

enum SearchSort: Int, CaseIterable {
    case relevance = 0
    case uploadDate = 1
    case viewCount = 2
    case rating = 3

    var label: String {
        switch self {
        case .relevance: return "Relevance"
        case .uploadDate: return "Upload Date"
        case .viewCount: return "View Count"
        case .rating: return "Rating"
        }
    }
}

enum SearchUploadDate: Int, CaseIterable {
    case anyTime = 0
    case lastHour = 1
    case today = 2
    case thisWeek = 3
    case thisMonth = 4
    case thisYear = 5

    var label: String {
        switch self {
        case .anyTime: return "Any Time"
        case .lastHour: return "Last Hour"
        case .today: return "Today"
        case .thisWeek: return "This Week"
        case .thisMonth: return "This Month"
        case .thisYear: return "This Year"
        }
    }
}

enum SearchDuration: Int, CaseIterable {
    case any = 0
    case short = 1
    case medium = 2
    case long = 3

    var label: String {
        switch self {
        case .any: return "Any"
        case .short: return "< 4 min"
        case .medium: return "4-20 min"
        case .long: return "> 20 min"
        }
    }
}

struct APISearchView: View {
    let allSubsFiles: [URL]

    @State private var searchText: String = ""
    @State private var searchResults: [SearchResult] = []
    @State private var isSearching: Bool = false
    @State private var errorText: String = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var navigationStack: [(title: String, results: [SearchResult])] = []
    @State private var currentTitle: String = ""
    @State private var sortBy: SearchSort = .relevance
    @State private var uploadDate: SearchUploadDate = .anyTime
    @State private var duration: SearchDuration = .any
    @State private var didLoadState = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField("Search YouTube and press Enter", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18))
                    .disabled(isSearching)
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        performSearch()
                    }

                Picker("", selection: $sortBy) {
                    ForEach(SearchSort.allCases, id: \.self) { sort in
                        Text(sort.label).tag(sort)
                    }
                }
                .frame(width: 110)

                Picker("", selection: $uploadDate) {
                    ForEach(SearchUploadDate.allCases, id: \.self) { date in
                        Text(date.label).tag(date)
                    }
                }
                .frame(width: 100)

                Picker("", selection: $duration) {
                    ForEach(SearchDuration.allCases, id: \.self) { dur in
                        Text(dur.label).tag(dur)
                    }
                }
                .frame(width: 90)

                Button(action: doRandomSearch) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
                .disabled(isSearching)
                .help("Random Search")
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

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
            if !didLoadState {
                let state = StateManager.load()
                if let sort = state.searchSortBy, let s = SearchSort(rawValue: sort) {
                    sortBy = s
                }
                if let date = state.searchUploadDate, let d = SearchUploadDate(rawValue: date) {
                    uploadDate = d
                }
                if let dur = state.searchDuration, let d = SearchDuration(rawValue: dur) {
                    duration = d
                }
                didLoadState = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
        .onChange(of: sortBy) { _, _ in saveFilters() }
        .onChange(of: uploadDate) { _, _ in saveFilters() }
        .onChange(of: duration) { _, _ in saveFilters() }
    }

    private func saveFilters() {
        StateManager.saveSearchFilters(sortBy: sortBy.rawValue, uploadDate: uploadDate.rawValue, duration: duration.rawValue)
    }

    // MARK: - Search Actions

    private func buildSearchParams() -> String? {
        var hasFilters = false
        var filterBytes: [UInt8] = []

        // Upload date filter (field 1 in filters submessage)
        if uploadDate != .anyTime {
            filterBytes.append(0x08) // field 1, wire type 0
            filterBytes.append(UInt8(uploadDate.rawValue))
            hasFilters = true
        }

        // Type filter (field 2 in filters submessage) - always video (1)
        filterBytes.append(0x10) // field 2, wire type 0
        filterBytes.append(0x01) // video type
        hasFilters = true

        // Duration filter (field 3 in filters submessage)
        if duration != .any {
            filterBytes.append(0x18) // field 3, wire type 0
            filterBytes.append(UInt8(duration.rawValue))
            hasFilters = true
        }

        var params: [UInt8] = []

        // Sort (field 1 in outer message)
        // YouTube sort values: 1=rating, 2=uploadDate, 3=viewCount
        if sortBy != .relevance {
            params.append(0x08) // field 1, wire type 0
            let youtubeSortValue: UInt8
            switch sortBy {
            case .relevance: youtubeSortValue = 0
            case .uploadDate: youtubeSortValue = 2
            case .viewCount: youtubeSortValue = 3
            case .rating: youtubeSortValue = 1
            }
            params.append(youtubeSortValue)
            print("[DEBUG] Sort filter: \(sortBy.label) -> YouTube value: \(youtubeSortValue)")
        }

        // Filters submessage (field 2 in outer message)
        if hasFilters {
            params.append(0x12) // field 2, wire type 2 (length-delimited)
            params.append(UInt8(filterBytes.count))
            params.append(contentsOf: filterBytes)
        }

        print("[DEBUG] buildSearchParams - sortBy: \(sortBy.label), uploadDate: \(uploadDate.label), duration: \(duration.label)")
        print("[DEBUG] Filter bytes: \(filterBytes.map { String(format: "%02x", $0) }.joined(separator: " "))")
        print("[DEBUG] Full params bytes: \(params.map { String(format: "%02x", $0) }.joined(separator: " "))")

        guard !params.isEmpty else { return nil }
        return Data(params).base64EncodedString()
    }

    private func performSearch() {
        guard !searchText.isEmpty else { return }

        isSearching = true
        errorText = ""
        searchResults = []
        navigationStack = []
        currentTitle = ""

        let params = buildSearchParams()

        Task {
            do {
                let results = try await YouTubeAPIService.searchYouTube(query: searchText, params: params)
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

    private func fetchRelatedToVideo(_ result: SearchResult) {
        isSearching = true
        errorText = ""

        Task {
            do {
                let related = try await YouTubeAPIService.getRelatedVideos(videoId: result.id, excludeChannelId: result.channelId)
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
                let relatedChannelVideos = try await YouTubeAPIService.getRelatedChannelVideos(channelId: channelId, channelName: result.channelName)
                await MainActor.run {
                    navigationStack.append((title: currentTitle, results: searchResults))
                    currentTitle = "Channels like: \(result.channelName)"
                    searchResults = relatedChannelVideos
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    errorText = "Failed to fetch related channels: \(error.localizedDescription)"
                    isSearching = false
                }
            }
        }
    }

    // MARK: - Navigation

    private func goBack() {
        guard !navigationStack.isEmpty else { return }
        let previous = navigationStack.removeLast()
        searchResults = previous.results
        currentTitle = navigationStack.last?.title ?? ""
    }

    // MARK: - Utilities

    private func copyVideoURL(_ result: SearchResult) {
        let url = "https://www.youtube.com/watch?v=\(result.id)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
    }

    private func doRandomSearch() {
        guard let wordsURL = Bundle.main.url(forResource: "words", withExtension: "txt"),
              let wordsText = try? String(contentsOf: wordsURL, encoding: .utf8) else {
            return
        }

        let words = wordsText.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard !words.isEmpty else { return }

        let randomWord = words.randomElement()!
        searchText = randomWord
        performSearch()
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
