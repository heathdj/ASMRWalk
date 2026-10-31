//
//  PreparedMapBackground.swift
//  ASMR Walk Mac Importer
//

import AppKit
import MapKit

struct PreparedMapBackground: Equatable, Sendable {
    let metadata: ASMRRoutePackage.MapBackground
    let imageData: Data

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

        let mapRect = Self.mapRect(for: points)
        let options = MKMapSnapshotter.Options()
        options.mapRect = mapRect
        options.size = Self.outputSize
        options.mapType = .standard
        options.showsBuildings = true
        options.pointOfInterestFilter = .includingAll
        options.appearance = NSAppearance(named: .aqua)

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

        return PreparedMapBackground(
            metadata: ASMRRoutePackage.MapBackground(
                filename: filename,
                pixelWidth: bitmap.pixelsWide,
                pixelHeight: bitmap.pixelsHigh,
                scale: Double(bitmap.pixelsWide) / Self.outputSize.width,
                mapRectOriginX: mapRect.origin.x,
                mapRectOriginY: mapRect.origin.y,
                mapRectWidth: mapRect.size.width,
                mapRectHeight: mapRect.size.height,
                firstRoutePointIndex: pointRange?.lowerBound,
                lastRoutePointIndex: pointRange?.upperBound,
                startTimestamp: points.first?.timestamp,
                endTimestamp: points.last?.timestamp
            ),
            imageData: pngData
        )
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

        var errorDescription: String? {
            switch self {
            case .emptyRoute:
                "Load a route before preparing a map background."
            case .snapshotUnavailable:
                "MapKit did not return a map image. Route-only export is still available."
            case .imageEncodingFailed:
                "The prepared map could not be encoded as a PNG. Route-only export is still available."
            }
        }
    }
}
