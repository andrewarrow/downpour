//
//  SetupView.swift
//  Downpour
//

import SwiftUI

struct SetupView: View {
    @ObservedObject var setupManager: SetupManager

    var body: some View {
        VStack(spacing: 24) {
            Text("Setting Up Downpour")
                .font(.title)
                .fontWeight(.semibold)

            VStack(spacing: 16) {
                // Progress indicator
                if setupManager.currentStep != .complete {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding(.bottom, 8)
                }

                // Current step
                Text(setupManager.currentStep.rawValue)
                    .font(.headline)
                    .foregroundColor(setupManager.currentStep == .complete ? .green : .primary)

                // Output log
                if !setupManager.stepOutput.isEmpty {
                    ScrollViewReader { proxy in
                        ScrollView {
                            Text(setupManager.stepOutput)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id("output")
                        }
                        .frame(height: 120)
                        .padding(8)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(8)
                        .onChange(of: setupManager.stepOutput) { _, _ in
                            proxy.scrollTo("output", anchor: .bottom)
                        }
                    }
                }

                // Homebrew installation instructions
                if setupManager.needsBrewInstall {
                    VStack(spacing: 12) {
                        Text("Homebrew is required but not installed.")
                            .font(.subheadline)

                        Text("Please install Homebrew by running this command in Terminal.\nYou may be asked for your Mac password.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        HStack {
                            Text(setupManager.brewInstallCommand)
                                .font(.system(.caption2, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .padding(8)
                                .background(Color(nsColor: .textBackgroundColor))
                                .cornerRadius(4)

                            Button("Copy") {
                                setupManager.copyBrewCommand()
                            }
                        }

                        Button("Open Terminal & Run") {
                            setupManager.openTerminal()
                        }
                        .buttonStyle(.borderedProminent)

                        Text("Waiting for Homebrew installation to complete...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .frame(maxWidth: 500)
        }
        .padding(32)
        .frame(width: 550, height: 400)
    }
}
