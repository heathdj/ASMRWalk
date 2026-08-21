//
//  WalkRouteThumbnailGenerator.swift
//  ASMR Walk
//

import CoreLocation
import Foundation
import MapKit
import SwiftData
import UIKit

@MainActor
enum WalkRouteThumbnailGenerator {
    nonisolated static let styleVersion = 1
    static let thumbnailSize = CGSize(width: 320, height: 220)
    static let thumbnailCompressionQuality: CGFloat = 0.82

    static func generate(
        for snapshot: WalkRecordingSnapshot,
        in modelContainer: ModelContainer,
        fileManager: FileManager = .default
    ) async {
        guard snapshot.points.count > 1 else {
            return
        }

        do {
            let image = try await image(for: snapshot.points)
            let thumbnailURL = try write(image: image, recordingID: snapshot.id, fileManager: fileManager)
            let persistence = WalkRecordingPersistence(modelContainer: modelContainer)
            try await persistence.updateThumbnailURL(
                recordingID: snapshot.id,
                thumbnailURL: thumbnailURL,
                styleVersion: styleVersion
            )
        } catch {
            // Thumbnail generation is best-effort and must never block or undo a saved recording.
        }
    }

    static func thumbnailDirectory(fileManager: FileManager = .default) throws -> URL {
        let directory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        .appending(path: "Route Thumbnails", directoryHint: .isDirectory)

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func thumbnailURL(recordingID: UUID, fileManager: FileManager = .default) throws -> URL {
        try thumbnailDirectory(fileManager: fileManager)
            .appending(path: "\(recordingID.uuidString).jpg")
    }

    private static func image(for points: [LocationPointSnapshot]) async throws -> UIImage {
        let coordinates = points.map(\.coordinate)
        let options = MKMapSnapshotter.Options()
        options.size = thumbnailSize
        options.mapType = .standard
        options.region = region(for: coordinates)

        let snapshot = try await MKMapSnapshotter(options: options).start()
        return drawRoute(coordinates, on: snapshot)
    }

    private static func write(
        image: UIImage,
        recordingID: UUID,
        fileManager: FileManager
    ) throws -> URL {
        let url = try thumbnailURL(recordingID: recordingID, fileManager: fileManager)
        guard let data = image.jpegData(compressionQuality: thumbnailCompressionQuality) else {
            throw CocoaError(.fileWriteUnknown)
        }

        try data.write(to: url, options: .atomic)
        return url
    }

    private static func region(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        let mapRect = coordinates
            .map { MKMapRect(origin: MKMapPoint($0), size: MKMapSize(width: 0, height: 0)) }
            .reduce(MKMapRect.null) { partialResult, mapRect in
                partialResult.union(mapRect)
            }

        let paddedRect = mapRect.insetBy(dx: -max(mapRect.width * 0.18, 800), dy: -max(mapRect.height * 0.18, 800))
        return MKCoordinateRegion(paddedRect)
    }

    private static func drawRoute(
        _ coordinates: [CLLocationCoordinate2D],
        on snapshot: MKMapSnapshotter.Snapshot
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = snapshot.image.scale

        return UIGraphicsImageRenderer(size: snapshot.image.size, format: format).image { context in
            snapshot.image.draw(at: .zero)

            let path = UIBezierPath()
            for (index, coordinate) in coordinates.enumerated() {
                let point = snapshot.point(for: coordinate)
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }

            UIColor.systemGreen.withAlphaComponent(0.28).setStroke()
            path.lineWidth = 10
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()

            UIColor.systemGreen.setStroke()
            path.lineWidth = 5
            path.stroke()

            if let firstCoordinate = coordinates.first {
                drawEndpoint(at: snapshot.point(for: firstCoordinate), color: .systemGreen, in: context.cgContext)
            }

            if let lastCoordinate = coordinates.last {
                drawEndpoint(at: snapshot.point(for: lastCoordinate), color: .systemRed, in: context.cgContext)
            }
        }
    }

    private static func drawEndpoint(at point: CGPoint, color: UIColor, in context: CGContext) {
        let rect = CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: rect)
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(2)
        context.strokeEllipse(in: rect)
    }
}
