//
//  AppDelegate.swift
//  Downpour
//

import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let window = NSApplication.shared.windows.first,
           let screen = NSScreen.main {
            window.setFrame(screen.visibleFrame, display: true)
        }

        YtDlpSetup.ensureYtDlpAvailable()
    }
}
