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
        let horizontalAccuracy: Double
        let speed: Double?
    }

    let recordingID: UUID
    let title: String
    let walkDescription: String
    let createdAt: Date
    let duration: TimeInterval
    let mode: RecordingMode
    let hasVideo: Bool
    let recordingSource: WalkRecordingSource
    let captureDeviceName: String?
    let routeStartedAt: Date
    let routeEndedAt: Date
    let externalVideoReference: String?
    let externalVideoStartedAt: Date?
    let points: [Point]

    @MainActor
    init(recording: WalkRecording) {
        recordingID = recording.id
        title = recording.title
        walkDescription = recording.walkDescription
        createdAt = recording.createdAt
        duration = recording.duration
        mode = recording.mode
        hasVideo = recording.hasVideo
        recordingSource = recording.source
        captureDeviceName = recording.captureDeviceName
        routeStartedAt = recording.routeTimingStart
        routeEndedAt = recording.routeTimingEnd
        externalVideoReference = recording.externalVideoReference
        externalVideoStartedAt = recording.externalVideoStartedAt
        points = recording.pointsInTimeOrder.map {
            Point(
                timestamp: $0.timestamp,
                latitude: $0.latitude,
                longitude: $0.longitude,
                altitude: $0.altitude,
                horizontalAccuracy: $0.horizontalAccuracy,
                speed: $0.speed
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
                details += "<ele>\(altitude.gpxNumberText)</ele>"
            }
            details += "<time>\(point.timestamp.ISO8601Format())</time>"
            details += point.extensionsXML

            return "<trkpt lat=\"\(point.latitude.coordinateText)\" lon=\"\(point.longitude.coordinateText)\">\(details)</trkpt>"
        }
        .joined(separator: "\n")

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="ASMR Walk" xmlns="http://www.topografix.com/GPX/1/1" xmlns:asmrwalk="https://asmrwalk.app/gpx/1">
        <metadata><name>\(title.xmlEscaped)</name>\(descriptionXML)<time>\(createdAt.ISO8601Format())</time></metadata>
        <trk><name>\(title.xmlEscaped)</name>\(descriptionXML)\(trackExtensionsXML)<trkseg>
        \(trackPoints)
        </trkseg></trk>
        </gpx>
        """
    }

    private var trackExtensionsXML: String {
        """
        <extensions><asmrwalk:recordingID>\(recordingID.uuidString.xmlEscaped)</asmrwalk:recordingID><asmrwalk:durationSeconds>\(duration.gpxNumberText)</asmrwalk:durationSeconds><asmrwalk:recordingMode>\(mode.rawValue.xmlEscaped)</asmrwalk:recordingMode><asmrwalk:recordingSource>\(recordingSource.rawValue.xmlEscaped)</asmrwalk:recordingSource>\(captureDeviceXML)<asmrwalk:routeStartedAt>\(routeStartedAt.ISO8601Format())</asmrwalk:routeStartedAt><asmrwalk:routeEndedAt>\(routeEndedAt.ISO8601Format())</asmrwalk:routeEndedAt><asmrwalk:hasVideo>\(hasVideo ? "true" : "false")</asmrwalk:hasVideo>\(descriptionExtensionXML)\(externalVideoXML)</extensions>
        """
    }

    private var captureDeviceXML: String {
        guard let captureDeviceName, captureDeviceName.isEmpty == false else {
            return ""
        }

        return "<asmrwalk:captureDeviceName>\(captureDeviceName.xmlEscaped)</asmrwalk:captureDeviceName>"
    }

    private var externalVideoXML: String {
        var values = ""
        if let externalVideoReference, externalVideoReference.isEmpty == false {
            values += "<asmrwalk:externalVideoReference>\(externalVideoReference.xmlEscaped)</asmrwalk:externalVideoReference>"
        }
        if let externalVideoStartedAt {
            values += "<asmrwalk:externalVideoStartedAt>\(externalVideoStartedAt.ISO8601Format())</asmrwalk:externalVideoStartedAt>"
        }
        return values
    }

    private var descriptionXML: String {
        guard walkDescription.isEmpty == false else {
            return ""
        }

        return "<desc>\(walkDescription.xmlEscaped)</desc>"
    }

    private var descriptionExtensionXML: String {
        guard walkDescription.isEmpty == false else {
            return ""
        }

        return "<asmrwalk:description>\(walkDescription.xmlEscaped)</asmrwalk:description>"
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

    var extensionsXML: String {
        var values = "<asmrwalk:horizontalAccuracyMeters>\(horizontalAccuracy.gpxNumberText)</asmrwalk:horizontalAccuracyMeters>"
        if let speed {
            values += "<asmrwalk:speedMetersPerSecond>\(speed.gpxNumberText)</asmrwalk:speedMetersPerSecond>"
        }
        return "<extensions>\(values)</extensions>"
    }
}

private extension Double {
    var coordinateText: String {
        formatted(.number.locale(Locale(identifier: "en_US_POSIX")).precision(.fractionLength(6)))
    }

    var gpxNumberText: String {
        formatted(.number.locale(Locale(identifier: "en_US_POSIX")).precision(.fractionLength(0...3)))
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
