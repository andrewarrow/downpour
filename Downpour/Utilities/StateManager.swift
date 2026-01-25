//
//  StateManager.swift
//  Downpour
//

import Foundation

struct AppState: Codable {
    var selectedTab: Int
    var selectedSubsFile: String?
    var searchSortBy: Int?
    var searchUploadDate: Int?
    var searchDuration: Int?
    var videoPlaybackPositions: [String: Double]?
}

enum StateManager {
    private static var stateFileURL: URL {
        Paths.applicationSupport.appendingPathComponent("state.json")
    }

    static func load() -> AppState {
        guard FileManager.default.fileExists(atPath: stateFileURL.path),
              let data = try? Data(contentsOf: stateFileURL),
              let state = try? JSONDecoder().decode(AppState.self, from: data) else {
            return AppState(selectedTab: 0, selectedSubsFile: nil)
        }
        return state
    }

    static func save(_ state: AppState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: stateFileURL)
    }

    static func saveSelectedTab(_ tab: Int) {
        var state = load()
        state.selectedTab = tab
        save(state)
    }

    static func saveSelectedSubsFile(_ filename: String?) {
        var state = load()
        state.selectedSubsFile = filename
        save(state)
    }

    static func saveSearchFilters(sortBy: Int, uploadDate: Int, duration: Int) {
        var state = load()
        state.searchSortBy = sortBy
        state.searchUploadDate = uploadDate
        state.searchDuration = duration
        save(state)
    }

    static func saveVideoPlaybackPosition(videoId: String, position: Double) {
        var state = load()
        if state.videoPlaybackPositions == nil {
            state.videoPlaybackPositions = [:]
        }
        state.videoPlaybackPositions?[videoId] = position
        save(state)
    }

    static func getVideoPlaybackPosition(videoId: String) -> Double? {
        let state = load()
        return state.videoPlaybackPositions?[videoId]
    }

    static func removeVideoPlaybackPosition(videoId: String) {
        var state = load()
        state.videoPlaybackPositions?[videoId] = nil
        save(state)
    }
}
