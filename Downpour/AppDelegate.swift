//
//  AppDelegate.swift
//  Downpour
//

import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[AppDelegate] applicationDidFinishLaunching - window count: \(NSApplication.shared.windows.count)")
        for (i, window) in NSApplication.shared.windows.enumerated() {
            print("[AppDelegate]   Window \(i): \(window.title), isVisible: \(window.isVisible)")
        }

        if let window = NSApplication.shared.windows.first,
           let screen = NSScreen.main {
            window.setFrame(screen.visibleFrame, display: true)
        }
    }

    func applicationShouldRestoreSecureState(_ app: NSApplication, coder: NSCoder) -> Bool {
        print("[AppDelegate] applicationShouldRestoreSecureState called - returning false")
        return false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        print("[AppDelegate] applicationSupportsSecureRestorableState called - returning false")
        return false
    }
}
