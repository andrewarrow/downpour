//
//  ContentView.swift
//  Downpour
//
//  Created by aa on 1/22/26.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var subsFiles: [URL] = []
    @State private var selectedSubsFile: URL?
    @StateObject private var setupManager = SetupManager()

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Tab bar
                HStack(spacing: 0) {
                    TabButton(title: "yt-dlp", isSelected: selectedTab == 0) {
                        selectedTab = 0
                    }
                    TabButton(title: "search", isSelected: selectedTab == 1) {
                        selectedTab = 1
                    }
                    TabButton(title: "subs", isSelected: selectedTab == 2) {
                        selectedTab = 2
                    }
                    TabButton(title: "channels", isSelected: selectedTab == 3) {
                        selectedTab = 3
                    }
                    Spacer()
                    Picker("", selection: $selectedSubsFile) {
                        ForEach(subsFiles, id: \.self) { file in
                            Text(file.deletingPathExtension().lastPathComponent)
                                .tag(file as URL?)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)
                    .padding(.trailing, 8)
                    Button("Open Data Folder") {
                        NSWorkspace.shared.open(Paths.dataDirectory)
                    }
                    .buttonStyle(.borderless)
                    .padding(.trailing, 12)
                }
                .background(Color(nsColor: .windowBackgroundColor))

                Divider()

                // Tab content
                if selectedTab == 0 {
                    YtDlpView()
                } else if selectedTab == 1 {
                    APISearchView()
                } else if selectedTab == 2 {
                    if let subsFile = selectedSubsFile {
                        SubsView(subsFile: subsFile)
                            .id(subsFile)
                    }
                } else {
                    if let subsFile = selectedSubsFile {
                        ChannelsView(subsFile: subsFile)
                            .id(subsFile)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .disabled(setupManager.isSetupRequired)
            .blur(radius: setupManager.isSetupRequired ? 3 : 0)
            .onAppear {
                loadSubsFiles()
            }

            if setupManager.isSetupRequired {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()

                SetupView(setupManager: setupManager)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .cornerRadius(12)
                    .shadow(radius: 20)
            }
        }
        .task {
            await setupManager.checkAndRunSetup()
        }
    }

    private func loadSubsFiles() {
        subsFiles = Paths.getSubsFiles()
        if selectedSubsFile == nil, let first = subsFiles.first {
            selectedSubsFile = first
        }
    }
}

#Preview {
    ContentView()
}
