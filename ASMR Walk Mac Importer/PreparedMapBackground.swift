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
}

@MainActor
struct MapBackgroundPreparer: MapBackgroundPreparing {
    static let outputSize = CGSize(width: 1_280, height: 720)

    func prepare(for route: RoutePreview) async throws -> PreparedMapBackground {
        guard route.routePoints.isEmpty == false else {
            throw PreparationError.emptyRoute
        }

        let mapRect = Self.mapRect(for: route.routePoints)
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
                filename: ASMRRoutePackage.mapBackgroundFilename,
                pixelWidth: bitmap.pixelsWide,
                pixelHeight: bitmap.pixelsHigh,
                scale: Double(bitmap.pixelsWide) / Self.outputSize.width,
                mapRectOriginX: mapRect.origin.x,
                mapRectOriginY: mapRect.origin.y,
                mapRectWidth: mapRect.size.width,
                mapRectHeight: mapRect.size.height
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
