//
//  ASMRRoutePackageTests.swift
//  ASMR WalkTests
//

import Foundation
import Testing
@testable import ASMR_Walk

@MainActor
struct ASMRRoutePackageTests {
    @Test(".asmrroute packages round-trip manifest, route points, and source GPX")
    func packageRoundTrip() throws {
        let recordingID = try #require(UUID(uuidString: "C9D171A2-B9E4-45A7-8BE8-D6120F9761C7"))
        let routeStartedAt = Date(timeIntervalSince1970: 1_000)
        let recording = WalkRecording(
            id: recordingID,
            title: "Package Walk",
            createdAt: routeStartedAt,
            duration: 120,
            distanceMeters: 345.5,
            mode: .walk,
            recordingSource: .appleWatch,
            captureDeviceName: "Apple Watch",
            routeStartedAt: routeStartedAt,
            routeEndedAt: routeStartedAt.addingTimeInterval(120),
            externalVideoReference: "A-cam clip",
            externalVideoStartedAt: routeStartedAt.addingTimeInterval(-3),
            points: [
                makePoint(timestamp: 1_020, latitude: 33.4490, longitude: -112.0728),
                makePoint(timestamp: 1_000, latitude: 33.4484, longitude: -112.0740, altitude: 331.25)
            ]
        )
        let export = WalkRouteExport(recording: recording)
        let package = ASMRRoutePackage(export: export, sourceGPX: export.gpxText)
        let packageURL = ASMRRoutePackage.packageURL(
            forTitle: recording.title,
            in: FileManager.default.temporaryDirectory
        )
        defer {
            try? FileManager.default.removeItem(at: packageURL)
        }

        try package.write(to: packageURL)
        let loaded = try ASMRRoutePackage.load(from: packageURL)

        #expect(loaded == package)
        #expect(loaded.manifest.schemaVersion == 1)
        #expect(loaded.manifest.packageIdentifier == recordingID)
        #expect(loaded.manifest.recordingSource == .appleWatch)
        #expect(loaded.manifest.distanceMeters == 345.5)
        #expect(loaded.manifest.routePointCount == 2)
        #expect(loaded.routePoints.map(\.timestamp) == [
            Date(timeIntervalSince1970: 1_000),
            Date(timeIntervalSince1970: 1_020)
        ])
        #expect(loaded.sourceGPX?.contains("<gpx version=\"1.1\"") == true)
        #expect(loaded.manifest.videoReferences.contains {
            $0.kind == .externalCamera && $0.offsetSeconds == -3
        })
    }

    @Test(".asmrroute manifest can represent non-embedded Photos video references")
    func packageManifestRepresentsPhotosVideoReferences() throws {
        let recording = WalkRecording(
            title: "Video Package",
            createdAt: Date(timeIntervalSince1970: 2_000),
            duration: 30,
            mode: .videoWalk,
            videoAssetIdentifier: "photos-local-id",
            points: [
                makePoint(timestamp: 2_000),
                makePoint(timestamp: 2_010)
            ]
        )
        let photosReference = ASMRRoutePackage.VideoReference(
            kind: .photosAsset,
            displayName: "Photos video selected on Mac",
            sourceIdentifier: "photos-local-id",
            startsAt: Date(timeIntervalSince1970: 2_000),
            offsetSeconds: 0,
            isEmbedded: false
        )

        let package = ASMRRoutePackage(
            export: WalkRouteExport(recording: recording),
            videoReferences: [photosReference]
        )

        #expect(package.manifest.videoReferences == [photosReference])
        #expect(package.manifest.videoReferences.first?.isEmbedded == false)
        #expect(package.manifest.routePointsFile == ASMRRoutePackage.routePointsFilename)
        #expect(package.manifest.sourceGPXFile == nil)
    }

    @Test(".asmrroute loader rejects unsupported schema versions")
    func unsupportedSchemaVersionFailsLoad() throws {
        var manifest = ASMRRoutePackage.Manifest(
            packageIdentifier: UUID(),
            title: "Future Package",
            createdAt: Date(timeIntervalSince1970: 1),
            durationSeconds: 10,
            distanceMeters: 20,
            mode: .walk,
            recordingSource: .iPhone,
            captureDeviceName: nil,
            routeStartedAt: Date(timeIntervalSince1970: 1),
            routeEndedAt: Date(timeIntervalSince1970: 11),
            routePointCount: 0,
            sourceGPXFile: nil,
            videoReferences: []
        )
        manifest.schemaVersion = 999
        let package = ASMRRoutePackage(manifest: manifest, routePoints: [])
        let packageURL = ASMRRoutePackage.packageURL(
            forTitle: "Future Package",
            in: FileManager.default.temporaryDirectory
        )
        defer {
            try? FileManager.default.removeItem(at: packageURL)
        }

        try package.write(to: packageURL)

        #expect(throws: ASMRRoutePackage.PackageError.unsupportedSchemaVersion(999)) {
            try ASMRRoutePackage.load(from: packageURL)
        }
    }
}
