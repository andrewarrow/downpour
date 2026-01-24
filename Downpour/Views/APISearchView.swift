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

    // MARK: - Search Actions

    private func performSearch() {
        guard !searchText.isEmpty else { return }

        isSearching = true
        errorText = ""
        searchResults = []
        navigationStack = []
        currentTitle = ""

        Task {
            do {
                let results = try await YouTubeAPIService.searchYouTube(query: searchText)
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
