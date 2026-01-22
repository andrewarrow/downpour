//
//  SearchResult.swift
//  Downpour
//

import Foundation

struct SearchResult: Identifiable {
    let id: String
    let title: String
    let thumbnailURL: URL?
    let channelName: String
    let viewCount: String
}
