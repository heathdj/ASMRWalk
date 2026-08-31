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
    private(set) var statusMessage: String? = "Select a synced recording or import a GPX file to preview a route."
    private(set) var statusSystemImage = "point.topleft.down.curvedto.point.bottomright.up"
    private(set) var packageURL: URL?
    private(set) var routePreview: RoutePreview?
    private(set) var selectedRoutePointID: RoutePreview.RoutePoint.ID?

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

            try loadGPX(from: selectedURL)
        } catch {
            showFailure(error)
        }
    }

    func loadGPX(from gpxURL: URL) throws {
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
        loadRoutePreview(
            package,
            sourceDescription: "GPX file: \(gpxURL.lastPathComponent)"
        )
    }

    func loadSyncedRecording(_ recording: WalkRecording) {
        let package = ASMRRoutePackage(recording: recording)
        loadRoutePreview(
            package,
            sourceDescription: "Synced \(recording.source.title) recording"
        )
    }

    func exportLoadedRoute() throws {
        guard let package = routePreview?.exportPackage else {
            throw ImportError.noRouteLoaded
        }

        try writePackage(package, successMessage: "\(package.manifest.routePointCount) route points were written to %@.")
    }

    func selectRoutePoint(id: RoutePreview.RoutePoint.ID) {
        guard routePreview?.point(id: id) != nil else {
            return
        }

        selectedRoutePointID = id
    }

    func deleteSelectedRoutePoint() {
        guard var preview = routePreview,
              let selectedRoutePointID,
              let removedPoint = preview.deletePoint(id: selectedRoutePointID) else {
            return
        }

        routePreview = preview
        self.selectedRoutePointID = nil
        packageURL = nil
        statusTitle = "Route Point Removed"
        statusMessage = "Point \(removedPoint.sourceIndex + 1) was removed from the pending export. The source route was not changed."
        statusSystemImage = "point.topleft.down.curvedto.point.bottomright.up"
    }

    func resetRoutePointEdits() {
        guard var preview = routePreview, preview.hasPointEdits else {
            return
        }

        preview.resetEdits()
        routePreview = preview
        selectedRoutePointID = nil
        packageURL = nil
        statusTitle = "Route Restored"
        statusMessage = "\(preview.routePointCount) route points are ready to preview."
        statusSystemImage = "arrow.counterclockwise"
    }

    private func loadRoutePreview(_ package: ASMRRoutePackage, sourceDescription: String) {
        routePreview = RoutePreview(package: package, sourceDescription: sourceDescription)
        selectedRoutePointID = nil
        packageURL = nil
        statusTitle = "Route Loaded"
        statusMessage = "\(package.manifest.routePointCount) route points are ready to preview."
        statusSystemImage = "map.fill"
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
        case noRouteLoaded

        var errorDescription: String? {
            switch self {
            case .fileAccessDenied:
                "The selected GPX file could not be accessed."
            case .outputDirectoryAccessDenied:
                "The selected output folder could not be accessed."
            case .outputDirectoryNotSelected:
                "No output folder was selected."
            case .noRouteLoaded:
                "Load a route before creating an .asmrroute package."
            }
        }
    }
}
