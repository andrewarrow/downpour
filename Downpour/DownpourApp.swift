//
//  DownpourApp.swift
//  Downpour
//
//  Created by aa on 1/22/26.
//

import SwiftUI

@main
struct DownpourApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let window = NSApplication.shared.windows.first,
           let screen = NSScreen.main {
            window.setFrame(screen.visibleFrame, display: true)
        }
    }
}
