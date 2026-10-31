//
//  FxPlugInstallation.swift
//  ASMR Walk Mac Importer
//

import AppKit
import Foundation
import SwiftUI

struct FxPlugInstallationInspection: Equatable, Sendable {
    enum State: Equatable, Sendable {
        case notInstalled
        case incomplete
        case invalidPluginIdentifier(String?)
        case ready
    }

    let state: State
    let wrapperURL: URL
    let pluginURL: URL
}

struct FxPlugInstallationService: Sendable {
    static let wrapperApplicationName = "ASMR Walk Route Overlay.app"
    static let pluginBundleName = "ASMRWalkRouteOverlay.pluginkit"
    static let expectedPluginIdentifier = "com.bald-traveler.ASMRWalkRouteOverlay"

    let applicationsDirectory: URL

    init(applicationsDirectory: URL = URL(filePath: "/Applications", directoryHint: .isDirectory)) {
        self.applicationsDirectory = applicationsDirectory
    }

    func inspect() -> FxPlugInstallationInspection {
        let wrapperURL = applicationsDirectory.appending(
            path: Self.wrapperApplicationName,
            directoryHint: .isDirectory
        )
        let pluginURL = wrapperURL.appending(
            path: "Contents/PlugIns/\(Self.pluginBundleName)",
            directoryHint: .isDirectory
        )

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: wrapperURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return FxPlugInstallationInspection(
                state: .notInstalled,
                wrapperURL: wrapperURL,
                pluginURL: pluginURL
            )
        }

        guard FileManager.default.fileExists(atPath: pluginURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return FxPlugInstallationInspection(
                state: .incomplete,
                wrapperURL: wrapperURL,
                pluginURL: pluginURL
            )
        }

        let identifier = Bundle(url: pluginURL)?.bundleIdentifier
        guard identifier == Self.expectedPluginIdentifier else {
            return FxPlugInstallationInspection(
                state: .invalidPluginIdentifier(identifier),
                wrapperURL: wrapperURL,
                pluginURL: pluginURL
            )
        }

        return FxPlugInstallationInspection(
            state: .ready,
            wrapperURL: wrapperURL,
            pluginURL: pluginURL
        )
    }

    @MainActor
    func registerInstalledPlugin() async throws {
        let inspection = inspect()
        guard inspection.state == .ready else {
            throw FxPlugInstallationError.notReady
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            NSWorkspace.shared.openApplication(
                at: inspection.wrapperURL,
                configuration: NSWorkspace.OpenConfiguration()
            ) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

enum FxPlugInstallationError: LocalizedError {
    case notReady

    var errorDescription: String? {
        switch self {
        case .notReady:
            String(localized: "The Final Cut Pro plugin installation is incomplete. Run the ASMR Walk installer again.")
        }
    }
}

struct FxPlugInstallationView: View {
    @State private var inspection = FxPlugInstallationService().inspect()
    @State private var isRegistering = false
    @State private var registrationMessage: String?

    private let service = FxPlugInstallationService()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            FxPlugInstallationHeader(state: inspection.state)
            FxPlugInstallationDetails(state: inspection.state)

            if let registrationMessage {
                Text(registrationMessage)
                    .foregroundStyle(.secondary)
            }

            ViewThatFits {
                HStack {
                    actionButtons
                }
                VStack(alignment: .leading) {
                    actionButtons
                }
            }
        }
        .frame(minWidth: 480, alignment: .leading)
        .padding(24)
    }

    @ViewBuilder
    private var actionButtons: some View {
        Button("Check Again") {
            refresh()
        }
        Button("Register or Repair Plugin") {
            registerPlugin()
        }
        .buttonStyle(.borderedProminent)
        .disabled(inspection.state != .ready || isRegistering)
    }

    private func refresh() {
        inspection = service.inspect()
        registrationMessage = nil
    }

    private func registerPlugin() {
        isRegistering = true
        registrationMessage = nil
        Task {
            do {
                try await service.registerInstalledPlugin()
                registrationMessage = String(localized: "The plugin wrapper launched. Quit and reopen Final Cut Pro or Motion before checking for the generator.")
            } catch {
                registrationMessage = error.localizedDescription
            }
            inspection = service.inspect()
            isRegistering = false
        }
    }
}

private struct FxPlugInstallationHeader: View {
    let state: FxPlugInstallationInspection.State

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundStyle(color)
    }

    private var title: LocalizedStringResource {
        switch state {
        case .ready:
            "Final Cut Pro plugin is installed"
        case .notInstalled:
            "Final Cut Pro plugin is not installed"
        case .incomplete, .invalidPluginIdentifier:
            "Final Cut Pro plugin needs repair"
        }
    }

    private var systemImage: String {
        state == .ready ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }

    private var color: Color {
        state == .ready ? .green : .orange
    }
}

private struct FxPlugInstallationDetails: View {
    let state: FxPlugInstallationInspection.State

    var body: some View {
        switch state {
        case .ready:
            Text("The signed route-overlay wrapper and its embedded FxPlug component are present in Applications. Register or repair the plugin, then reopen Final Cut Pro or Motion.")
        case .notInstalled:
            Text("Run the ASMR Walk Mac Tools installer. It installs both the importer and route-overlay plugin wrapper in Applications.")
        case .incomplete:
            Text("The route-overlay app is present, but its embedded plugin is missing. Run the installer again to repair both components.")
        case let .invalidPluginIdentifier(identifier):
            Text("The embedded plugin has an unexpected identifier: \(identifier ?? "missing"). Run the installer again before opening Final Cut Pro or Motion.")
        }
    }
}

struct FxPlugInstallationCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Final Cut Pro Plugin…") {
                openWindow(id: "fxplug-installation")
            }
        }
    }
}
