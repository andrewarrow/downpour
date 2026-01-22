//
//  ContentView.swift
//  Downpour
//
//  Created by aa on 1/22/26.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                TabButton(title: "yt-dlp", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                TabButton(title: "api", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
                Spacer()
            }
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Tab content
            if selectedTab == 0 {
                YtDlpView()
            } else {
                APISearchView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
}
