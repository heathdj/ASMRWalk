//
//  ASMRGPXRouteImporterTests.swift
//  ASMR WalkTests
//

import Foundation
import Testing
@testable import ASMR_Walk

@MainActor
struct ASMRGPXRouteImporterTests {
    @Test("ASMR Walk GPX imports route metadata, points, source GPX, and external video timing")
    func importsASMRWalkGPXMetadata() throws {
        let recordingID = try #require(UUID(uuidString: "F05AE212-17E7-4F17-8EB3-F77968EB9BB6"))
        let recording = WalkRecording(
            id: recordingID,
            title: "Importer Walk",
            createdAt: Date(timeIntervalSince1970: 10_000),
            duration: 180,
            mode: .walk,
            walkDescription: "Canal path near golden hour.",
            recordingSource: .appleWatch,
            captureDeviceName: "Apple Watch Ultra",
            routeStartedAt: Date(timeIntervalSince1970: 10_000),
            routeEndedAt: Date(timeIntervalSince1970: 10_180),
            externalVideoReference: "GoPro clip 0042",
            externalVideoStartedAt: Date(timeIntervalSince1970: 9_995),
            points: [
                makePoint(timestamp: 10_030, latitude: 33.4490, longitude: -112.0728, horizontalAccuracy: 7.5),
                makePoint(timestamp: 10_000, latitude: 33.4484, longitude: -112.0740, altitude: 331.25, horizontalAccuracy: 4.25, speed: 1.5)
            ]
        )
        let gpxText = WalkRouteExport(recording: recording).gpxText

        let package = try ASMRGPXRouteImporter().package(
            fromGPXText: gpxText,
            sourceFilename: "fallback-name.gpx"
        )

        #expect(package.manifest.packageIdentifier == recordingID)
        #expect(package.manifest.title == "Importer Walk")
        #expect(package.manifest.walkDescription == "Canal path near golden hour.")
        #expect(package.manifest.durationSeconds == 180)
        #expect(package.manifest.mode == .walk)
        #expect(package.manifest.recordingSource == .appleWatch)
        #expect(package.manifest.captureDeviceName == "Apple Watch Ultra")
        #expect(package.manifest.sourceGPXFile == ASMRRoutePackage.sourceGPXFilename)
        #expect(package.sourceGPX == gpxText)
        #expect(package.routePoints.map(\.timestamp) == [
            Date(timeIntervalSince1970: 10_000),
            Date(timeIntervalSince1970: 10_030)
        ])
        #expect(package.routePoints.first?.horizontalAccuracy == 4.25)
        #expect(package.routePoints.first?.altitude == 331.25)
        #expect(package.routePoints.first?.speed == 1.5)
        #expect(package.manifest.videoReferences == [
            ASMRRoutePackage.VideoReference(
                kind: .externalCamera,
                displayName: "GoPro clip 0042",
                sourceIdentifier: "GoPro clip 0042",
                startsAt: Date(timeIntervalSince1970: 9_995),
                offsetSeconds: -5,
                isEmbedded: false
            )
        ])
    }

    @Test("Generic GPX imports with conservative fallback metadata")
    func importsGenericGPXWithFallbackMetadata() throws {
        let package = try ASMRGPXRouteImporter(
            now: { Date(timeIntervalSince1970: 123) }
        )
        .package(
            fromGPXText: """
            <?xml version="1.0" encoding="UTF-8"?>
            <gpx version="1.1" creator="Third Party">
              <trk><name>Park Loop</name><trkseg>
                <trkpt lat="33.448400" lon="-112.074000"><time>1970-01-01T00:00:10Z</time></trkpt>
                <trkpt lat="33.449000" lon="-112.072800"><time>1970-01-01T00:00:20Z</time></trkpt>
              </trkseg></trk>
            </gpx>
            """,
            sourceFilename: "third-party.gpx"
        )

        #expect(package.manifest.title == "Park Loop")
        #expect(package.manifest.createdAt == Date(timeIntervalSince1970: 10))
        #expect(package.manifest.durationSeconds == 10)
        #expect(package.manifest.mode == .walk)
        #expect(package.manifest.recordingSource == .iPhone)
        #expect(package.routePoints.count == 2)
        #expect(package.routePoints.allSatisfy { $0.horizontalAccuracy == 0 })
    }

    @Test("GPX without route points fails import")
    func missingRoutePointsFailsImport() throws {
        #expect(throws: ASMRGPXRouteImporter.ImportError.missingRoutePoints) {
            try ASMRGPXRouteImporter().package(
                fromGPXText: """
                <?xml version="1.0" encoding="UTF-8"?>
                <gpx version="1.1"><trk><trkseg></trkseg></trk></gpx>
                """
            )
        }
    }
}
