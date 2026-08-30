//
//  MacImporterViewModel.swift
//  ASMR Walk Mac Importer
//

import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
final class MacImporterViewModel {
    private(set) var statusTitle = "Ready"
    private(set) var statusMessage: String? = "Choose an ASMR Walk GPX export to create an .asmrroute package."
    private(set) var statusSystemImage = "point.topleft.down.curvedto.point.bottomright.up"
    private(set) var packageURL: URL?

    private let importer: ASMRGPXRouteImporter
    private let fileManager: FileManager

    init(
        importer: ASMRGPXRouteImporter = ASMRGPXRouteImporter(),
        fileManager: FileManager = .default
    ) {
        self.importer = importer
        self.fileManager = fileManager
    }

    func handleGPXImportResult(_ result: Result<[URL], any Error>) async {
        do {
            let selectedURL = try result.get().first
            guard let selectedURL else {
                return
            }

            try importGPX(from: selectedURL)
        } catch {
            showFailure(error)
        }
    }

    func importGPX(from gpxURL: URL) throws {
        guard gpxURL.startAccessingSecurityScopedResource() else {
            throw ImportError.fileAccessDenied
        }
        defer {
            gpxURL.stopAccessingSecurityScopedResource()
        }

        let data = try Data(contentsOf: gpxURL)
        let package = try importer.package(
            fromGPXData: data,
            sourceFilename: gpxURL.lastPathComponent
        )
        try writePackage(package, successMessage: "\(package.manifest.routePointCount) route points were written to %@.")
    }

    func exportSyncedRecording(_ recording: WalkRecording) throws {
        let package = ASMRRoutePackage(recording: recording)
        try writePackage(package, successMessage: "\(package.manifest.routePointCount) synced route points were written to %@.")
    }

    private func writePackage(_ package: ASMRRoutePackage, successMessage: String) throws {
        let outputDirectory = try chooseOutputDirectory()
        let outputURL = ASMRRoutePackage.packageURL(
            forTitle: package.manifest.title,
            in: outputDirectory
        )

        guard outputDirectory.startAccessingSecurityScopedResource() else {
            throw ImportError.outputDirectoryAccessDenied
        }
        defer {
            outputDirectory.stopAccessingSecurityScopedResource()
        }

        try package.write(to: outputURL, fileManager: fileManager)
        packageURL = outputURL
        statusTitle = "Package Created"
        statusMessage = String(format: successMessage, outputURL.lastPathComponent)
        statusSystemImage = "checkmark.circle.fill"
    }

    func revealPackageInFinder() {
        guard let packageURL else {
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([packageURL])
    }

    private func chooseOutputDirectory() throws -> URL {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Create Package"
        panel.message = "Choose where to create the .asmrroute package."

        guard panel.runModal() == .OK, let url = panel.url else {
            throw ImportError.outputDirectoryNotSelected
        }

        return url
    }

    func showFailure(_ error: any Error) {
        packageURL = nil
        statusTitle = "Import Failed"
        statusMessage = error.localizedDescription
        statusSystemImage = "exclamationmark.triangle.fill"
    }
}

extension MacImporterViewModel {
    enum ImportError: LocalizedError, Equatable {
        case fileAccessDenied
        case outputDirectoryAccessDenied
        case outputDirectoryNotSelected

        var errorDescription: String? {
            switch self {
            case .fileAccessDenied:
                "The selected GPX file could not be accessed."
            case .outputDirectoryAccessDenied:
                "The selected output folder could not be accessed."
            case .outputDirectoryNotSelected:
                "No output folder was selected."
            }
        }
    }
}
