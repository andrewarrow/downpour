//
//  SearchResult.swift
//  Downpour
//

import Foundation

struct SearchResult: Identifiable, Codable {
    let id: String
    let title: String
    let thumbnailURL: URL?
    let channelId: String?
    let channelThumbnailURL: String?
    let channelName: String
    let viewCount: String
    let publishedText: String?

    /// Converts relative time text (e.g., "1 day ago", "3 weeks ago") to approximate seconds ago for sorting
    var approximateSecondsAgo: Int {
        guard let text = publishedText?.lowercased() else { return Int.max }

        let components = text.components(separatedBy: " ")
        guard components.count >= 2, let value = Int(components[0]) else {
            // Handle "Streamed X ago" format
            if text.contains("streamed") {
                let filtered = text.replacingOccurrences(of: "streamed ", with: "")
                let parts = filtered.components(separatedBy: " ")
                guard parts.count >= 2, let val = Int(parts[0]) else { return Int.max }
                return calculateSeconds(value: val, unit: parts[1])
            }
            return Int.max
        }

        return calculateSeconds(value: value, unit: components[1])
    }

    private func calculateSeconds(value: Int, unit: String) -> Int {
        if unit.hasPrefix("second") { return value }
        if unit.hasPrefix("minute") { return value * 60 }
        if unit.hasPrefix("hour") { return value * 3600 }
        if unit.hasPrefix("day") { return value * 86400 }
        if unit.hasPrefix("week") { return value * 604800 }
        if unit.hasPrefix("month") { return value * 2592000 }
        if unit.hasPrefix("year") { return value * 31536000 }
        return Int.max
    }
}
