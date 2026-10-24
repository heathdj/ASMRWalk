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

    @Test("Compact extensionless Relive GPX preserves timed route data")
    func importsExtensionlessReliveGPX() throws {
        let package = try ASMRGPXRouteImporter().package(
            fromGPXText: Self.reliveGPXFixture,
            sourceFilename: "Afternoon_Oct_9"
        )

        #expect(package.manifest.title == "Afternoon Oct 9")
        #expect(package.manifest.createdAt == Self.date("2026-10-09T20:24:10.000Z"))
        #expect(package.manifest.routeStartedAt == Self.date("2026-10-09T20:24:10.000Z"))
        #expect(package.manifest.routeEndedAt == Self.date("2026-10-09T20:24:40.000Z"))
        #expect(package.manifest.durationSeconds == 30)
        #expect(package.routePoints.count == 4)
        #expect(package.routePoints.map(\.altitude) == [101.25, 102.5, 103.75, 104])
        #expect(package.routePoints.allSatisfy { $0.horizontalAccuracy == 0 })
        #expect(package.routePoints.allSatisfy { $0.speed == nil })
        let thirdPoint = try #require(package.routePoints.dropFirst(2).first)
        #expect(thirdPoint.timestamp == Self.date("2026-10-09T20:24:25.999Z"))
        #expect(package.sourceGPX == Self.reliveGPXFixture)
    }

    @Test(
        "GPX Export files use filename metadata and preserve equal-time source order",
        .bug("https://github.com/heathdj/ASMRWalk/issues/117")
    )
    func importsUnnamedGPXExportWithStableEqualTimestamps() throws {
        let package = try ASMRGPXRouteImporter().package(
            fromGPXText: Self.gpxExportDuplicateTimestampFixture,
            sourceFilename: "Walking 2026-10-04T185228Z.gpx"
        )

        #expect(package.manifest.title == "Walking 2026-10-04T185228Z")
        #expect(package.manifest.createdAt == Self.wholeSecondDate("2026-10-04T18:31:56Z"))
        #expect(package.manifest.routeStartedAt == Self.wholeSecondDate("2026-10-04T18:31:56Z"))
        #expect(package.manifest.routeEndedAt == Self.wholeSecondDate("2026-10-04T18:31:59Z"))
        #expect(package.manifest.durationSeconds == 3)
        #expect(package.routePoints.map(\.altitude) == [200.123456789, 201.123456789, 202.123456789, 203.123456789])
        #expect(package.routePoints.allSatisfy { $0.horizontalAccuracy == 0 })
        #expect(package.routePoints.allSatisfy { $0.speed == nil })
    }

    @Test(
        "GPX Export timestamp gaps remain in the derived route duration",
        .bug("https://github.com/heathdj/ASMRWalk/issues/117")
    )
    func importsGPXExportWithLongTimestampGap() throws {
        let package = try ASMRGPXRouteImporter().package(
            fromGPXText: Self.gpxExportLongGapFixture,
            sourceFilename: "Walking 2026-10-07T165238Z.gpx"
        )

        #expect(package.manifest.title == "Walking 2026-10-07T165238Z")
        #expect(package.manifest.durationSeconds == 61)
        #expect(package.manifest.routePointCount == 4)
        let secondPoint = try #require(package.routePoints.dropFirst().first)
        let thirdPoint = try #require(package.routePoints.dropFirst(2).first)
        #expect(thirdPoint.timestamp.timeIntervalSince(secondPoint.timestamp) == 59)
    }

    @Test("XML with route-like elements but no GPX root is rejected")
    func rejectsNonGPXXML() {
        #expect(throws: ASMRGPXRouteImporter.ImportError.self) {
            try ASMRGPXRouteImporter().package(
                fromGPXText: "<route><trkpt lat=\"12.3\" lon=\"45.6\"><time>2026-10-09T20:24:10Z</time></trkpt></route>"
            )
        }
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

    private static let reliveGPXFixture = #"<?xml version="1.0" encoding="UTF-8"?><gpx version="1.1" creator="Relive" xmlns="http://www.topografix.com/GPX/1/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd" xmlns:gpxtpx="http://www.garmin.com/xmlschemas/TrackPointExtension/v1" xmlns:gpxx="http://www.garmin.com/xmlschemas/GpxExtensions/v3"><metadata><time>2026-10-09T20:24:10.000Z</time><name>Afternoon Oct 9</name></metadata><trk><trkseg><trkpt lat="12.345100" lon="45.678100"><time>2026-10-09T20:24:10.000Z</time><ele>101.25</ele></trkpt><trkpt lat="12.345200" lon="45.678200"><time>2026-10-09T20:24:11.000Z</time><ele>102.5</ele></trkpt><trkpt lat="12.345300" lon="45.678300"><time>2026-10-09T20:24:25.999Z</time><ele>103.75</ele></trkpt><trkpt lat="12.345400" lon="45.678400"><time>2026-10-09T20:24:40.000Z</time><ele>104</ele></trkpt></trkseg></trk></gpx>"#

    private static let gpxExportDuplicateTimestampFixture = #"<?xml version="1.0" encoding="UTF-8"?><gpx xmlns="http://www.topografix.com/GPX/1/1" version="1.1" creator="GPX Export"><trk><trkseg><trkpt lat="10.001" lon="20.001"><ele>201.123456789</ele><time>2026-10-04T18:31:57Z</time></trkpt><trkpt lat="10.000" lon="20.000"><ele>200.123456789</ele><time>2026-10-04T18:31:56Z</time></trkpt><trkpt lat="10.002" lon="20.002"><ele>202.123456789</ele><time>2026-10-04T18:31:57Z</time></trkpt><trkpt lat="10.003" lon="20.003"><ele>203.123456789</ele><time>2026-10-04T18:31:59Z</time></trkpt></trkseg></trk></gpx>"#

    private static let gpxExportLongGapFixture = #"<?xml version="1.0" encoding="UTF-8"?><gpx xmlns="http://www.topografix.com/GPX/1/1" version="1.1" creator="GPX Export"><trk><trkseg><trkpt lat="30.000" lon="40.000"><ele>300.25</ele><time>2026-10-07T16:46:16Z</time></trkpt><trkpt lat="30.001" lon="40.001"><ele>300.5</ele><time>2026-10-07T16:46:17Z</time></trkpt><trkpt lat="30.002" lon="40.002"><ele>300.75</ele><time>2026-10-07T16:47:16Z</time></trkpt><trkpt lat="30.003" lon="40.003"><ele>301</ele><time>2026-10-07T16:47:17Z</time></trkpt></trkseg></trk></gpx>"#

    private static func date(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: text)
    }

    private static func wholeSecondDate(_ text: String) -> Date? {
        ISO8601DateFormatter().date(from: text)
    }
}
