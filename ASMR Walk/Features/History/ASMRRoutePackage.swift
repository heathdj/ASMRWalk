//
//  ASMRRoutePackage.swift
//  ASMR Walk
//

import Foundation
import UniformTypeIdentifiers

nonisolated struct ASMRRoutePackage: Equatable, Sendable {
    static let schemaVersion = 3
    static let minimumSupportedSchemaVersion = 1
    static let fileExtension = "asmrroute"
    static let manifestFilename = "manifest.json"
    static let routePointsFilename = "route-points.json"
    static let sourceGPXFilename = "source.gpx"
    static let mapBackgroundFilename = "map-background.png"

    let manifest: Manifest
    let routePoints: [RoutePoint]
    let sourceGPX: String?
    let mapBackgroundData: Data?
    let mapBackgroundDataByFilename: [String: Data]

    init(
        manifest: Manifest,
        routePoints: [RoutePoint],
        sourceGPX: String? = nil,
        mapBackgroundData: Data? = nil,
        mapBackgroundDataByFilename: [String: Data] = [:]
    ) {
        self.manifest = manifest
        self.routePoints = routePoints.enumerated().sorted { lhs, rhs in
            if lhs.element.timestamp == rhs.element.timestamp {
                return lhs.offset < rhs.offset
            }

            return lhs.element.timestamp < rhs.element.timestamp
        }.map(\.element)
        self.sourceGPX = sourceGPX
        self.mapBackgroundData = mapBackgroundData
        self.mapBackgroundDataByFilename = mapBackgroundDataByFilename
    }

    func write(to packageURL: URL, fileManager: FileManager = .default) throws {
        if fileManager.fileExists(atPath: packageURL.path) {
            try fileManager.removeItem(at: packageURL)
        }

        try fileManager.createDirectory(at: packageURL, withIntermediateDirectories: true)
        try Self.encode(manifest).write(
            to: packageURL.appending(path: Self.manifestFilename),
            options: .atomic
        )
        try Self.encode(routePoints).write(
            to: packageURL.appending(path: manifest.routePointsFile),
            options: .atomic
        )

        if let sourceGPX, let sourceGPXFile = manifest.sourceGPXFile {
            try Data(sourceGPX.utf8).write(
                to: packageURL.appending(path: sourceGPXFile),
                options: .atomic
            )
        }

        if let mapBackgroundData, let mapBackground = manifest.mapBackground {
            try mapBackgroundData.write(to: packageURL.appending(path: mapBackground.filename), options: .atomic)
        }

        for mapBackground in manifest.mapBackgrounds ?? [] {
            guard let data = mapBackgroundDataByFilename[mapBackground.filename] else { continue }
            try data.write(to: packageURL.appending(path: mapBackground.filename), options: .atomic)
        }
    }

    static func load(from packageURL: URL) throws -> ASMRRoutePackage {
        let manifest = try decode(
            Manifest.self,
            from: Data(contentsOf: packageURL.appending(path: manifestFilename))
        )
        guard (minimumSupportedSchemaVersion...schemaVersion).contains(manifest.schemaVersion) else {
            throw PackageError.unsupportedSchemaVersion(manifest.schemaVersion)
        }

        let routePoints = try decode(
            [RoutePoint].self,
            from: Data(contentsOf: packageURL.appending(path: manifest.routePointsFile))
        )
        let sourceGPX: String?
        if let sourceGPXFile = manifest.sourceGPXFile {
            sourceGPX = try String(
                decoding: Data(contentsOf: packageURL.appending(path: sourceGPXFile)),
                as: UTF8.self
            )
        } else {
            sourceGPX = nil
        }
        let mapBackgroundData = manifest.mapBackground.flatMap {
            try? Data(contentsOf: packageURL.appending(path: $0.filename))
        }
        let mapBackgroundDataByFilename = Dictionary(
            uniqueKeysWithValues: (manifest.mapBackgrounds ?? []).compactMap { background in
                let url = packageURL.appending(path: background.filename)
                return (try? Data(contentsOf: url)).map { (background.filename, $0) }
            }
        )

        guard routePoints.count == manifest.routePointCount else {
            throw PackageError.routePointCountMismatch(
                expected: manifest.routePointCount,
                actual: routePoints.count
            )
        }

        return ASMRRoutePackage(
            manifest: manifest,
            routePoints: routePoints,
            sourceGPX: sourceGPX,
            mapBackgroundData: mapBackgroundData,
            mapBackgroundDataByFilename: mapBackgroundDataByFilename
        )
    }

    static func packageURL(forTitle title: String, in directory: URL) -> URL {
        directory.appending(path: "\(filenameBase(for: title)).\(fileExtension)", directoryHint: .isDirectory)
    }

    private static func filenameBase(for title: String) -> String {
        let baseName = title
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.isEmpty == false }
            .joined(separator: "-")

        return baseName.isEmpty ? "ASMR-Walk" : baseName
    }

    private static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }
}

extension ASMRRoutePackage {
    nonisolated struct Manifest: Codable, Equatable, Sendable {
        var schemaVersion = ASMRRoutePackage.schemaVersion
        var packageIdentifier: UUID
        var title: String
        var walkDescription: String?
        var createdAt: Date
        var durationSeconds: TimeInterval
        var distanceMeters: Double?
        var mode: RecordingMode
        var recordingSource: WalkRecordingSource
        var captureDeviceName: String?
        var routeStartedAt: Date
        var routeEndedAt: Date
        var routePointCount: Int
        var routePointsFile = ASMRRoutePackage.routePointsFilename
        var sourceGPXFile: String?
        var videoReferences: [VideoReference]
        var primaryVideoReferenceIndex: Int? = nil
        var mapBackground: MapBackground? = nil
        var mapBackgrounds: [MapBackground]? = nil
        var createdBy = "ASMR Walk"
    }

    nonisolated struct MapBackground: Codable, Equatable, Sendable {
        let filename: String
        let pixelWidth: Int
        let pixelHeight: Int
        let scale: Double
        let mapRectOriginX: Double
        let mapRectOriginY: Double
        let mapRectWidth: Double
        let mapRectHeight: Double
        var firstRoutePointIndex: Int? = nil
        var lastRoutePointIndex: Int? = nil
        var startTimestamp: Date? = nil
        var endTimestamp: Date? = nil
    }

    nonisolated struct RoutePoint: Codable, Equatable, Sendable {
        let timestamp: Date
        let latitude: Double
        let longitude: Double
        let altitude: Double?
        let horizontalAccuracy: Double
        let speed: Double?

        init(
            timestamp: Date,
            latitude: Double,
            longitude: Double,
            altitude: Double?,
            horizontalAccuracy: Double,
            speed: Double?
        ) {
            self.timestamp = timestamp
            self.latitude = latitude
            self.longitude = longitude
            self.altitude = altitude
            self.horizontalAccuracy = horizontalAccuracy
            self.speed = speed
        }

    }

    nonisolated struct VideoReference: Codable, Equatable, Sendable {
        nonisolated enum Kind: String, Codable, Sendable {
            case localVideo
            case photosAsset
            case externalCamera
        }

        let kind: Kind
        let displayName: String
        let sourceIdentifier: String?
        let startsAt: Date?
        let offsetSeconds: TimeInterval?
        let isEmbedded: Bool
    }

    nonisolated enum PackageError: LocalizedError, Equatable {
        case unsupportedSchemaVersion(Int)
        case routePointCountMismatch(expected: Int, actual: Int)

        var errorDescription: String? {
            switch self {
            case let .unsupportedSchemaVersion(version):
                "Unsupported .asmrroute schema version \(version)."
            case let .routePointCountMismatch(expected, actual):
                "The .asmrroute package expected \(expected) route points but found \(actual)."
            }
        }
    }
}

extension UTType {
    static var asmrRoutePackage: UTType {
        UTType(filenameExtension: ASMRRoutePackage.fileExtension) ?? .package
    }
}
