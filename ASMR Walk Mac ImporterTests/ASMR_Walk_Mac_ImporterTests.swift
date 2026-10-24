//
//  ASMR_Walk_Mac_ImporterTests.swift
//  ASMR Walk Mac ImporterTests
//
//  Created by David Heath on 8/30/26.
//

import Foundation
import Testing
import SwiftData
import UniformTypeIdentifiers
@testable import ASMR_Walk_Mac_Importer

@MainActor
struct ASMR_Walk_Mac_ImporterTests {

    @Test func cloudSyncUsesASMRWalkContainer() {
        #expect(CloudSyncConfiguration.containerIdentifier == "iCloud.com.bald-traveler.ASMRWalk")
    }

    @Test func inMemoryModelContainerCanStoreSyncedRecordingSchema() throws {
        let container = try MacModelContainerFactory.makeModelContainer(inMemory: true)
        let context = ModelContext(container)
        let recording = WalkRecording(
            title: "Morning Walk",
            createdAt: Date(timeIntervalSince1970: 100),
            duration: 60,
            distanceMeters: 120,
            mode: .walk,
            points: [
                LocationPoint(
                    timestamp: Date(timeIntervalSince1970: 101),
                    latitude: 40,
                    longitude: -74,
                    horizontalAccuracy: 5
                )
            ]
        )

        context.insert(recording)
        try context.save()

        let descriptor = FetchDescriptor<WalkRecording>()
        let recordings = try context.fetch(descriptor)

        #expect(recordings.count == 1)
        #expect(recordings.first?.displayTitle == "Morning Walk")
        #expect(recordings.first?.points.count == 1)
    }

    @Test func routePackageFromSyncedRecordingDoesNotRequireSourceGPX() {
        let start = Date(timeIntervalSince1970: 1_000)
        let recording = WalkRecording(
            id: UUID(uuidString: "B3E87B3F-CF9C-499E-8714-F62D2CE172F8")!,
            title: "Synced Watch Walk",
            createdAt: start,
            duration: 120,
            distanceMeters: 300,
            mode: .walk,
            walkDescription: "Imported from iCloud.",
            recordingSource: .appleWatch,
            routeStartedAt: start,
            routeEndedAt: start.addingTimeInterval(120),
            points: [
                LocationPoint(
                    timestamp: start.addingTimeInterval(60),
                    latitude: 36.12,
                    longitude: -86.67,
                    altitude: 190,
                    horizontalAccuracy: 4,
                    speed: 1.2
                ),
                LocationPoint(
                    timestamp: start,
                    latitude: 36.11,
                    longitude: -86.66,
                    horizontalAccuracy: 5
                )
            ]
        )

        let package = ASMRRoutePackage(recording: recording)

        #expect(package.manifest.title == "Synced Watch Walk")
        #expect(package.manifest.recordingSource == .appleWatch)
        #expect(package.manifest.routePointCount == 2)
        #expect(package.manifest.sourceGPXFile == nil)
        #expect(package.sourceGPX == nil)
        #expect(package.routePoints.map(\.timestamp) == [start, start.addingTimeInterval(60)])
    }

    @Test func routePreviewSummarizesLoadedPackage() {
        let package = makeRoutePackage()

        let preview = RoutePreview(package: package, sourceDescription: "GPX file: Preview.gpx")

        #expect(preview.id == package.manifest.packageIdentifier)
        #expect(preview.title == "Preview Route")
        #expect(preview.sourceDescription == "GPX file: Preview.gpx")
        #expect(preview.routePointCount == 2)
    }

    @Test func deletingPreviewPointOnlyChangesPendingExport() throws {
        let package = makeRoutePackage()
        var preview = RoutePreview(package: package, sourceDescription: "GPX file: Preview.gpx")
        let pointToDelete = try #require(preview.routePoints.first)

        let deletedPoint = preview.deletePoint(id: pointToDelete.id)
        let exportPackage = preview.exportPackage

        #expect(deletedPoint?.sourceIndex == pointToDelete.sourceIndex)
        #expect(preview.routePointCount == 1)
        #expect(preview.removedPointCount == 1)
        #expect(preview.hasPointEdits)
        #expect(package.routePoints.count == 2)
        #expect(exportPackage.manifest.routePointCount == 1)
        #expect(exportPackage.routePoints.count == 1)
        #expect(exportPackage.routePoints.first?.timestamp == package.routePoints.last?.timestamp)
    }

    @Test func previewCannotDeleteLastRoutePoint() throws {
        var preview = RoutePreview(package: makeRoutePackage(), sourceDescription: "GPX file: Preview.gpx")
        let firstPoint = try #require(preview.routePoints.first)
        _ = preview.deletePoint(id: firstPoint.id)
        let remainingPoint = try #require(preview.routePoints.first)

        let deletedPoint = preview.deletePoint(id: remainingPoint.id)

        #expect(deletedPoint == nil)
        #expect(preview.routePointCount == 1)
    }

    @Test func resetPreviewEditsRestoresOriginalPoints() throws {
        var preview = RoutePreview(package: makeRoutePackage(), sourceDescription: "GPX file: Preview.gpx")
        let firstPoint = try #require(preview.routePoints.first)
        _ = preview.deletePoint(id: firstPoint.id)

        preview.resetEdits()

        #expect(preview.routePointCount == 2)
        #expect(preview.removedPointCount == 0)
        #expect(preview.hasPointEdits == false)
    }

    @Test func routePreviewExportIncludesPairedPhotosVideoReference() throws {
        let preview = RoutePreview(package: makeRoutePackage(), sourceDescription: "GPX file: Preview.gpx")
        let photosReference = MacImporterViewModel.PhotosVideoReference(
            itemIdentifier: "B96D04C5-3D04-4C6B-9FF7-2B5B307526D5/L0/001",
            supportedContentTypes: [.quickTimeMovie],
            metadata: nil
        )

        let exportPackage = preview.exportPackage(photosVideoReference: photosReference.packageReference)
        let videoReference = try #require(exportPackage.manifest.videoReferences.first)

        #expect(exportPackage.manifest.videoReferences.count == 1)
        #expect(videoReference.kind == .photosAsset)
        #expect(videoReference.displayName.contains("Photos video"))
        #expect(videoReference.sourceIdentifier == "B96D04C5-3D04-4C6B-9FF7-2B5B307526D5/L0/001")
        #expect(videoReference.startsAt == nil)
        #expect(videoReference.offsetSeconds == nil)
        #expect(videoReference.isEmbedded == false)
    }

    @Test func pairedPhotosVideoReferenceReplacesExistingPhotosReference() throws {
        let originalPackage = makeRoutePackage()
        var manifest = originalPackage.manifest
        manifest.videoReferences = [
            ASMRRoutePackage.VideoReference(
                kind: .photosAsset,
                displayName: "Old Photos video",
                sourceIdentifier: "old-identifier",
                startsAt: nil,
                offsetSeconds: nil,
                isEmbedded: false
            )
        ]
        let package = ASMRRoutePackage(
            manifest: manifest,
            routePoints: originalPackage.routePoints,
            sourceGPX: originalPackage.sourceGPX
        )
        let preview = RoutePreview(package: package, sourceDescription: "GPX file: Preview.gpx")
        let photosReference = MacImporterViewModel.PhotosVideoReference(
            itemIdentifier: "new-identifier",
            supportedContentTypes: [.movie],
            metadata: nil
        )

        let exportPackage = preview.exportPackage(photosVideoReference: photosReference.packageReference)
        let videoReference = try #require(exportPackage.manifest.videoReferences.first)

        #expect(exportPackage.manifest.videoReferences.count == 1)
        #expect(videoReference.sourceIdentifier == "new-identifier")
    }

    @Test func routePreviewExportIncludesPhotosVideoTimingOffset() throws {
        let routeStart = Date(timeIntervalSince1970: 2_000)
        let preview = RoutePreview(package: makeRoutePackage(), sourceDescription: "GPX file: Preview.gpx")
        let photosReference = MacImporterViewModel.PhotosVideoReference(
            itemIdentifier: "timed-video",
            supportedContentTypes: [.movie],
            metadata: PhotoLibraryVideoMetadata(
                creationDate: routeStart.addingTimeInterval(-12),
                duration: 96,
                latitude: 36.11,
                longitude: -86.66
            )
        )

        let exportPackage = preview.exportPackage(photosVideoReference: photosReference.packageReference(relativeTo: preview))
        let videoReference = try #require(exportPackage.manifest.videoReferences.first)

        #expect(videoReference.startsAt == routeStart.addingTimeInterval(-12))
        #expect(videoReference.offsetSeconds == -12)
    }

    @Test func photosVideoSelectionWithoutIdentifierReportsFailure() async {
        let viewModel = MacImporterViewModel()

        await viewModel.pairPhotosVideo(itemIdentifier: nil, supportedContentTypes: [.movie])

        #expect(viewModel.selectedPhotosVideoReference == nil)
        #expect(viewModel.statusTitle == "Import Failed")
        #expect(viewModel.statusMessage == MacImporterViewModel.ImportError.photosVideoIdentifierUnavailable.localizedDescription)
    }

    @Test func exportWithoutLoadedRouteReportsFailure() {
        let viewModel = MacImporterViewModel()

        #expect(throws: MacImporterViewModel.ImportError.noRouteLoaded) {
            try viewModel.exportLoadedRoute()
        }
    }

    @Test("Extensionless Relive GPX imports and writes a readable route package")
    func importsExtensionlessReliveGPX() throws {
        let package = try ASMRGPXRouteImporter().package(
            fromGPXText: Self.reliveGPXFixture,
            sourceFilename: "Afternoon_Oct_9"
        )
        let packageURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appendingPathExtension(ASMRRoutePackage.fileExtension)
        defer { try? FileManager.default.removeItem(at: packageURL) }

        try package.write(to: packageURL)
        let loadedPackage = try ASMRRoutePackage.load(from: packageURL)

        #expect(UTType.supportedGPXImportTypes.contains(.data))
        #expect(loadedPackage.manifest.title == "Afternoon Oct 9")
        #expect(loadedPackage.manifest.durationSeconds == 30)
        #expect(loadedPackage.manifest.routePointCount == 4)
        #expect(loadedPackage.routePoints.map(\.altitude) == [101.25, 102.5, 103.75, 104])
        #expect(loadedPackage.routePoints.allSatisfy { $0.horizontalAccuracy == 0 })
        #expect(loadedPackage.routePoints.allSatisfy { $0.speed == nil })
        #expect(loadedPackage.sourceGPX == Self.reliveGPXFixture)
    }

    @Test(
        "GPX Export package round-trip preserves filename metadata and equal-time source order",
        .bug("https://github.com/heathdj/ASMRWalk/issues/117")
    )
    func importsAndWritesUnnamedGPXExport() throws {
        let package = try ASMRGPXRouteImporter().package(
            fromGPXText: Self.gpxExportDuplicateTimestampFixture,
            sourceFilename: "Walking 2026-10-04T185228Z.gpx"
        )
        let packageURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appendingPathExtension(ASMRRoutePackage.fileExtension)
        defer { try? FileManager.default.removeItem(at: packageURL) }

        try package.write(to: packageURL)
        let loadedPackage = try ASMRRoutePackage.load(from: packageURL)

        #expect(loadedPackage.manifest.title == "Walking 2026-10-04T185228Z")
        #expect(loadedPackage.manifest.durationSeconds == 3)
        #expect(loadedPackage.manifest.routePointCount == 4)
        #expect(loadedPackage.routePoints.map(\.altitude) == [200.123456789, 201.123456789, 202.123456789, 203.123456789])
        #expect(loadedPackage.routePoints.allSatisfy { $0.horizontalAccuracy == 0 })
        #expect(loadedPackage.routePoints.allSatisfy { $0.speed == nil })
    }

    private func makeRoutePackage() -> ASMRRoutePackage {
        let start = Date(timeIntervalSince1970: 2_000)
        return ASMRRoutePackage(
            manifest: ASMRRoutePackage.Manifest(
                packageIdentifier: UUID(uuidString: "48DB6037-9676-46F8-A272-E029A1E96F66")!,
                title: "Preview Route",
                walkDescription: nil,
                createdAt: start,
                durationSeconds: 90,
                distanceMeters: 450,
                mode: .walk,
                recordingSource: .iPhone,
                captureDeviceName: nil,
                routeStartedAt: start,
                routeEndedAt: start.addingTimeInterval(90),
                routePointCount: 2,
                sourceGPXFile: nil,
                videoReferences: []
            ),
            routePoints: [
                ASMRRoutePackage.RoutePoint(
                    timestamp: start,
                    latitude: 36.11,
                    longitude: -86.66,
                    altitude: nil,
                    horizontalAccuracy: 5,
                    speed: nil
                ),
                ASMRRoutePackage.RoutePoint(
                    timestamp: start.addingTimeInterval(90),
                    latitude: 36.12,
                    longitude: -86.67,
                    altitude: nil,
                    horizontalAccuracy: 4,
                    speed: nil
                )
            ]
        )
    }

    private static let reliveGPXFixture = #"<?xml version="1.0" encoding="UTF-8"?><gpx version="1.1" creator="Relive" xmlns="http://www.topografix.com/GPX/1/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd" xmlns:gpxtpx="http://www.garmin.com/xmlschemas/TrackPointExtension/v1" xmlns:gpxx="http://www.garmin.com/xmlschemas/GpxExtensions/v3"><metadata><time>2026-10-09T20:24:10.000Z</time><name>Afternoon Oct 9</name></metadata><trk><trkseg><trkpt lat="12.345100" lon="45.678100"><time>2026-10-09T20:24:10.000Z</time><ele>101.25</ele></trkpt><trkpt lat="12.345200" lon="45.678200"><time>2026-10-09T20:24:11.000Z</time><ele>102.5</ele></trkpt><trkpt lat="12.345300" lon="45.678300"><time>2026-10-09T20:24:25.999Z</time><ele>103.75</ele></trkpt><trkpt lat="12.345400" lon="45.678400"><time>2026-10-09T20:24:40.000Z</time><ele>104</ele></trkpt></trkseg></trk></gpx>"#

    private static let gpxExportDuplicateTimestampFixture = #"<?xml version="1.0" encoding="UTF-8"?><gpx xmlns="http://www.topografix.com/GPX/1/1" version="1.1" creator="GPX Export"><trk><trkseg><trkpt lat="10.001" lon="20.001"><ele>201.123456789</ele><time>2026-10-04T18:31:57Z</time></trkpt><trkpt lat="10.000" lon="20.000"><ele>200.123456789</ele><time>2026-10-04T18:31:56Z</time></trkpt><trkpt lat="10.002" lon="20.002"><ele>202.123456789</ele><time>2026-10-04T18:31:57Z</time></trkpt><trkpt lat="10.003" lon="20.003"><ele>203.123456789</ele><time>2026-10-04T18:31:59Z</time></trkpt></trkseg></trk></gpx>"#

}
