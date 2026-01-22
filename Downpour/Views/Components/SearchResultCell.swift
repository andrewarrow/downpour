//
//  SearchResultCell.swift
//  Downpour
//

import SwiftUI

struct SearchResultCell: View {
    @Environment(\.openWindow) private var openWindow
    let result: SearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: result.thumbnailURL) { image in
                image
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fit)
                    .cornerRadius(8)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(16/9, contentMode: .fit)
                    .cornerRadius(8)
            }

            Text(result.title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(2)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.channelName)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Text(result.viewCount)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .onTapGesture {
            let video = StreamingVideo(videoId: result.id, title: result.title)
            openWindow(value: video)
        }
    }
}
