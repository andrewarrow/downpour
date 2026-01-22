//
//  ContentView.swift
//  Downpour
//
//  Created by aa on 1/22/26.
//

import SwiftUI

struct ContentView: View {
    @State private var urlText: String = ""
    @State private var outputText: String = ""
    @State private var isDownloading: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            TextField("Paste URL and press Enter", text: $urlText)
                .textFieldStyle(.plain)
                .font(.system(size: 18))
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .disabled(isDownloading)
                .onSubmit {
                    startDownload()
                }

            ScrollView {
                Text(outputText)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func startDownload() {
        guard !urlText.isEmpty else { return }

        isDownloading = true
        outputText = "Starting download...\n"

        let url = urlText

        Task {
            await runYtDlp(url: url)
        }
    }

    private func runYtDlp(url: String) async {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/yt-dlp")
        process.arguments = [
            "-o", "./data/%(id)s.%(ext)s",
            "-f", "bv*[vcodec^=avc1][ext=mp4]+ba[acodec^=mp4a][ext=m4a]/best[ext=mp4][vcodec^=avc1]",
            "--merge-output-format", "mp4",
            url
        ]
        let projectDir = "/Users/aa/dev/Downpour"
        process.currentDirectoryURL = URL(fileURLWithPath: projectDir)

        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                Task { @MainActor in
                    outputText += str
                }
            }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                Task { @MainActor in
                    outputText += str
                }
            }
        }

        do {
            try process.run()
            process.waitUntilExit()

            await MainActor.run {
                outputText += "\nDownload completed with exit code: \(process.terminationStatus)\n"
                isDownloading = false
                urlText = ""
            }
        } catch {
            await MainActor.run {
                outputText += "\nError: \(error.localizedDescription)\n"
                isDownloading = false
            }
        }

        pipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil
    }
}

#Preview {
    ContentView()
}
