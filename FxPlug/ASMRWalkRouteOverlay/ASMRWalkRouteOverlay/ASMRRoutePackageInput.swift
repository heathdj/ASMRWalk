//
//  ASMRRoutePackageInput.swift
//  ASMR Walk Route Overlay FxPlug
//

import Foundation

struct ASMRRoutePackageInput: Equatable, Sendable {
    static let expectedSchemaVersion = 1
    static let manifestFilename = "manifest.json"
    static let routePointsFilename = "route-points.json"

    let manifest: Manifest
    let routePoints: [RoutePoint]

    static func load(from packageURL: URL) throws -> ASMRRoutePackageInput {
        let manifestURL = packageURL.appending(path: manifestFilename)
        let manifest = try decode(Manifest.self, from: Data(contentsOf: manifestURL))

        guard manifest.schemaVersion == expectedSchemaVersion else {
            throw LoadError.unsupportedSchemaVersion(manifest.schemaVersion)
        }

        let routePointsURL = packageURL.appending(path: manifest.routePointsFile)
        let routePoints = try decode([RoutePoint].self, from: Data(contentsOf: routePointsURL))

        guard routePoints.count == manifest.routePointCount else {
            throw LoadError.routePointCountMismatch(
                expected: manifest.routePointCount,
                actual: routePoints.count
            )
        }

        return ASMRRoutePackageInput(
            manifest: manifest,
            routePoints: routePoints.sorted { $0.timestamp < $1.timestamp }
        )
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }
}

extension ASMRRoutePackageInput {
    struct Manifest: Codable, Equatable, Sendable {
        let schemaVersion: Int
        let packageIdentifier: UUID
        let title: String
        let walkDescription: String?
        let createdAt: Date
        let durationSeconds: TimeInterval
        let distanceMeters: Double?
        let mode: String
        let recordingSource: String
        let captureDeviceName: String?
        let routeStartedAt: Date
        let routeEndedAt: Date
        let routePointCount: Int
        let routePointsFile: String
        let sourceGPXFile: String?
        let videoReferences: [VideoReference]
        let createdBy: String
    }

    struct RoutePoint: Codable, Equatable, Sendable {
        let timestamp: Date
        let latitude: Double
        let longitude: Double
        let altitude: Double?
        let horizontalAccuracy: Double
        let speed: Double?
    }

    struct VideoReference: Codable, Equatable, Sendable {
        let kind: String
        let displayName: String
        let sourceIdentifier: String?
        let startsAt: Date?
        let offsetSeconds: TimeInterval?
        let isEmbedded: Bool
    }

    enum LoadError: LocalizedError, Equatable {
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
