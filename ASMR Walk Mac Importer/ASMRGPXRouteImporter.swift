//
//  ASMRGPXRouteImporter.swift
//  ASMR Walk
//

import Foundation
import UniformTypeIdentifiers

nonisolated struct ASMRGPXRouteImporter {
    var now: @Sendable () -> Date = { Date.now }

    func package(fromGPXData data: Data, sourceFilename: String? = nil) throws -> ASMRRoutePackage {
        guard let gpxText = String(data: data, encoding: .utf8) else {
            throw ImportError.invalidTextEncoding
        }

        return try package(fromGPXText: gpxText, sourceFilename: sourceFilename)
    }

    func package(fromGPXText gpxText: String, sourceFilename: String? = nil) throws -> ASMRRoutePackage {
        let document = try GPXDocument.parse(gpxText)
        guard document.points.isEmpty == false else {
            throw ImportError.missingRoutePoints
        }

        let sortedPoints = document.points.sorted { $0.timestamp < $1.timestamp }
        let routeStartedAt = document.routeStartedAt ?? sortedPoints.first?.timestamp ?? document.createdAt ?? now()
        let routeEndedAt = document.routeEndedAt ?? sortedPoints.last?.timestamp ?? routeStartedAt
        let title = document.title ?? sourceFilename?.filenameTitle ?? "ASMR Walk Route"
        let walkDescription = document.walkDescription
        let mode = document.mode ?? .walk
        let recordingSource = document.recordingSource ?? .iPhone
        let externalVideoReference = makeExternalVideoReference(from: document, routeStartedAt: routeStartedAt)
        let videoReferences = externalVideoReference.map { [$0] } ?? []

        let manifest = ASMRRoutePackage.Manifest(
            packageIdentifier: document.recordingID ?? UUID(),
            title: title,
            walkDescription: walkDescription,
            createdAt: document.createdAt ?? routeStartedAt,
            durationSeconds: document.durationSeconds ?? routeEndedAt.timeIntervalSince(routeStartedAt),
            distanceMeters: nil,
            mode: mode,
            recordingSource: recordingSource,
            captureDeviceName: document.captureDeviceName,
            routeStartedAt: routeStartedAt,
            routeEndedAt: routeEndedAt,
            routePointCount: sortedPoints.count,
            sourceGPXFile: ASMRRoutePackage.sourceGPXFilename,
            videoReferences: videoReferences
        )

        return ASMRRoutePackage(
            manifest: manifest,
            routePoints: sortedPoints.map {
                ASMRRoutePackage.RoutePoint(
                    timestamp: $0.timestamp,
                    latitude: $0.latitude,
                    longitude: $0.longitude,
                    altitude: $0.altitude,
                    horizontalAccuracy: $0.horizontalAccuracy ?? 0,
                    speed: $0.speed
                )
            },
            sourceGPX: gpxText
        )
    }

    private func makeExternalVideoReference(
        from document: GPXDocument,
        routeStartedAt: Date
    ) -> ASMRRoutePackage.VideoReference? {
        guard let reference = document.externalVideoReference, reference.isEmpty == false else {
            return nil
        }

        return ASMRRoutePackage.VideoReference(
            kind: .externalCamera,
            displayName: reference,
            sourceIdentifier: reference,
            startsAt: document.externalVideoStartedAt,
            offsetSeconds: document.externalVideoOffsetSeconds
                ?? document.externalVideoStartedAt?.timeIntervalSince(routeStartedAt),
            isEmbedded: false
        )
    }
}

extension ASMRGPXRouteImporter {
    enum ImportError: LocalizedError, Equatable {
        case invalidTextEncoding
        case invalidGPX(String)
        case missingRoutePoints

        var errorDescription: String? {
            switch self {
            case .invalidTextEncoding:
                "The selected GPX file is not valid UTF-8 text."
            case let .invalidGPX(message):
                "The selected file could not be parsed as GPX. \(message)"
            case .missingRoutePoints:
                "The selected GPX file does not contain any route points."
            }
        }
    }
}

nonisolated private struct GPXDocument {
    var recordingID: UUID?
    var title: String?
    var walkDescription: String?
    var createdAt: Date?
    var durationSeconds: TimeInterval?
    var mode: RecordingMode?
    var recordingSource: WalkRecordingSource?
    var captureDeviceName: String?
    var routeStartedAt: Date?
    var routeEndedAt: Date?
    var externalVideoReference: String?
    var externalVideoStartedAt: Date?
    var externalVideoOffsetSeconds: TimeInterval?
    var points: [Point] = []

    struct Point {
        var timestamp: Date
        var latitude: Double
        var longitude: Double
        var altitude: Double?
        var horizontalAccuracy: Double?
        var speed: Double?
    }

    static func parse(_ gpxText: String) throws -> GPXDocument {
        let parser = XMLParser(data: Data(gpxText.utf8))
        let delegate = GPXDocumentParser()
        parser.delegate = delegate
        parser.shouldProcessNamespaces = true
        parser.shouldReportNamespacePrefixes = false

        guard parser.parse() else {
            let message = parser.parserError?.localizedDescription ?? "The XML parser reported an unknown error."
            throw ASMRGPXRouteImporter.ImportError.invalidGPX(message)
        }

        return delegate.document
    }
}

nonisolated private final class GPXDocumentParser: NSObject, XMLParserDelegate {
    private(set) var document = GPXDocument()
    private var elementStack: [String] = []
    private var currentText = ""
    private var currentPoint: MutablePoint?

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let name = elementName.normalizedGPXElementName
        elementStack.append(name)
        currentText = ""

        if name == "trkpt" {
            currentPoint = MutablePoint(
                latitude: Double(attributeDict["lat"] ?? ""),
                longitude: Double(attributeDict["lon"] ?? "")
            )
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let name = elementName.normalizedGPXElementName
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        defer {
            _ = elementStack.popLast()
            currentText = ""
        }

        if name == "trkpt" {
            finishCurrentPoint()
            return
        }

        if currentPoint != nil {
            applyPointElement(name: name, text: text)
        } else {
            applyDocumentElement(name: name, text: text)
        }
    }

    private func applyDocumentElement(name: String, text: String) {
        guard text.isEmpty == false else {
            return
        }

        switch name {
        case "name" where elementStack.contains("trk"):
            document.title = text
        case "name" where document.title == nil:
            document.title = text
        case "desc":
            document.walkDescription = text
        case "time" where elementStack.contains("metadata"):
            document.createdAt = Date(iso8601GPXText: text)
        case "recordingID":
            document.recordingID = UUID(uuidString: text)
        case "durationSeconds":
            document.durationSeconds = Double(text)
        case "recordingMode":
            document.mode = RecordingMode(rawValue: text)
        case "recordingSource":
            document.recordingSource = WalkRecordingSource(rawValue: text)
        case "captureDeviceName":
            document.captureDeviceName = text
        case "routeStartedAt":
            document.routeStartedAt = Date(iso8601GPXText: text)
        case "routeEndedAt":
            document.routeEndedAt = Date(iso8601GPXText: text)
        case "description":
            document.walkDescription = text
        case "externalVideoReference":
            document.externalVideoReference = text
        case "externalVideoStartedAt":
            document.externalVideoStartedAt = Date(iso8601GPXText: text)
        case "externalVideoOffsetSeconds":
            document.externalVideoOffsetSeconds = Double(text)
        default:
            break
        }
    }

    private func applyPointElement(name: String, text: String) {
        guard text.isEmpty == false else {
            return
        }

        switch name {
        case "ele":
            currentPoint?.altitude = Double(text)
        case "time":
            currentPoint?.timestamp = Date(iso8601GPXText: text)
        case "horizontalAccuracyMeters":
            currentPoint?.horizontalAccuracy = Double(text)
        case "speedMetersPerSecond":
            currentPoint?.speed = Double(text)
        default:
            break
        }
    }

    private func finishCurrentPoint() {
        defer {
            currentPoint = nil
        }

        guard let currentPoint,
              let latitude = currentPoint.latitude,
              let longitude = currentPoint.longitude,
              let timestamp = currentPoint.timestamp else {
            return
        }

        document.points.append(
            GPXDocument.Point(
                timestamp: timestamp,
                latitude: latitude,
                longitude: longitude,
                altitude: currentPoint.altitude,
                horizontalAccuracy: currentPoint.horizontalAccuracy,
                speed: currentPoint.speed
            )
        )
    }

    private struct MutablePoint {
        var latitude: Double?
        var longitude: Double?
        var timestamp: Date?
        var altitude: Double?
        var horizontalAccuracy: Double?
        var speed: Double?
    }
}

private extension Date {
    nonisolated init?(iso8601GPXText text: String) {
        if let date = ISO8601DateFormatter.gpx.date(from: text) {
            self = date
        } else if let date = ISO8601DateFormatter.gpxFractional.date(from: text) {
            self = date
        } else {
            return nil
        }
    }
}

private extension ISO8601DateFormatter {
    nonisolated static let gpx: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    nonisolated static let gpxFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private extension String {
    nonisolated var normalizedGPXElementName: String {
        components(separatedBy: ":").last ?? self
    }

    nonisolated var filenameTitle: String {
        let title = URL(filePath: self).deletingPathExtension().lastPathComponent
        return title.isEmpty ? self : title
    }
}

extension UTType {
    static var gpx: UTType {
        UTType(filenameExtension: "gpx") ?? .xml
    }
}
