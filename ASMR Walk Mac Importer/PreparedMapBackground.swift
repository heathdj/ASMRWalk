//
//  PreparedMapBackground.swift
//  ASMR Walk Mac Importer
//

import AppKit
import MapKit

struct PreparedMapBackground: Equatable, Sendable {
    let metadata: ASMRRoutePackage.MapBackground
    let imageData: Data
    var darkImageData: Data? = nil

    var assets: [String: Data] {
        var result = [metadata.filename: imageData]
        if let filename = metadata.darkFilename, let darkImageData {
            result[filename] = darkImageData
        }
        return result
    }

    var image: NSImage? {
        NSImage(data: imageData)
    }
}

@MainActor
protocol MapBackgroundPreparing {
    func prepare(for route: RoutePreview) async throws -> PreparedMapBackground
    func prepareSegments(for route: RoutePreview) async throws -> [PreparedMapBackground]
}

extension MapBackgroundPreparing {
    func prepareSegments(for route: RoutePreview) async throws -> [PreparedMapBackground] {
        [try await prepare(for: route)]
    }
}

@MainActor
struct MapBackgroundPreparer: MapBackgroundPreparing {
    static let outputSize = CGSize(width: 1_280, height: 720)
    static let maximumSegmentPointCount = 100
    static let segmentOverlapPointCount = 5

    func prepare(for route: RoutePreview) async throws -> PreparedMapBackground {
        try await prepare(
            points: route.routePoints,
            filename: ASMRRoutePackage.mapBackgroundFilename,
            pointRange: nil
        )
    }

    func prepareSegments(for route: RoutePreview) async throws -> [PreparedMapBackground] {
        let ranges = Self.segmentRanges(pointCount: route.routePoints.count)
        return try await withThrowingTaskGroup(of: (Int, PreparedMapBackground).self) { group in
            for (offset, range) in ranges.enumerated() {
                let points = Array(route.routePoints[range])
                group.addTask { @MainActor in
                    let background = try await prepare(
                        points: points,
                        filename: String(format: "map-background-%03d.png", offset + 1),
                        pointRange: range
                    )
                    return (offset, background)
                }
            }

            var prepared: [(Int, PreparedMapBackground)] = []
            for try await result in group {
                prepared.append(result)
            }
            return prepared.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    static func segmentRanges(pointCount: Int) -> [ClosedRange<Int>] {
        guard pointCount > 0 else { return [] }
        guard pointCount > maximumSegmentPointCount else { return [0...(pointCount - 1)] }

        var ranges: [ClosedRange<Int>] = []
        var startIndex = 0
        while startIndex < pointCount {
            let endIndex = min(startIndex + maximumSegmentPointCount - 1, pointCount - 1)
            ranges.append(startIndex...endIndex)
            guard endIndex < pointCount - 1 else { break }
            startIndex = endIndex - segmentOverlapPointCount + 1
        }
        return ranges
    }

    private func prepare(
        points: [RoutePreview.RoutePoint],
        filename: String,
        pointRange: ClosedRange<Int>?
    ) async throws -> PreparedMapBackground {
        guard points.isEmpty == false else {
            throw PreparationError.emptyRoute
        }

        let light = try await prepareSnapshot(points: points, filename: filename, pointRange: pointRange, appearance: .aqua)
        let darkFilename = String(filename.dropLast(4)) + "-dark.png"
        let dark = try await prepareSnapshot(points: points, filename: darkFilename, pointRange: pointRange, appearance: .darkAqua)
        guard Self.projectionsMatch(light.metadata, dark.metadata) else {
            throw PreparationError.invalidProjection
        }
        var metadata = light.metadata
        metadata.darkFilename = darkFilename
        return PreparedMapBackground(metadata: metadata, imageData: light.imageData, darkImageData: dark.imageData)
    }

    // Reject mismatched snapshots instead of letting an appearance change move the route.
    static func projectionsMatch(_ light: ASMRRoutePackage.MapBackground, _ dark: ASMRRoutePackage.MapBackground) -> Bool {
        guard light.pixelWidth == dark.pixelWidth, light.pixelHeight == dark.pixelHeight,
              light.scale == dark.scale else { return false }
        let tolerance = min(light.mapRectWidth / Double(max(1, light.pixelWidth)),
                            light.mapRectHeight / Double(max(1, light.pixelHeight))) * 0.001
        return zip([light.mapRectOriginX, light.mapRectOriginY, light.mapRectWidth, light.mapRectHeight],
                   [dark.mapRectOriginX, dark.mapRectOriginY, dark.mapRectWidth, dark.mapRectHeight])
            .allSatisfy { abs($0 - $1) <= tolerance }
    }

    private func prepareSnapshot(
        points: [RoutePreview.RoutePoint],
        filename: String,
        pointRange: ClosedRange<Int>?,
        appearance: NSAppearance.Name
    ) async throws -> PreparedMapBackground {
        let mapRect = Self.mapRect(for: points)
        let options = MKMapSnapshotter.Options()
        options.mapRect = mapRect
        options.size = Self.outputSize
        options.mapType = .standard
        options.showsBuildings = true
        options.pointOfInterestFilter = .includingAll
        options.appearance = NSAppearance(named: appearance)

        let snapshotter = MKMapSnapshotter(options: options)
        let snapshot = try await withCheckedThrowingContinuation { continuation in
            snapshotter.start { snapshot, error in
                if let snapshot {
                    continuation.resume(returning: snapshot)
                } else {
                    continuation.resume(throwing: error ?? PreparationError.snapshotUnavailable)
                }
            }
        }

        guard let tiffData = snapshot.image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw PreparationError.imageEncodingFailed
        }

        // MapKit can adjust the requested rectangle to fit the snapshot. Recover
        // the actual north-up Mercator bounds from its coordinate-to-image mapping.
        let referenceRect = MKMapRect(
            x: mapRect.minX + mapRect.width * 0.25,
            y: mapRect.minY + mapRect.height * 0.25,
            width: mapRect.width * 0.5, height: mapRect.height * 0.5
        )
        let capturedRect = try Self.capturedMapRect(
            referenceRect: referenceRect,
            imageSize: snapshot.image.size,
            northWest: snapshot.point(for: MKMapPoint(x: referenceRect.minX, y: referenceRect.minY).coordinate),
            southEast: snapshot.point(for: MKMapPoint(x: referenceRect.maxX, y: referenceRect.maxY).coordinate)
        )

        return PreparedMapBackground(
            metadata: ASMRRoutePackage.MapBackground(
                filename: filename,
                pixelWidth: bitmap.pixelsWide,
                pixelHeight: bitmap.pixelsHigh,
                scale: Double(bitmap.pixelsWide) / Self.outputSize.width,
                mapRectOriginX: capturedRect.origin.x,
                mapRectOriginY: capturedRect.origin.y,
                mapRectWidth: capturedRect.size.width,
                mapRectHeight: capturedRect.size.height,
                firstRoutePointIndex: pointRange?.lowerBound,
                lastRoutePointIndex: pointRange?.upperBound,
                startTimestamp: points.first?.timestamp,
                endTimestamp: points.last?.timestamp
            ),
            imageData: pngData
        )
    }

    static func capturedMapRect(
        referenceRect: MKMapRect,
        imageSize: CGSize,
        northWest: CGPoint,
        southEast: CGPoint
    ) throws -> MKMapRect {
        let horizontalSpan = southEast.x - northWest.x
        let verticalSpan = southEast.y - northWest.y
        guard imageSize.width.isFinite, imageSize.height.isFinite,
              imageSize.width > 0, imageSize.height > 0,
              northWest.x.isFinite, northWest.y.isFinite,
              horizontalSpan.isFinite, verticalSpan.isFinite,
              horizontalSpan > 0, abs(verticalSpan) > 0,
              referenceRect.width.isFinite, referenceRect.height.isFinite,
              referenceRect.width > 0, referenceRect.height > 0 else {
            throw PreparationError.invalidProjection
        }
        let unitsPerX = referenceRect.width / horizontalSpan
        let unitsPerY = referenceRect.height / abs(verticalSpan)
        // NSImage and other image APIs may expose opposite vertical origins.
        // Infer the direction from the known north/south coordinates.
        let topY = verticalSpan > 0 ? northWest.y : imageSize.height - northWest.y
        let rect = MKMapRect(
            x: referenceRect.minX - northWest.x * unitsPerX,
            y: referenceRect.minY - topY * unitsPerY,
            width: imageSize.width * unitsPerX,
            height: imageSize.height * unitsPerY
        )
        guard rect.origin.x.isFinite, rect.origin.y.isFinite,
              rect.width.isFinite, rect.height.isFinite,
              rect.width > 0, rect.height > 0 else {
            throw PreparationError.invalidProjection
        }
        return rect
    }

    static func mapRect(for points: [RoutePreview.RoutePoint]) -> MKMapRect {
        let routeRect = points.reduce(MKMapRect.null) { partialResult, routePoint in
            let point = MKMapPoint(
                CLLocationCoordinate2D(
                    latitude: routePoint.latitude,
                    longitude: routePoint.longitude
                )
            )
            return partialResult.union(MKMapRect(x: point.x, y: point.y, width: 1, height: 1))
        }

        let minimumDimension = 1_000.0
        let paddedWidth = max(routeRect.width * 1.25, minimumDimension)
        let paddedHeight = max(routeRect.height * 1.25, minimumDimension)

        return MKMapRect(
            x: routeRect.midX - (paddedWidth / 2),
            y: routeRect.midY - (paddedHeight / 2),
            width: paddedWidth,
            height: paddedHeight
        )
    }

    enum PreparationError: LocalizedError {
        case emptyRoute
        case snapshotUnavailable
        case imageEncodingFailed
        case invalidProjection

        var errorDescription: String? {
            switch self {
            case .emptyRoute:
                "Load a route before preparing a map background."
            case .snapshotUnavailable:
                "MapKit did not return a map image. Route-only export is still available."
            case .invalidProjection:
                "MapKit returned an unusable map projection. Prepare the map again."
            case .imageEncodingFailed:
                "The prepared map could not be encoded as a PNG. Route-only export is still available."
            }
        }
    }
}
