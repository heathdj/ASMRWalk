//
//  WalkRouteExport.swift
//  ASMR Walk
//

import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct WalkRouteExport {
    struct Point: Sendable {
        let timestamp: Date
        let latitude: Double
        let longitude: Double
        let altitude: Double?
    }

    let title: String
    let createdAt: Date
    let points: [Point]

    @MainActor
    init(recording: WalkRecording) {
        title = recording.title
        createdAt = recording.createdAt
        points = recording.pointsInTimeOrder.map {
            Point(
                timestamp: $0.timestamp,
                latitude: $0.latitude,
                longitude: $0.longitude,
                altitude: $0.altitude
            )
        }
    }

    var googleMapsURL: URL? {
        guard let first = points.first, let last = points.last else {
            return nil
        }

        var components = URLComponents(string: "https://www.google.com/maps/dir/")
        var queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "origin", value: first.coordinateText),
            URLQueryItem(name: "destination", value: last.coordinateText),
            URLQueryItem(name: "travelmode", value: "walking")
        ]

        let waypoints = sampledWaypoints(maximumCount: 8)
        if waypoints.isEmpty == false {
            queryItems.append(
                URLQueryItem(
                    name: "waypoints",
                    value: waypoints.map(\.coordinateText).joined(separator: "|")
                )
            )
        }

        components?.queryItems = queryItems
        return components?.url
    }

    var gpxFile: GPXFile {
        GPXFile(filename: filename, data: Data(gpxText.utf8))
    }

    var gpxText: String {
        let trackPoints = points.map { point in
            var details = ""
            if let altitude = point.altitude {
                details += "<ele>\(altitude.formatted(.number.precision(.fractionLength(2))))</ele>"
            }
            details += "<time>\(point.timestamp.ISO8601Format())</time>"

            return "<trkpt lat=\"\(point.latitude.coordinateText)\" lon=\"\(point.longitude.coordinateText)\">\(details)</trkpt>"
        }
        .joined(separator: "\n")

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="ASMR Walk" xmlns="http://www.topografix.com/GPX/1/1">
        <metadata><name>\(title.xmlEscaped)</name><time>\(createdAt.ISO8601Format())</time></metadata>
        <trk><name>\(title.xmlEscaped)</name><trkseg>
        \(trackPoints)
        </trkseg></trk>
        </gpx>
        """
    }

    private var filename: String {
        let baseName = title
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.isEmpty == false }
            .joined(separator: "-")

        return "\(baseName.isEmpty ? "ASMR-Walk" : baseName).gpx"
    }

    private func sampledWaypoints(maximumCount: Int) -> [Point] {
        guard points.count > 2, maximumCount > 0 else {
            return []
        }

        let interiorPoints = Array(points.dropFirst().dropLast())
        guard interiorPoints.count > maximumCount else {
            return interiorPoints
        }

        if maximumCount == 1 {
            return [interiorPoints[interiorPoints.count / 2]]
        }

        let stride = Double(interiorPoints.count - 1) / Double(maximumCount - 1)
        return (0..<maximumCount).map { index in
            interiorPoints[Int((Double(index) * stride).rounded())]
        }
    }
}

struct GPXFile: Transferable, Sendable {
    let filename: String
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .gpx) { file in
            let directory = FileManager.default.temporaryDirectory
                .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            let url = directory.appending(path: file.filename)
            try file.data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

private extension WalkRouteExport.Point {
    var coordinateText: String {
        "\(latitude.coordinateText),\(longitude.coordinateText)"
    }
}

private extension Double {
    var coordinateText: String {
        formatted(.number.locale(Locale(identifier: "en_US_POSIX")).precision(.fractionLength(6)))
    }
}

private extension String {
    var xmlEscaped: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

private extension UTType {
    static var gpx: UTType {
        UTType(filenameExtension: "gpx") ?? .xml
    }
}
