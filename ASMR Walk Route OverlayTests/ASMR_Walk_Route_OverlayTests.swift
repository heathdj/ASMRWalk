//
//  ASMR_Walk_Route_OverlayTests.swift
//  ASMR Walk Route OverlayTests
//

import Foundation
import Testing

struct ASMRRouteOverlayRenderPlanTests {
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

    private func makeRoutePackage(
        coordinates: [(latitude: Double, longitude: Double, seconds: TimeInterval)] = [
            (latitude: 0, longitude: 0, seconds: 0),
            (latitude: 10, longitude: 10, seconds: 10),
            (latitude: 0, longitude: 20, seconds: 20)
        ]
    ) -> ASMRRoutePackageInput {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
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
                durationSeconds: 20,
                distanceMeters: nil,
                mode: "walk",
                recordingSource: "iPhone",
                captureDeviceName: nil,
                routeStartedAt: start,
                routeEndedAt: start.addingTimeInterval(20),
                routePointCount: routePoints.count,
                routePointsFile: "route-points.json",
                sourceGPXFile: nil,
                videoReferences: [],
                createdBy: "ASMR Walk Tests"
            ),
            routePoints: routePoints
        )
    }
}

struct ASMRRouteOverlayRendererTests {
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
