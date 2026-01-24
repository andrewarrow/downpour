//
//  YouTubeResponseParser.swift
//  Downpour
//

import Foundation

struct YouTubeResponseParser {

    // MARK: - Search Results Parsing

    static func parseSearchResults(json: [String: Any]) -> [SearchResult] {
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

    // MARK: - Video Renderer Parsing

    static func parseVideoRenderer(_ renderer: [String: Any]) -> SearchResult? {
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

    // MARK: - Related Videos Parsing

    static func parseRelatedVideosWithContinuation(json: [String: Any]) -> ([SearchResult], String?) {
        var results: [SearchResult] = []
        var continuationToken: String? = nil

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

        print("[DEBUG] parseRelatedVideos: Parsed \(results.count) videos, continuation: \(continuationToken != nil)")
        return (results, continuationToken)
    }

    static func parseContinuationResponse(json: [String: Any]) -> ([SearchResult], String?) {
        var results: [SearchResult] = []
        var continuationToken: String? = nil

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

    // MARK: - Lockup View Model Parsing

    static func parseLockupViewModel(_ viewModel: [String: Any]) -> SearchResult? {
        guard let videoId = viewModel["contentId"] as? String else {
            print("[DEBUG] parseLockupViewModel: No contentId found")
            return nil
        }

        guard let metadata = viewModel["metadata"] as? [String: Any],
              let lockupMetadataViewModel = metadata["lockupMetadataViewModel"] as? [String: Any] else {
            print("[DEBUG] parseLockupViewModel: No lockupMetadataViewModel found")
            return nil
        }

        let title: String
        if let titleObj = lockupMetadataViewModel["title"] as? [String: Any],
           let content = titleObj["content"] as? String {
            title = content
        } else {
            title = "Unknown"
        }

        var channelName = ""
        var viewCount = ""
        var channelId: String? = nil

        if let metadataContent = lockupMetadataViewModel["metadata"] as? [String: Any],
           let contentMetadataViewModel = metadataContent["contentMetadataViewModel"] as? [String: Any],
           let metadataRows = contentMetadataViewModel["metadataRows"] as? [[String: Any]] {

            if let firstRow = metadataRows.first,
               let metadataParts = firstRow["metadataParts"] as? [[String: Any]],
               let firstPart = metadataParts.first,
               let text = firstPart["text"] as? [String: Any],
               let content = text["content"] as? String {
                channelName = content
            }

            if metadataRows.count > 1,
               let secondRow = metadataRows[1] as? [String: Any],
               let metadataParts = secondRow["metadataParts"] as? [[String: Any]],
               let firstPart = metadataParts.first,
               let text = firstPart["text"] as? [String: Any],
               let content = text["content"] as? String {
                viewCount = content
            }
        }

        var channelThumbnailURL: String? = nil
        if let image = lockupMetadataViewModel["image"] as? [String: Any],
           let decoratedAvatarViewModel = image["decoratedAvatarViewModel"] as? [String: Any] {
            if let rendererContext = decoratedAvatarViewModel["rendererContext"] as? [String: Any],
               let commandContext = rendererContext["commandContext"] as? [String: Any],
               let onTap = commandContext["onTap"] as? [String: Any],
               let innertubeCommand = onTap["innertubeCommand"] as? [String: Any],
               let browseEndpoint = innertubeCommand["browseEndpoint"] as? [String: Any],
               let browseId = browseEndpoint["browseId"] as? String {
                channelId = browseId
            }
            if let avatar = decoratedAvatarViewModel["avatar"] as? [String: Any],
               let avatarViewModel = avatar["avatarViewModel"] as? [String: Any],
               let avatarImage = avatarViewModel["image"] as? [String: Any],
               let sources = avatarImage["sources"] as? [[String: Any]],
               let firstSource = sources.first,
               let urlString = firstSource["url"] as? String {
                channelThumbnailURL = urlString
            }
        }

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
            channelThumbnailURL: channelThumbnailURL,
            channelName: channelName,
            viewCount: viewCount,
            publishedText: nil
        )
    }

    // MARK: - Compact Video Renderer Parsing

    static func parseCompactVideoRenderer(_ renderer: [String: Any]) -> SearchResult? {
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

    // MARK: - Channel Videos Parsing

    static func parseChannelVideos(json: [String: Any]) -> [SearchResult] {
        var results: [SearchResult] = []

        guard let contents = json["contents"] as? [String: Any],
              let twoColumnBrowseResultsRenderer = contents["twoColumnBrowseResultsRenderer"] as? [String: Any],
              let tabs = twoColumnBrowseResultsRenderer["tabs"] as? [[String: Any]] else {
            return results
        }

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

            if let sectionListRenderer = tabContent["sectionListRenderer"] as? [String: Any],
               let sectionContents = sectionListRenderer["contents"] as? [[String: Any]] {
                for section in sectionContents {
                    if let itemSectionRenderer = section["itemSectionRenderer"] as? [String: Any],
                       let items = itemSectionRenderer["contents"] as? [[String: Any]] {
                        for item in items {
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

    static func parseGridVideoRenderer(_ renderer: [String: Any], channelName: String, channelId: String?) -> SearchResult? {
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

    // MARK: - Diversity Filter

    static func applyDiversityFilter(results: [SearchResult], excludeChannelId: String?) -> [SearchResult] {
        var filtered = results
        if let excludeId = excludeChannelId {
            filtered = results.filter { $0.channelId != excludeId }
            print("[DEBUG] After excluding source channel: \(filtered.count) results")
        }

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

        let sortedChannels = byChannel.sorted { $0.value.count > $1.value.count }

        var diverseResults: [SearchResult] = []
        for (_, videos) in sortedChannels {
            if let firstVideo = videos.first {
                diverseResults.append(firstVideo)
            }
        }

        diverseResults.append(contentsOf: noChannelResults)

        return Array(diverseResults.prefix(30))
    }
}
