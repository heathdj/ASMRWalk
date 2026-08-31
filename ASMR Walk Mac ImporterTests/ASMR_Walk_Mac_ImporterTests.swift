//
//  ASMR_Walk_Mac_ImporterTests.swift
//  ASMR Walk Mac ImporterTests
//
//  Created by David Heath on 8/30/26.
//

import Foundation
import Testing
import SwiftData
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
        let start = Date(timeIntervalSince1970: 2_000)
        let package = ASMRRoutePackage(
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

        let preview = RoutePreview(package: package, sourceDescription: "GPX file: Preview.gpx")

        #expect(preview.id == package.manifest.packageIdentifier)
        #expect(preview.title == "Preview Route")
        #expect(preview.sourceDescription == "GPX file: Preview.gpx")
        #expect(preview.routePointCount == 2)
    }

    @Test func exportWithoutLoadedRouteReportsFailure() {
        let viewModel = MacImporterViewModel()

        #expect(throws: MacImporterViewModel.ImportError.noRouteLoaded) {
            try viewModel.exportLoadedRoute()
        }
    }

}
