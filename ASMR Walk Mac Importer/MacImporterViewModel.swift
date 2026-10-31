//
//  MacImporterViewModel.swift
//  ASMR Walk Mac Importer
//

import AppKit
import Foundation
import Observation
import Photos
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
    private(set) var selectedPhotosVideoReference: PhotosVideoReference?
    private(set) var selectedFileVideoReference: FileVideoReference?
    private(set) var preparedMapBackground: PreparedMapBackground?
    private(set) var preparedMapBackgrounds: [PreparedMapBackground] = []
    private(set) var isPreparingMapBackground = false

    private let importer: ASMRGPXRouteImporter
    private let fileManager: FileManager
    private let photosMetadataLoader: any PhotosVideoMetadataLoading
    private let fileVideoReferenceLoader: any FileVideoReferenceLoading
    private let mapBackgroundPreparer: any MapBackgroundPreparing

    init(
        importer: ASMRGPXRouteImporter = ASMRGPXRouteImporter(),
        fileManager: FileManager = .default,
        photosMetadataLoader: (any PhotosVideoMetadataLoading)? = nil,
        fileVideoReferenceLoader: (any FileVideoReferenceLoading)? = nil,
        mapBackgroundPreparer: (any MapBackgroundPreparing)? = nil
    ) {
        self.importer = importer
        self.fileManager = fileManager
        self.photosMetadataLoader = photosMetadataLoader ?? PhotoLibraryVideoMetadataLoader()
        self.fileVideoReferenceLoader = fileVideoReferenceLoader ?? FileVideoReferenceLoader()
        self.mapBackgroundPreparer = mapBackgroundPreparer ?? MapBackgroundPreparer()
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
        guard let package = pendingExportPackage else {
            throw ImportError.noRouteLoaded
        }

        try writePackage(package, successMessage: "\(package.manifest.routePointCount) route points were written to %@.")
    }

    var pendingExportPackage: ASMRRoutePackage? {
        routePreview?.exportPackage(
            videoReference: selectedVideoPackageReference,
            mapBackground: preparedMapBackground,
            mapBackgrounds: preparedMapBackgrounds
        )
    }

    func prepareMapBackground() async {
        guard let routePreview else {
            showFailure(ImportError.noRouteLoaded)
            return
        }

        isPreparingMapBackground = true
        defer { isPreparingMapBackground = false }
        do {
            preparedMapBackground = try await mapBackgroundPreparer.prepare(for: routePreview)
            preparedMapBackgrounds = []
            packageURL = nil
            statusTitle = "Map Background Ready"
            statusMessage = "The next package will include a local map image. Final Cut Pro rendering will not contact MapKit."
            statusSystemImage = "map.fill"
        } catch {
            preparedMapBackground = nil
            statusTitle = "Map Background Unavailable"
            statusMessage = "\(error.localizedDescription) You can still export the route-only package."
            statusSystemImage = "map"
        }
    }

    func prepareSegmentedMapBackgrounds() async {
        guard let routePreview else {
            showFailure(ImportError.noRouteLoaded)
            return
        }

        isPreparingMapBackground = true
        defer { isPreparingMapBackground = false }
        do {
            preparedMapBackgrounds = try await mapBackgroundPreparer.prepareSegments(for: routePreview)
            preparedMapBackground = nil
            packageURL = nil
            statusTitle = "Segmented Maps Ready"
            statusMessage = "\(preparedMapBackgrounds.count) local map images will be included for deterministic offline rendering."
            statusSystemImage = "map.fill"
        } catch {
            preparedMapBackgrounds = []
            statusTitle = "Segmented Maps Unavailable"
            statusMessage = "\(error.localizedDescription) Retry, prepare one map, or export the route only."
            statusSystemImage = "map"
        }
    }

    func clearMapBackground() {
        guard preparedMapBackground != nil || preparedMapBackgrounds.isEmpty == false else { return }
        preparedMapBackground = nil
        preparedMapBackgrounds = []
        packageURL = nil
        statusTitle = "Route-Only Export"
        statusMessage = "The prepared map was removed. The next package will keep a transparent route overlay."
        statusSystemImage = "point.topleft.down.curvedto.point.bottomright.up"
    }

    func pairPhotosVideo(itemIdentifier: String?, supportedContentTypes: [UTType]) async {
        guard let itemIdentifier, itemIdentifier.isEmpty == false else {
            showFailure(ImportError.photosVideoIdentifierUnavailable)
            return
        }

        var pairingMessage: String?
        selectedPhotosVideoReference = PhotosVideoReference(
            itemIdentifier: itemIdentifier,
            supportedContentTypes: supportedContentTypes,
            metadata: nil
        )
        selectedFileVideoReference = nil

        do {
            let metadata = try await photosMetadataLoader.metadata(forItemIdentifier: itemIdentifier)
            selectedPhotosVideoReference = PhotosVideoReference(
                itemIdentifier: itemIdentifier,
                supportedContentTypes: supportedContentTypes,
                metadata: metadata
            )
            pairingMessage = photosVideoPairingMessage
        } catch PhotoLibraryVideoMetadataLoader.MetadataError.usageDescriptionMissing {
            pairingMessage = "The Photos video is selected. Add the Mac target Photos usage description in Xcode before timestamp, duration, and location matching can run."
        } catch {
            pairingMessage = "The Photos video is selected, but its timestamp, duration, and location metadata could not be loaded: \(error.localizedDescription)"
        }

        packageURL = nil
        statusTitle = "Photos Video Paired"
        statusMessage = messagePreservingPreparedMap(pairingMessage ?? photosVideoPairingMessage)
        statusSystemImage = "photo.on.rectangle"
    }

    func clearPhotosVideoPairing() {
        guard selectedPhotosVideoReference != nil || selectedFileVideoReference != nil else {
            return
        }

        selectedPhotosVideoReference = nil
        selectedFileVideoReference = nil
        packageURL = nil
        statusTitle = "Video Removed"
        statusMessage = "The pending route package will not include a video reference."
        statusSystemImage = "photo.on.rectangle.angled"
    }

    func pairVideoFile(at url: URL) async {
        do {
            let reference = try await fileVideoReferenceLoader.load(from: url)
            selectedFileVideoReference = reference
            selectedPhotosVideoReference = nil
            packageURL = nil
            statusTitle = "Video File Paired"
            statusMessage = messagePreservingPreparedMap(videoPairingMessage)
            statusSystemImage = "film"
        } catch {
            showFailure(error)
        }
    }

    func handleVideoImportResult(_ result: Result<[URL], any Error>) async {
        do {
            guard let selectedURL = try result.get().first else { return }
            await pairVideoFile(at: selectedURL)
        } catch let error as CocoaError where error.code == .userCancelled {
            // Cancellation intentionally preserves the current video pairing.
        } catch {
            showFailure(error)
        }
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
        preparedMapBackground = nil
        preparedMapBackgrounds = []
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
        preparedMapBackground = nil
        preparedMapBackgrounds = []
        selectedRoutePointID = nil
        packageURL = nil
        statusTitle = "Route Restored"
        statusMessage = "\(preview.routePointCount) route points are ready to preview."
        statusSystemImage = "arrow.counterclockwise"
    }

    var photosVideoPairingMessage: String {
        guard let selectedPhotosVideoReference else {
            return "Select a Photos video to pair it with the loaded route."
        }

        guard routePreview != nil else {
            return "\(selectedPhotosVideoReference.displayName) is selected. Load a route before creating an .asmrroute package."
        }

        if let offsetText = selectedPhotosVideoReference.offsetText(relativeTo: routePreview) {
            return "\(selectedPhotosVideoReference.displayName) will be referenced in the next .asmrroute package. Estimated route offset: \(offsetText)."
        }

        return "\(selectedPhotosVideoReference.displayName) will be referenced in the next .asmrroute package. The video file will not be copied into the package."
    }

    var videoPairingMessage: String {
        if let selectedFileVideoReference {
            let durationDescription = selectedFileVideoReference.durationText.map { " Duration: \($0)." } ?? ""
            guard routePreview != nil else {
                return "\(selectedFileVideoReference.displayName) is selected.\(durationDescription) Load a route before creating an .asmrroute package."
            }
            if let offsetText = selectedFileVideoReference.offsetText(relativeTo: routePreview) {
                return "\(selectedFileVideoReference.displayName) will remain external to the package.\(durationDescription) Embedded creation time gives a route offset of \(offsetText)."
            }
            return "\(selectedFileVideoReference.displayName) will remain external to the package.\(durationDescription) No embedded creation time was available for automatic alignment."
        }
        return photosVideoPairingMessage
    }

    var hasSelectedVideo: Bool {
        selectedPhotosVideoReference != nil || selectedFileVideoReference != nil
    }

    private var selectedVideoPackageReference: ASMRRoutePackage.VideoReference? {
        selectedFileVideoReference?.packageReference(relativeTo: routePreview)
            ?? selectedPhotosVideoReference?.packageReference(relativeTo: routePreview)
    }

    private func loadRoutePreview(_ package: ASMRRoutePackage, sourceDescription: String) {
        routePreview = RoutePreview(package: package, sourceDescription: sourceDescription)
        preparedMapBackground = nil
        preparedMapBackgrounds = []
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

    private func messagePreservingPreparedMap(_ message: String) -> String {
        if preparedMapBackgrounds.isEmpty == false {
            return "\(message) All \(preparedMapBackgrounds.count) prepared map segments will also be included."
        }
        guard preparedMapBackground != nil else { return message }
        return "\(message) The prepared map background will also be included."
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
        case photosVideoIdentifierUnavailable

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
            case .photosVideoIdentifierUnavailable:
                "The selected Photos video could not be referenced."
            }
        }
    }
}

extension MacImporterViewModel {
    struct PhotosVideoReference: Equatable {
        let itemIdentifier: String
        let supportedContentTypes: [UTType]
        let metadata: PhotoLibraryVideoMetadata?

        var displayName: String {
            if let typeDescription = supportedContentTypes.first?.localizedDescription,
               typeDescription.isEmpty == false {
                return "Photos video (\(typeDescription))"
            }

            return "Photos video"
        }

        var packageReference: ASMRRoutePackage.VideoReference {
            ASMRRoutePackage.VideoReference(
                kind: .photosAsset,
                displayName: displayName,
                sourceIdentifier: itemIdentifier,
                startsAt: metadata?.creationDate,
                offsetSeconds: nil,
                isEmbedded: false
            )
        }

        func packageReference(relativeTo routePreview: RoutePreview?) -> ASMRRoutePackage.VideoReference {
            ASMRRoutePackage.VideoReference(
                kind: .photosAsset,
                displayName: displayName,
                sourceIdentifier: itemIdentifier,
                startsAt: metadata?.creationDate,
                offsetSeconds: offsetSeconds(relativeTo: routePreview),
                isEmbedded: false
            )
        }

        func offsetText(relativeTo routePreview: RoutePreview?) -> String? {
            guard let offsetSeconds = offsetSeconds(relativeTo: routePreview) else {
                return nil
            }

            return Duration.seconds(offsetSeconds).formatted(.time(pattern: .minuteSecond(padMinuteToLength: 2)))
        }

        private func offsetSeconds(relativeTo routePreview: RoutePreview?) -> TimeInterval? {
            guard let routePreview, let creationDate = metadata?.creationDate else {
                return nil
            }

            return creationDate.timeIntervalSince(routePreview.routeStartedAt)
        }
    }
}

protocol PhotosVideoMetadataLoading: Sendable {
    func metadata(forItemIdentifier itemIdentifier: String) async throws -> PhotoLibraryVideoMetadata
}

struct PhotoLibraryVideoMetadata: Equatable, Sendable {
    let creationDate: Date?
    let duration: TimeInterval
    let latitude: Double?
    let longitude: Double?
}

struct PhotoLibraryVideoMetadataLoader: PhotosVideoMetadataLoading {
    func metadata(forItemIdentifier itemIdentifier: String) async throws -> PhotoLibraryVideoMetadata {
        guard Bundle.main.object(forInfoDictionaryKey: "NSPhotoLibraryUsageDescription") != nil else {
            throw MetadataError.usageDescriptionMissing
        }

        let authorizationStatus = await authorizationStatus()
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            throw MetadataError.authorizationDenied
        }

        let result = PHAsset.fetchAssets(withLocalIdentifiers: [itemIdentifier], options: nil)
        guard let asset = result.firstObject else {
            throw MetadataError.assetNotFound
        }

        return PhotoLibraryVideoMetadata(
            creationDate: asset.creationDate,
            duration: asset.duration,
            latitude: asset.location?.coordinate.latitude,
            longitude: asset.location?.coordinate.longitude
        )
    }

    private func authorizationStatus() async -> PHAuthorizationStatus {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard currentStatus == .notDetermined else {
            return currentStatus
        }

        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }

    enum MetadataError: LocalizedError, Equatable {
        case usageDescriptionMissing
        case authorizationDenied
        case assetNotFound

        var errorDescription: String? {
            switch self {
            case .usageDescriptionMissing:
                "The Mac importer target is missing NSPhotoLibraryUsageDescription."
            case .authorizationDenied:
                "Photos library access was not granted."
            case .assetNotFound:
                "The selected Photos video could not be found in the library."
            }
        }
    }
}
