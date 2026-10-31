//
//  ASMR_Walk_Route_OverlayTests.swift
//  ASMR Walk Route OverlayTests
//

import Foundation
import Testing

struct ASMRRouteOverlayRenderPlanTests {
    @Test("Map style converts normalized position and size to output pixels", .bug("https://github.com/heathdj/ASMRWalk/issues/123"))
    func mapStyleProducesExpectedPixelRect() {
        let style = ASMRRouteOverlayMapStyle(
            centerX: 0.75,
            centerY: 0.25,
            widthFraction: 0.4,
            heightFraction: 0.5,
            cornerRadiusFraction: 0.1,
            opacity: 0.75
        )

        let rect = style.pixelRect(outputWidth: 1_000, outputHeight: 800)

        #expect(rect.originX == 550)
        #expect(rect.originY == 0)
        #expect(rect.width == 400)
        #expect(rect.height == 400)
    }

    @Test("Stored map bounds project Web Mercator coordinates deterministically", .bug("https://github.com/heathdj/ASMRWalk/issues/123"))
    func storedMapBoundsProjectCoordinates() {
        let background = ASMRRoutePackageInput.MapBackground(
            filename: "map-background.png",
            pixelWidth: 1_280,
            pixelHeight: 720,
            scale: 1,
            mapRectOriginX: 0,
            mapRectOriginY: 0,
            mapRectWidth: 268_435_456,
            mapRectHeight: 268_435_456
        )

        let center = ASMRRouteMapProjection.normalizedPoint(
            latitude: 0,
            longitude: 0,
            mapBackground: background
        )
        let northWest = ASMRRouteMapProjection.normalizedPoint(
            latitude: 85.051_128_78,
            longitude: -180,
            mapBackground: background
        )

        #expect(abs(center.x - 0.5) < 0.000_001)
        #expect(abs(center.y - 0.5) < 0.000_001)
        #expect(abs(northWest.x) < 0.000_001)
        #expect(abs(northWest.y) < 0.000_001)
    }

    @Test("Non-square map bounds preserve high-latitude Web Mercator projection", .bug("https://github.com/heathdj/ASMRWalk/issues/123"))
    func nonSquareHighLatitudeProjection() {
        let worldWidth = 268_435_456.0
        let background = ASMRRoutePackageInput.MapBackground(
            filename: "map-background.png",
            pixelWidth: 1_280,
            pixelHeight: 720,
            scale: 1,
            mapRectOriginX: 0,
            mapRectOriginY: 0,
            mapRectWidth: worldWidth,
            mapRectHeight: worldWidth / 2
        )

        let point = ASMRRouteMapProjection.normalizedPoint(
            latitude: 60,
            longitude: 90,
            mapBackground: background
        )
        let latitudeRadians = 60.0 * Double.pi / 180
        let expectedY = 1 - (log(tan(latitudeRadians) + (1 / cos(latitudeRadians))) / Double.pi)

        #expect(abs(point.x - 0.75) < 0.000_001)
        #expect(abs(point.y - expectedY) < 0.000_001)
    }

    @Test("Map availability distinguishes valid, missing, and unsupported assets", .bug("https://github.com/heathdj/ASMRWalk/issues/123"))
    func mapAssetAvailability() throws {
        let original = makeRoutePackage()
        var manifest = original.manifest
        manifest.mapBackground = ASMRRoutePackageInput.MapBackground(
            filename: "map-background.png",
            pixelWidth: 1,
            pixelHeight: 1,
            scale: 1,
            mapRectOriginX: 0,
            mapRectOriginY: 0,
            mapRectWidth: 1,
            mapRectHeight: 1
        )
        let png = try #require(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="))
        let gif = try #require(Data(base64Encoded: "R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw=="))

        let valid = ASMRRoutePackageInput(manifest: manifest, routePoints: original.routePoints, mapBackgroundData: png)
        let missing = ASMRRoutePackageInput(manifest: manifest, routePoints: original.routePoints)
        let unsupported = ASMRRoutePackageInput(manifest: manifest, routePoints: original.routePoints, mapBackgroundData: gif)

        #expect(valid.mapAvailability == .available)
        #expect(missing.mapAvailability == .unusable)
        #expect(unsupported.mapAvailability == .unusable)
        #expect(unsupported.mapAvailability.statusMessage.contains("unsupported"))
    }

    @Test("Schema-one package reports route-only map availability", .bug("https://github.com/heathdj/ASMRWalk/issues/123"))
    func routeOnlyMapAvailability() {
        #expect(makeRoutePackage().mapAvailability == .routeOnly)
    }

    @Test("Segment selection follows route timestamps at boundaries", .bug("https://github.com/heathdj/ASMRWalk/issues/128"))
    func segmentedMapSelection() {
        let package = makeRoutePackage()
        let start = package.manifest.routeStartedAt
        let firstBitmap = ASMRRouteOverlayBitmap(width: 1, height: 1, rgbaPixels: [1, 2, 3, 255])
        let secondBitmap = ASMRRouteOverlayBitmap(width: 1, height: 1, rgbaPixels: [4, 5, 6, 255])
        let worldWidth = 268_435_456.0
        let backgrounds = [
            ASMRRoutePackageInput.DecodedMapBackground(
                metadata: .init(
                    filename: "map-background-001.png",
                    pixelWidth: 1,
                    pixelHeight: 1,
                    scale: 1,
                    mapRectOriginX: 0,
                    mapRectOriginY: 0,
                    mapRectWidth: worldWidth,
                    mapRectHeight: worldWidth,
                    firstRoutePointIndex: 0,
                    lastRoutePointIndex: 1,
                    startTimestamp: start,
                    endTimestamp: start.addingTimeInterval(10)
                ),
                bitmap: firstBitmap
            ),
            ASMRRoutePackageInput.DecodedMapBackground(
                metadata: .init(
                    filename: "map-background-002.png",
                    pixelWidth: 1,
                    pixelHeight: 1,
                    scale: 1,
                    mapRectOriginX: 0,
                    mapRectOriginY: 0,
                    mapRectWidth: worldWidth,
                    mapRectHeight: worldWidth,
                    firstRoutePointIndex: 1,
                    lastRoutePointIndex: 2,
                    startTimestamp: start.addingTimeInterval(10),
                    endTimestamp: start.addingTimeInterval(20)
                ),
                bitmap: secondBitmap
            )
        ]

        let firstPlan = ASMRRouteOverlayRenderPlan.make(
            from: package,
            renderTimeSeconds: 9.9,
            preparedMapBackgrounds: backgrounds,
            usesPreparedMapBackground: true
        )
        let boundaryPlan = ASMRRouteOverlayRenderPlan.make(
            from: package,
            renderTimeSeconds: 10,
            preparedMapBackgrounds: backgrounds,
            usesPreparedMapBackground: true
        )
        let finalPlan = ASMRRouteOverlayRenderPlan.make(
            from: package,
            renderTimeSeconds: 20,
            preparedMapBackgrounds: backgrounds,
            usesPreparedMapBackground: true
        )

        #expect(firstPlan.mapBackground == firstBitmap)
        #expect(boundaryPlan.mapBackground == firstBitmap)
        #expect(finalPlan.mapBackground == secondBitmap)
    }

    @Test("Corrupt map data falls back to the route-only plan", .bug("https://github.com/heathdj/ASMRWalk/issues/123"))
    func corruptMapFallsBackToRouteOnly() {
        let original = makeRoutePackage()
        var manifest = original.manifest
        manifest.mapBackground = ASMRRoutePackageInput.MapBackground(
            filename: "map-background.png",
            pixelWidth: 100,
            pixelHeight: 100,
            scale: 1,
            mapRectOriginX: 0,
            mapRectOriginY: 0,
            mapRectWidth: 1,
            mapRectHeight: 1
        )
        let package = ASMRRoutePackageInput(
            manifest: manifest,
            routePoints: original.routePoints,
            mapBackgroundData: Data("not a png".utf8)
        )

        let plan = ASMRRouteOverlayRenderPlan.make(from: package, renderTimeSeconds: 10)

        #expect(plan.mapBackground == nil)
        #expect(plan.routePoints.isEmpty == false)
    }

    @Test("Prepared package cache reuses state and invalidates when route data changes", .bug("https://github.com/heathdj/ASMRWalk/issues/123"))
    func packageCacheReusesAndInvalidates() throws {
        let package = makeRoutePackage()
        let packageURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: packageURL) }
        try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let manifestURL = packageURL.appending(path: ASMRRoutePackageInput.manifestFilename)
        let routeURL = packageURL.appending(path: package.manifest.routePointsFile)
        try encoder.encode(package.manifest).write(to: manifestURL)
        try encoder.encode(package.routePoints).write(to: routeURL)
        let cache = ASMRRouteOverlayPackageCache()

        _ = try cache.preparedPackage(at: packageURL)
        _ = try cache.preparedPackage(at: packageURL)
        #expect(cache.loadCount == 1)

        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(10)],
            ofItemAtPath: routeURL.path
        )
        _ = try cache.preparedPackage(at: packageURL)
        #expect(cache.loadCount == 2)
    }

    @Test("Segment cache invalidates when one PNG changes and reports partial fallback", .bug("https://github.com/heathdj/ASMRWalk/issues/128"))
    func segmentedPackageCacheInvalidation() throws {
        let original = makeRoutePackage()
        let start = original.manifest.routeStartedAt
        let metadata: [ASMRRoutePackageInput.MapBackground] = [0, 1].map { index in
            .init(
                filename: String(format: "map-background-%03d.png", index + 1),
                pixelWidth: 1,
                pixelHeight: 1,
                scale: 1,
                mapRectOriginX: 0,
                mapRectOriginY: 0,
                mapRectWidth: 268_435_456,
                mapRectHeight: 268_435_456,
                firstRoutePointIndex: index,
                lastRoutePointIndex: index + 1,
                startTimestamp: start.addingTimeInterval(Double(index * 10)),
                endTimestamp: start.addingTimeInterval(Double((index + 1) * 10))
            )
        }
        var manifest = original.manifest
        manifest.mapBackgrounds = metadata
        let packageURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: packageURL) }
        try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(manifest).write(to: packageURL.appending(path: ASMRRoutePackageInput.manifestFilename))
        try encoder.encode(original.routePoints).write(to: packageURL.appending(path: manifest.routePointsFile))
        let png = try #require(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="))
        try png.write(to: packageURL.appending(path: metadata[0].filename))
        try png.write(to: packageURL.appending(path: metadata[1].filename))
        let cache = ASMRRouteOverlayPackageCache()

        let complete = try cache.preparedPackage(at: packageURL)
        #expect(complete.mapAvailability == .segmented(available: 2, total: 2))
        _ = try cache.preparedPackage(at: packageURL)
        #expect(cache.loadCount == 1)

        let secondURL = packageURL.appending(path: metadata[1].filename)
        try Data("corrupt".utf8).write(to: secondURL)
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(10)],
            ofItemAtPath: secondURL.path
        )
        let degraded = try cache.preparedPackage(at: packageURL)

        #expect(cache.loadCount == 2)
        #expect(degraded.mapAvailability == .segmented(available: 1, total: 2))
        #expect(degraded.mapAvailability.statusMessage.contains("degraded"))
    }

    @Test("Route progress interpolates from package timestamps", .bug("https://github.com/heathdj/ASMRWalk/issues/77"))
    func routeProgressInterpolatesFromPackageTimestamps() throws {
        let routePackage = makeRoutePackage()

        let plan = ASMRRouteOverlayRenderPlan.make(
            from: routePackage,
            renderTimeSeconds: 5
        )

        #expect(plan.routePoints == [
            .init(x: 0, y: 0.75),
            .init(x: 0.5, y: 0.25),
            .init(x: 1, y: 0.75)
        ])
        #expect(plan.visibleRoutePoints == [
            .init(x: 0, y: 0.75),
            .init(x: 0.25, y: 0.5)
        ])
        #expect(plan.currentPosition == .init(x: 0.25, y: 0.5))
        #expect(plan.startPosition == .init(x: 0, y: 0.75))
        #expect(plan.endPosition == .init(x: 1, y: 0.75))
    }

    @Test("Render time is clamped to the route duration", arguments: [-5.0, 25.0])
    func renderTimeIsClamped(_ renderTime: TimeInterval) throws {
        let routePackage = makeRoutePackage()

        let plan = ASMRRouteOverlayRenderPlan.make(
            from: routePackage,
            renderTimeSeconds: renderTime
        )

        if renderTime < 0 {
            #expect(plan.visibleRoutePoints == [.init(x: 0, y: 0.75)])
            #expect(plan.currentPosition == .init(x: 0, y: 0.75))
        } else {
            #expect(plan.visibleRoutePoints == plan.routePoints)
            #expect(plan.currentPosition == .init(x: 1, y: 0.75))
        }
    }

    @Test("Marker visibility settings are reflected in the render plan")
    func markerVisibilitySettingsAreReflectedInPlan() {
        let plan = ASMRRouteOverlayRenderPlan.make(
            from: makeRoutePackage(),
            renderTimeSeconds: 10,
            showCurrentPosition: false,
            showStartEndMarkers: false
        )

        #expect(plan.currentPosition == nil)
        #expect(plan.startPosition == nil)
        #expect(plan.endPosition == nil)
        #expect(plan.visibleRoutePoints.count == 2)
    }

    @Test("Clip-duration timing maps the full route onto the host effect")
    func clipDurationTimingMapsRouteOntoEffect() {
        let plan = ASMRRouteOverlayRenderPlan.make(
            from: makeRoutePackage(),
            renderTimeSeconds: 120,
            effectStartSeconds: 100,
            effectDurationSeconds: 40,
            timingMode: .clipDuration
        )

        #expect(plan.currentPosition == .init(x: 0.5, y: 0.25))
        #expect(plan.visibleRoutePoints.count == 2)
    }

    @Test("GPX timing uses timestamp seconds independently of effect duration")
    func gpxTimingUsesTimestampSeconds() {
        let plan = ASMRRouteOverlayRenderPlan.make(
            from: makeRoutePackage(),
            renderTimeSeconds: 105,
            effectStartSeconds: 100,
            effectDurationSeconds: 200,
            timingMode: .routeTimestamps
        )

        #expect(plan.currentPosition == .init(x: 0.25, y: 0.5))
        #expect(plan.visibleRoutePoints.count == 2)
    }

    @Test(
        "Equal timestamps resolve to the last source point without a backward segment",
        .bug("https://github.com/heathdj/ASMRWalk/issues/117")
    )
    func equalTimestampsResolveToLastSourcePoint() {
        let routePackage = makeRoutePackage(coordinates: [
            (latitude: 0, longitude: 0, seconds: 0),
            (latitude: 0, longitude: 10, seconds: 10),
            (latitude: 10, longitude: 10, seconds: 10),
            (latitude: 10, longitude: 20, seconds: 20)
        ])

        let firstPlan = ASMRRouteOverlayRenderPlan.make(
            from: routePackage,
            renderTimeSeconds: 10,
            timingMode: .routeTimestamps
        )
        let secondPlan = ASMRRouteOverlayRenderPlan.make(
            from: routePackage,
            renderTimeSeconds: 10,
            timingMode: .routeTimestamps
        )

        #expect(firstPlan == secondPlan)
        #expect(firstPlan.visibleRoutePoints == [
            .init(x: 0, y: 0.75),
            .init(x: 0.5, y: 0.75),
            .init(x: 0.5, y: 0.25)
        ])
        #expect(firstPlan.currentPosition == .init(x: 0.5, y: 0.25))
    }

    @Test(
        "GPX timestamp mode retains a long interval between source points",
        .bug("https://github.com/heathdj/ASMRWalk/issues/117")
    )
    func gpxTimestampModeRetainsLongGap() throws {
        let routePackage = makeRoutePackage(coordinates: [
            (latitude: 0, longitude: 0, seconds: 0),
            (latitude: 0, longitude: 10, seconds: 1),
            (latitude: 0, longitude: 20, seconds: 60),
            (latitude: 0, longitude: 30, seconds: 61)
        ])

        let plan = ASMRRouteOverlayRenderPlan.make(
            from: routePackage,
            renderTimeSeconds: 30,
            timingMode: .routeTimestamps
        )
        let currentPosition = try #require(plan.currentPosition)
        let expectedX = (1.0 / 3.0) + ((1.0 / 3.0) * (29.0 / 59.0))

        #expect(currentPosition.x.isFinite)
        #expect(currentPosition.y.isFinite)
        #expect(abs(currentPosition.x - expectedX) < 0.000_001)
        #expect(currentPosition.y == 0.5)
        #expect(plan.visibleRoutePoints.count == 3)
    }

    @Test("Long routes are reduced to a deterministic point budget")
    func longRoutesAreReducedToPointBudget() throws {
        let coordinates = (0..<10_000).map { index in
            (latitude: Double(index % 17), longitude: Double(index), seconds: TimeInterval(index))
        }
        let routePackage = makeRoutePackage(coordinates: coordinates)

        let firstPlan = ASMRRouteOverlayRenderPlan.make(
            from: routePackage,
            renderTimeSeconds: 10_000,
            maximumRoutePointCount: 256
        )
        let secondPlan = ASMRRouteOverlayRenderPlan.make(
            from: routePackage,
            renderTimeSeconds: 10_000,
            maximumRoutePointCount: 256
        )

        #expect(firstPlan == secondPlan)
        #expect(firstPlan.routePoints.count == 256)
        #expect(firstPlan.routePoints.first?.x == 0)
        #expect(firstPlan.routePoints.last?.x == 1)
    }

    @Test("A stationary route stays centered")
    func stationaryRouteStaysCentered() {
        let routePackage = makeRoutePackage(coordinates: [
            (latitude: 35, longitude: -86, seconds: 0),
            (latitude: 35, longitude: -86, seconds: 20)
        ])

        let plan = ASMRRouteOverlayRenderPlan.make(
            from: routePackage,
            renderTimeSeconds: 10
        )

        #expect(plan.routePoints == [.init(x: 0.5, y: 0.5), .init(x: 0.5, y: 0.5)])
        #expect(plan.currentPosition == .init(x: 0.5, y: 0.5))
    }

    @Test("Package and manual timing offsets are additive", .bug("https://github.com/heathdj/ASMRWalk/issues/124"))
    func packageAndManualTimingOffsetsAreAdditive() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        let video = ASMRRoutePackageInput.VideoReference(
            kind: "externalCamera",
            displayName: "Camera.mov",
            sourceIdentifier: nil,
            startsAt: start.addingTimeInterval(3),
            offsetSeconds: 5,
            isEmbedded: false
        )
        let package = makeRoutePackage(videoReferences: [video])
        let alignment = ASMRRouteTimingAlignment.resolve(
            manifest: package.manifest,
            explicitOffsetSeconds: -2
        )
        let aligned = ASMRRouteOverlayRenderPlan.make(
            from: package,
            renderTimeSeconds: 0,
            routeTimingOffsetSeconds: alignment.totalOffsetSeconds
        )
        let expected = ASMRRouteOverlayRenderPlan.make(from: package, renderTimeSeconds: 3)

        #expect(alignment.packageOffsetSeconds == 5)
        #expect(alignment.totalOffsetSeconds == 3)
        #expect(aligned.currentPosition == expected.currentPosition)
    }

    @Test("startsAt supplies positive, zero, and negative package offsets")
    func startsAtFallbackSupportsSignedOffsets() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        for expected in [-8.0, 0.0, 12.5] {
            let video = ASMRRoutePackageInput.VideoReference(
                kind: "externalCamera",
                displayName: "Camera.mov",
                sourceIdentifier: nil,
                startsAt: start.addingTimeInterval(expected),
                offsetSeconds: nil,
                isEmbedded: false
            )
            let package = makeRoutePackage(videoReferences: [video])
            let alignment = ASMRRouteTimingAlignment.resolve(
                manifest: package.manifest,
                explicitOffsetSeconds: 0
            )
            #expect(alignment.packageOffsetSeconds == expected)
        }
    }

    @Test("Multiple video references require an explicit primary reference")
    func multipleReferencesDoNotGuess() {
        let videos = [4.0, 9.0].map { offset in
            ASMRRoutePackageInput.VideoReference(
                kind: "externalCamera",
                displayName: "Camera \(offset)",
                sourceIdentifier: nil,
                startsAt: nil,
                offsetSeconds: offset,
                isEmbedded: false
            )
        }
        let ambiguous = makeRoutePackage(videoReferences: videos)
        let selected = makeRoutePackage(videoReferences: videos, primaryVideoReferenceIndex: 1)

        #expect(ASMRRouteTimingAlignment.resolve(
            manifest: ambiguous.manifest,
            explicitOffsetSeconds: 2
        ).totalOffsetSeconds == 2)
        #expect(ASMRRouteTimingAlignment.resolve(
            manifest: selected.manifest,
            explicitOffsetSeconds: 2
        ).totalOffsetSeconds == 11)
    }

    @Test("Saved package selections round trip without exposing bookmark bytes")
    func packageSelectionRoundTrips() throws {
        let selection = ASMRRoutePackageSelection(
            bookmarkData: Data([1, 2, 3, 4]),
            displayName: "Evening Walk",
            lastKnownPath: "/tmp/Evening Walk.asmrroute"
        )

        #expect(try ASMRRoutePackageSelection.decode(selection.encoded()) == selection)
    }

    private func makeRoutePackage(
        coordinates: [(latitude: Double, longitude: Double, seconds: TimeInterval)] = [
            (latitude: 0, longitude: 0, seconds: 0),
            (latitude: 10, longitude: 10, seconds: 10),
            (latitude: 0, longitude: 20, seconds: 20)
        ],
        videoReferences: [ASMRRoutePackageInput.VideoReference] = [],
        primaryVideoReferenceIndex: Int? = nil
    ) -> ASMRRoutePackageInput {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        let duration = coordinates.map(\.seconds).max() ?? 0
        let routePoints = coordinates.map { coordinate in
            ASMRRoutePackageInput.RoutePoint(
                timestamp: start.addingTimeInterval(coordinate.seconds),
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                altitude: nil,
                horizontalAccuracy: 0,
                speed: nil
            )
        }

        return ASMRRoutePackageInput(
            manifest: ASMRRoutePackageInput.Manifest(
                schemaVersion: 1,
                packageIdentifier: UUID(uuid: (17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17)),
                title: "Test Route",
                walkDescription: nil,
                createdAt: start,
                durationSeconds: duration,
                distanceMeters: nil,
                mode: "walk",
                recordingSource: "iPhone",
                captureDeviceName: nil,
                routeStartedAt: start,
                routeEndedAt: start.addingTimeInterval(duration),
                routePointCount: routePoints.count,
                routePointsFile: "route-points.json",
                sourceGPXFile: nil,
                videoReferences: videoReferences,
                primaryVideoReferenceIndex: primaryVideoReferenceIndex,
                createdBy: "ASMR Walk Tests"
            ),
            routePoints: routePoints
        )
    }
}

struct ASMRRouteOverlayRendererTests {
    @Test("Map panel composites locally and keeps pixels outside transparent", .bug("https://github.com/heathdj/ASMRWalk/issues/123"))
    func mapPanelCompositesWithTransparentOutside() {
        let background = ASMRRouteOverlayBitmap(
            width: 2,
            height: 2,
            rgbaPixels: Array(repeating: [UInt8(200), 100, 50, 255], count: 4).flatMap { $0 }
        )
        let transparentStyle = ASMRRouteOverlayStyle(
            routeColor: .init(red: 0, green: 0, blue: 0, alpha: 0),
            currentPositionColor: .init(red: 0, green: 0, blue: 0, alpha: 0),
            markerColor: .init(red: 0, green: 0, blue: 0, alpha: 0),
            paddingFraction: 0,
            lineWidthFraction: 0,
            currentDotRadiusFraction: 0,
            markerRadiusFraction: 0
        )
        let plan = ASMRRouteOverlayRenderPlan(
            routePoints: [.init(x: 0.5, y: 0.5)],
            visibleRoutePoints: [],
            currentPosition: nil,
            startPosition: nil,
            endPosition: nil,
            style: transparentStyle,
            mapBackground: background,
            mapStyle: .init(
                centerX: 0.5,
                centerY: 0.5,
                widthFraction: 0.5,
                heightFraction: 0.5,
                cornerRadiusFraction: 0,
                opacity: 0.5
            )
        )

        let bitmap = ASMRRouteOverlayRenderer.bitmap(for: plan, width: 8, height: 8)
        let outside = Array(bitmap.rgbaPixels[0..<4])
        let centerOffset = ((4 * 8) + 4) * 4
        let center = Array(bitmap.rgbaPixels[centerOffset..<(centerOffset + 4)])

        #expect(outside == [0, 0, 0, 0])
        #expect(center == [200, 100, 50, 128])
    }

    @Test("Rounded map corners clip panel pixels", .bug("https://github.com/heathdj/ASMRWalk/issues/123"))
    func roundedMapCornersClipPixels() {
        let background = ASMRRouteOverlayBitmap(
            width: 1,
            height: 1,
            rgbaPixels: [200, 100, 50, 255]
        )
        let transparentStyle = ASMRRouteOverlayStyle(
            routeColor: .init(red: 0, green: 0, blue: 0, alpha: 0),
            currentPositionColor: .init(red: 0, green: 0, blue: 0, alpha: 0),
            markerColor: .init(red: 0, green: 0, blue: 0, alpha: 0),
            paddingFraction: 0,
            lineWidthFraction: 0,
            currentDotRadiusFraction: 0,
            markerRadiusFraction: 0
        )
        let plan = ASMRRouteOverlayRenderPlan(
            routePoints: [.init(x: 0.5, y: 0.5)],
            visibleRoutePoints: [],
            currentPosition: nil,
            startPosition: nil,
            endPosition: nil,
            style: transparentStyle,
            mapBackground: background,
            mapStyle: .init(
                centerX: 0.5,
                centerY: 0.5,
                widthFraction: 1,
                heightFraction: 1,
                cornerRadiusFraction: 0.5,
                opacity: 1
            )
        )

        let bitmap = ASMRRouteOverlayRenderer.bitmap(for: plan, width: 8, height: 8)
        let corner = Array(bitmap.rgbaPixels[0..<4])
        let centerOffset = ((4 * 8) + 4) * 4
        let center = Array(bitmap.rgbaPixels[centerOffset..<(centerOffset + 4)])

        #expect(corner == [0, 0, 0, 0])
        #expect(center == [200, 100, 50, 255])
    }

    @Test("Bitmap rendering is deterministic and leaves untouched pixels transparent", .bug("https://github.com/heathdj/ASMRWalk/issues/77"))
    func bitmapRenderingIsDeterministicAndTransparent() {
        let plan = makePlan()

        let firstBitmap = ASMRRouteOverlayRenderer.bitmap(for: plan, width: 64, height: 64)
        let secondBitmap = ASMRRouteOverlayRenderer.bitmap(for: plan, width: 64, height: 64)

        #expect(firstBitmap == secondBitmap)
        #expect(firstBitmap.rgbaPixels[0..<4].allSatisfy { $0 == 0 })
        #expect(firstBitmap.rgbaPixels.contains { $0 > 0 })
    }

    @Test("BGRA output writes channels in host surface order")
    func bgraOutputWritesChannelsInHostSurfaceOrder() {
        let style = ASMRRouteOverlayStyle(
            routeColor: .init(red: 0, green: 0, blue: 0, alpha: 0),
            currentPositionColor: .init(red: 240, green: 120, blue: 30, alpha: 255),
            markerColor: .init(red: 0, green: 0, blue: 0, alpha: 0),
            paddingFraction: 0,
            lineWidthFraction: 0,
            currentDotRadiusFraction: 0.5,
            markerRadiusFraction: 0
        )
        let plan = ASMRRouteOverlayRenderPlan(
            routePoints: [.init(x: 0.5, y: 0.5)],
            visibleRoutePoints: [],
            currentPosition: .init(x: 0.5, y: 0.5),
            startPosition: nil,
            endPosition: nil,
            style: style
        )
        let bytesPerRow = 24
        var pixels = Array(repeating: UInt8(99), count: bytesPerRow * 4)

        pixels.withUnsafeMutableBytes { bytes in
            guard let baseAddress = bytes.baseAddress else {
                Issue.record("Expected a pixel buffer base address.")
                return
            }

            ASMRRouteOverlayRenderer.render(
                plan,
                into: baseAddress,
                width: 4,
                height: 4,
                bytesPerRow: bytesPerRow,
                pixelFormat: .bgra
            )
        }

        let centerOffset = (2 * bytesPerRow) + (2 * 4)
        #expect(Array(pixels[centerOffset..<(centerOffset + 4)]) == [30, 120, 240, 255])
        #expect(pixels[(bytesPerRow - 1)] == 0, "Row padding should be cleared with the destination surface.")
    }

    @Test("An empty plan clears the destination to transparent")
    func emptyPlanClearsDestination() {
        var pixels = Array(repeating: UInt8.max, count: 8 * 8 * 4)

        pixels.withUnsafeMutableBytes { bytes in
            guard let baseAddress = bytes.baseAddress else {
                Issue.record("Expected a pixel buffer base address.")
                return
            }

            ASMRRouteOverlayRenderer.render(
                .empty,
                into: baseAddress,
                width: 8,
                height: 8,
                bytesPerRow: 8 * 4,
                pixelFormat: .rgba
            )
        }

        #expect(pixels.allSatisfy { $0 == 0 })
    }

    private func makePlan() -> ASMRRouteOverlayRenderPlan {
        ASMRRouteOverlayRenderPlan(
            routePoints: [.init(x: 0, y: 0), .init(x: 1, y: 1)],
            visibleRoutePoints: [.init(x: 0, y: 0), .init(x: 0.5, y: 0.5)],
            currentPosition: .init(x: 0.5, y: 0.5),
            startPosition: .init(x: 0, y: 0),
            endPosition: .init(x: 1, y: 1),
            style: .default
        )
    }
}
