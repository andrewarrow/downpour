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
    @State private var showingNewCategoryAlert = false
    @State private var newCategoryName = ""
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
                    TabButton(title: "v3-list", isSelected: selectedTab == 4) {
                        selectedTab = 4
                    }
                    TabButton(title: "v3-search", isSelected: selectedTab == 5) {
                        selectedTab = 5
                    }
                    Spacer()
                    Menu {
                        ForEach(subsFiles, id: \.self) { file in
                            Button(action: { selectedSubsFile = file }) {
                                HStack {
                                    Text(file.deletingPathExtension().lastPathComponent)
                                    if file == selectedSubsFile {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                        Divider()
                        Button("Add New Category...") {
                            newCategoryName = ""
                            showingNewCategoryAlert = true
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedSubsFile?.deletingPathExtension().lastPathComponent ?? "Select")
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10))
                        }
                    }
                    .menuStyle(.borderlessButton)
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
                    APISearchView(allSubsFiles: subsFiles)
                } else if selectedTab == 2 {
                    if let subsFile = selectedSubsFile {
                        SubsView(subsFile: subsFile)
                            .id(subsFile)
                    }
                } else if selectedTab == 3 {
                    if let subsFile = selectedSubsFile {
                        ChannelsView(subsFile: subsFile, allSubsFiles: subsFiles)
                            .id(subsFile)
                    }
                } else if selectedTab == 4 {
                    YouTubeAPIView()
                } else if selectedTab == 5 {
                    YouTubeSearchAPIView()
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
        .alert("New Category", isPresented: $showingNewCategoryAlert) {
            TextField("Category name", text: $newCategoryName)
            Button("Cancel", role: .cancel) { }
            Button("Create") {
                createNewCategory()
            }
        } message: {
            Text("Enter a name for the new category:")
        }
        .onChange(of: selectedTab) { _, newValue in
            StateManager.saveSelectedTab(newValue)
        }
        .onChange(of: selectedSubsFile) { _, newValue in
            StateManager.saveSelectedSubsFile(newValue?.lastPathComponent)
        }
    }

    private func loadSubsFiles() {
        subsFiles = Paths.getSubsFiles()

        let savedState = StateManager.load()
        selectedTab = savedState.selectedTab

        if let savedFilename = savedState.selectedSubsFile,
           let matchingFile = subsFiles.first(where: { $0.lastPathComponent == savedFilename }) {
            selectedSubsFile = matchingFile
        } else if let first = subsFiles.first {
            selectedSubsFile = first
        }
    }

    private func createNewCategory() {
        let sanitized = sanitizeFilename(newCategoryName)
        guard !sanitized.isEmpty else { return }

        let newFile = Paths.subsDirectory.appendingPathComponent("\(sanitized).json")

        // Don't overwrite existing file
        guard !FileManager.default.fileExists(atPath: newFile.path) else { return }

        do {
            try "[]".write(to: newFile, atomically: true, encoding: .utf8)
            loadSubsFiles()
            selectedSubsFile = newFile
        } catch {
            print("Failed to create category: \(error)")
        }
    }

    private func sanitizeFilename(_ name: String) -> String {
        let lowercased = name.lowercased()
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let filtered = lowercased.unicodeScalars.filter { allowed.contains($0) }
        return String(String.UnicodeScalarView(filtered))
    }
}

#Preview {
    ContentView()
}
