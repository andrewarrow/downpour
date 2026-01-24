//
//  YouTubeAPIService.swift
//  Downpour
//

import Foundation

struct YouTubeAPIService {
    private static let apiKey = "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"
    private static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"

    private static func makeClientContext() -> [String: Any] {
        return [
            "client": [
                "clientName": "WEB",
                "clientVersion": "2.20240101.00.00",
                "hl": "en",
                "gl": "US"
            ]
        ]
    }

    private static func makeRequest(url: URL, body: [String: Any]) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    static func searchYouTube(query: String, params: String? = nil) async throws -> [SearchResult] {
        let urlString = "https://www.youtube.com/youtubei/v1/search?key=\(apiKey)"

        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var body: [String: Any] = [
            "context": makeClientContext(),
            "query": query
        ]

        if let params = params {
            body["params"] = params
        }

        let request = try makeRequest(url: url, body: body)
        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }

        return YouTubeResponseParser.parseSearchResults(json: json)
    }

    static func getRelatedVideos(videoId: String, excludeChannelId: String?) async throws -> [SearchResult] {
        let urlString = "https://www.youtube.com/youtubei/v1/next?key=\(apiKey)"

        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var allResults: [SearchResult] = []
        var continuationToken: String? = nil
        let maxPages = 3

        let body: [String: Any] = [
            "context": makeClientContext(),
            "videoId": videoId
        ]

        let request = try makeRequest(url: url, body: body)

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

        let (results, token) = YouTubeResponseParser.parseRelatedVideosWithContinuation(json: json)
        allResults.append(contentsOf: results)
        continuationToken = token

        print("[DEBUG] First page: \(results.count) results, continuation: \(token != nil)")

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

        let diverseResults = YouTubeResponseParser.applyDiversityFilter(results: allResults, excludeChannelId: excludeChannelId)

        print("[DEBUG] After diversity filter: \(diverseResults.count) results (from \(allResults.count) total)")

        return diverseResults
    }

    static func fetchContinuation(token: String) async throws -> ([SearchResult], String?) {
        let urlString = "https://www.youtube.com/youtubei/v1/next?key=\(apiKey)"

        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let body: [String: Any] = [
            "context": makeClientContext(),
            "continuation": token
        ]

        let request = try makeRequest(url: url, body: body)
        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }

        return YouTubeResponseParser.parseContinuationResponse(json: json)
    }

    static func getChannelVideos(channelId: String) async throws -> [SearchResult] {
        let urlString = "https://www.youtube.com/youtubei/v1/browse?key=\(apiKey)"

        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let body: [String: Any] = [
            "context": makeClientContext(),
            "browseId": channelId
        ]

        let request = try makeRequest(url: url, body: body)

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

        return YouTubeResponseParser.parseChannelVideos(json: json)
    }

    static func getRelatedChannelVideos(channelId: String, channelName: String) async throws -> [SearchResult] {
        print("[DEBUG] getRelatedChannelVideos for channel: \(channelId) (\(channelName))")

        let channelVideos = try await getChannelVideos(channelId: channelId)
        print("[DEBUG] Got \(channelVideos.count) videos from channel")

        guard !channelVideos.isEmpty else {
            print("[DEBUG] No videos found on channel")
            return []
        }

        var allRelated: [SearchResult] = []

        let videosToCheck = Array(channelVideos.prefix(3))
        for video in videosToCheck {
            let related = try await getRelatedVideos(videoId: video.id, excludeChannelId: channelId)
            allRelated.append(contentsOf: related)
            print("[DEBUG] Got \(related.count) related videos from video: \(video.title)")
        }

        let diverse = YouTubeResponseParser.applyDiversityFilter(results: allRelated, excludeChannelId: channelId)
        print("[DEBUG] Final diverse results: \(diverse.count) videos from different channels")

        return diverse
    }
}
