//
//  Subscription.swift
//  Downpour
//

import Foundation

struct Subscription: Codable, Identifiable {
    var id: String { snippet.resourceId.channelId }
    let snippet: SubscriptionSnippet
}

struct SubscriptionSnippet: Codable {
    let channelId: String
    let title: String
    let resourceId: ResourceId
    let thumbnails: Thumbnails
}

struct ResourceId: Codable {
    let channelId: String
}

struct Thumbnails: Codable {
    let `default`: ThumbnailInfo
}

struct ThumbnailInfo: Codable {
    let url: String
}
