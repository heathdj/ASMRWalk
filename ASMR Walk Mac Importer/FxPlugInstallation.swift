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

    enum MotionTemplateState: Equatable, Sendable {
        case notInstalled
        case invalid
        case ready
    }

    let state: State
    let motionTemplateState: MotionTemplateState
    let wrapperURL: URL
    let pluginURL: URL
    let motionTemplateURL: URL

    var isComplete: Bool {
        state == .ready && motionTemplateState == .ready
    }
}

struct FxPlugInstallationService: Sendable {
    static let wrapperApplicationName = "ASMR Walk Route Overlay.app"
    static let pluginBundleName = "ASMRWalkRouteOverlay.pluginkit"
    static let expectedPluginIdentifier = "com.bald-traveler.ASMRWalkRouteOverlay"
    static let expectedPluginUUID = "D3A901A9-B749-4B9D-AF3D-F28509A457DF"
    static let motionTemplateRelativePath = "Generators.localized/ASMR Walk/ASMR Walk Route Overlay"
    static let motionTemplateDocumentName = "ASMR Walk Route Overlay.motn"

    let applicationsDirectory: URL
    let motionTemplatesDirectory: URL

    init(
        applicationsDirectory: URL = URL(filePath: "/Applications", directoryHint: .isDirectory),
        motionTemplatesDirectory: URL? = nil
    ) {
        self.applicationsDirectory = applicationsDirectory
        let moviesDirectory = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: "Movies", directoryHint: .isDirectory)
        self.motionTemplatesDirectory = motionTemplatesDirectory
            ?? moviesDirectory.appending(path: "Motion Templates.localized", directoryHint: .isDirectory)
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
        let motionTemplateURL = motionTemplatesDirectory.appending(
            path: Self.motionTemplateRelativePath,
            directoryHint: .isDirectory
        )
        let motionTemplateState = inspectMotionTemplate(at: motionTemplateURL)

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: wrapperURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return FxPlugInstallationInspection(
                state: .notInstalled,
                motionTemplateState: motionTemplateState,
                wrapperURL: wrapperURL,
                pluginURL: pluginURL,
                motionTemplateURL: motionTemplateURL
            )
        }

        guard FileManager.default.fileExists(atPath: pluginURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return FxPlugInstallationInspection(
                state: .incomplete,
                motionTemplateState: motionTemplateState,
                wrapperURL: wrapperURL,
                pluginURL: pluginURL,
                motionTemplateURL: motionTemplateURL
            )
        }

        let identifier = Bundle(url: pluginURL)?.bundleIdentifier
        guard identifier == Self.expectedPluginIdentifier else {
            return FxPlugInstallationInspection(
                state: .invalidPluginIdentifier(identifier),
                motionTemplateState: motionTemplateState,
                wrapperURL: wrapperURL,
                pluginURL: pluginURL,
                motionTemplateURL: motionTemplateURL
            )
        }

        return FxPlugInstallationInspection(
            state: .ready,
            motionTemplateState: motionTemplateState,
            wrapperURL: wrapperURL,
            pluginURL: pluginURL,
            motionTemplateURL: motionTemplateURL
        )
    }

    private func inspectMotionTemplate(at templateURL: URL) -> FxPlugInstallationInspection.MotionTemplateState {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: templateURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return .notInstalled
        }

        let requiredFiles = [
            Self.motionTemplateDocumentName,
            "large.png",
            "small.png"
        ]
        guard requiredFiles.allSatisfy({
            FileManager.default.fileExists(atPath: templateURL.appending(path: $0).path)
        }) else {
            return .invalid
        }

        return .ready
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
    @Environment(\.dismiss) private var dismiss
    @State private var inspection = FxPlugInstallationService().inspect()
    @State private var isRegistering = false
    @State private var registrationMessage: String?

    private let service = FxPlugInstallationService()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            FxPlugInstallationHeader(isComplete: inspection.isComplete)
            FxPlugInstallationDetails(inspection: inspection)

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
        Button("Close") {
            dismiss()
        }
        .keyboardShortcut(.cancelAction)
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
    let isComplete: Bool

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundStyle(color)
    }

    private var title: LocalizedStringResource {
        if isComplete {
            "Final Cut Pro plugin is installed"
        } else {
            "Final Cut Pro plugin needs repair"
        }
    }

    private var systemImage: String {
        isComplete ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }

    private var color: Color {
        isComplete ? .green : .orange
    }
}

private struct FxPlugInstallationDetails: View {
    let inspection: FxPlugInstallationInspection

    var body: some View {
        switch inspection.state {
        case .ready:
            Label("Signed FxPlug component installed", systemImage: "checkmark.circle")
        case .notInstalled:
            Label("FxPlug component is not installed", systemImage: "xmark.circle")
        case .incomplete:
            Label("FxPlug component is incomplete", systemImage: "exclamationmark.triangle")
        case .invalidPluginIdentifier:
            Label("FxPlug component has an unexpected identifier", systemImage: "exclamationmark.triangle")
        }

        switch inspection.motionTemplateState {
        case .ready:
            Label("Final Cut Pro generator template installed", systemImage: "checkmark.circle")
        case .notInstalled:
            Label("Final Cut Pro generator template is not installed", systemImage: "xmark.circle")
        case .invalid:
            Label("Final Cut Pro generator template needs repair", systemImage: "exclamationmark.triangle")
        }

        if !inspection.isComplete {
            Text("Run the ASMR Walk Mac Tools installer again to repair only the ASMR Walk-owned components, then reopen Final Cut Pro and Motion.")
                .foregroundStyle(.secondary)
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
