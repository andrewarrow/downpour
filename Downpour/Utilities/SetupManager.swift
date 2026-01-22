//
//  SetupManager.swift
//  Downpour
//

import Foundation
import SwiftUI
import Combine

@MainActor
class SetupManager: ObservableObject {
    enum SetupStep: String {
        case checkingDependencies = "Checking dependencies..."
        case creatingVenv = "Creating Python environment..."
        case installingYtDlp = "Installing yt-dlp..."
        case waitingForBrew = "Waiting for Homebrew installation..."
        case installingFfmpeg = "Installing ffmpeg..."
        case complete = "Setup complete!"
    }

    @Published var isSetupRequired = false
    @Published var currentStep: SetupStep = .checkingDependencies
    @Published var stepOutput: String = ""
    @Published var needsBrewInstall = false
    @Published var brewInstallCommand: String = ""
    @Published var isComplete = false

    private var outputBuffer: String = ""

    func checkAndRunSetup() async {
        let needsVenv = !FileManager.default.fileExists(atPath: Paths.venvDirectory.path)
        let needsBrew = !brewIsInstalled()
        let needsFfmpeg = !ffmpegIsInstalled()

        if needsVenv || needsBrew || needsFfmpeg {
            isSetupRequired = true
            await runSetup(needsVenv: needsVenv, needsBrew: needsBrew, needsFfmpeg: needsFfmpeg)
        } else {
            // Still update yt-dlp in background
            Task.detached {
                await self.installYtDlp(showProgress: false)
            }
        }
    }

    private func runSetup(needsVenv: Bool, needsBrew: Bool, needsFfmpeg: Bool) async {
        // Step 1: Create venv if needed
        if needsVenv {
            currentStep = .creatingVenv
            stepOutput = ""
            let success = await createVenv()
            if !success {
                stepOutput += "\n❌ Failed to create Python environment"
                return
            }
            stepOutput += "\n✓ Python environment created"
        }

        // Step 2: Install/update yt-dlp
        currentStep = .installingYtDlp
        stepOutput = ""
        await installYtDlp(showProgress: true)
        stepOutput += "\n✓ yt-dlp installed"

        // Step 3: Install Homebrew if needed
        if needsBrew {
            currentStep = .waitingForBrew
            stepOutput = ""
            needsBrewInstall = true
            brewInstallCommand = "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""

            // Wait for user to complete brew installation
            while !brewIsInstalled() {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // Check every 2 seconds
            }
            needsBrewInstall = false
            stepOutput += "\n✓ Homebrew installed"
        }

        // Step 4: Install ffmpeg if needed
        if needsFfmpeg || needsBrew {
            currentStep = .installingFfmpeg
            stepOutput = ""
            await installFfmpeg()
            stepOutput += "\n✓ ffmpeg installed"
        }

        // Done!
        currentStep = .complete
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isComplete = true
        isSetupRequired = false
    }

    private func brewIsInstalled() -> Bool {
        let paths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        return paths.contains { FileManager.default.fileExists(atPath: $0) }
    }

    private func ffmpegIsInstalled() -> Bool {
        let paths = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg"]
        return paths.contains { FileManager.default.fileExists(atPath: $0) }
    }

    private func createVenv() async -> Bool {
        let process = Process()
        process.executableURL = Paths.pythonExecutable
        process.arguments = ["-m", "venv", Paths.venvDirectory.path]

        return await runProcess(process)
    }

    private func installYtDlp(showProgress: Bool) async {
        let process = Process()
        process.executableURL = Paths.pipExecutable
        process.arguments = ["install", "--upgrade", "yt-dlp"]

        var env = ProcessInfo.processInfo.environment
        env["VIRTUAL_ENV"] = Paths.venvDirectory.path
        process.environment = env

        _ = await runProcess(process, streamOutput: showProgress)
    }

    private func installFfmpeg() async {
        let brewPath = FileManager.default.fileExists(atPath: "/opt/homebrew/bin/brew")
            ? "/opt/homebrew/bin/brew"
            : "/usr/local/bin/brew"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: brewPath)
        process.arguments = ["install", "ffmpeg"]

        _ = await runProcess(process, streamOutput: true)
    }

    private func runProcess(_ process: Process, streamOutput: Bool = false) async -> Bool {
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        if streamOutput {
            pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                    Task { @MainActor in
                        self?.appendOutput(str)
                    }
                }
            }
        }

        do {
            try process.run()
            process.waitUntilExit()
            pipe.fileHandleForReading.readabilityHandler = nil

            if !streamOutput {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    appendOutput(output)
                }
            }

            return process.terminationStatus == 0
        } catch {
            appendOutput("Error: \(error.localizedDescription)")
            return false
        }
    }

    private func appendOutput(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            if stepOutput.isEmpty {
                stepOutput = trimmed
            } else {
                stepOutput += "\n" + trimmed
            }
        }
    }

    func copyBrewCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(brewInstallCommand, forType: .string)
    }

    func openTerminal() {
        let script = """
        tell application "Terminal"
            activate
            do script "\(brewInstallCommand)"
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
}
