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

}
