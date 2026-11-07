//
//  ASMRRoutePackageInput.swift
//  ASMRWalkRouteOverlay
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ASMRRoutePackageInput: Equatable, Sendable {
    static let expectedSchemaVersion = 3
    static let minimumSupportedSchemaVersion = 1
    static let manifestFilename = "manifest.json"

    let manifest: Manifest
    let routePoints: [RoutePoint]
    let mapBackgroundData: Data?
    let mapBackgroundDataByFilename: [String: Data]

    init(
        manifest: Manifest,
        routePoints: [RoutePoint],
        mapBackgroundData: Data? = nil,
        mapBackgroundDataByFilename: [String: Data] = [:]
    ) {
        self.manifest = manifest
        self.routePoints = routePoints
        self.mapBackgroundData = mapBackgroundData
        self.mapBackgroundDataByFilename = mapBackgroundDataByFilename
    }

    static func load(from packageURL: URL) throws -> ASMRRoutePackageInput {
        let manifestURL = packageURL.appending(path: manifestFilename)
        let manifest = try decode(Manifest.self, from: Data(contentsOf: manifestURL))

        guard (minimumSupportedSchemaVersion...expectedSchemaVersion).contains(manifest.schemaVersion) else {
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

        let sortedRoutePoints = routePoints.enumerated().sorted { lhs, rhs in
            if lhs.element.timestamp == rhs.element.timestamp {
                return lhs.offset < rhs.offset
            }

            return lhs.element.timestamp < rhs.element.timestamp
        }.map(\.element)

        let mapBackgroundData = manifest.mapBackground.flatMap {
            try? Data(contentsOf: packageURL.appending(path: $0.filename))
        }
        let backgrounds = [manifest.mapBackground].compactMap { $0 } + (manifest.mapBackgrounds ?? [])
        let filenames = Set(backgrounds.flatMap(\.assetFilenames))
        let mapBackgroundDataByFilename = Dictionary(uniqueKeysWithValues: filenames.compactMap { filename in
            (try? Data(contentsOf: packageURL.appending(path: filename))).map { (filename, $0) }
        })

        return ASMRRoutePackageInput(
            manifest: manifest,
            routePoints: sortedRoutePoints,
            mapBackgroundData: mapBackgroundData,
            mapBackgroundDataByFilename: mapBackgroundDataByFilename
        )
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }

    func decodedMapBackground() -> ASMRRouteOverlayBitmap? {
        decodedSingleMapBackground()?.bitmap
    }

    func decodedSingleMapBackground() -> DecodedMapBackground? {
        guard let metadata = manifest.mapBackground else { return nil }
        return decodedBackground(metadata: metadata, lightData: mapBackgroundData)
    }

    func decodedMapBackgrounds() -> [DecodedMapBackground] {
        (manifest.mapBackgrounds ?? []).compactMap { metadata in
            decodedBackground(metadata: metadata, lightData: mapBackgroundDataByFilename[metadata.filename])
        }
    }

    private func decodedBackground(metadata: MapBackground, lightData: Data?) -> DecodedMapBackground? {
        let light = lightData.flatMap { Self.decodeMapBackground(data: $0, metadata: metadata) }
        let dark = metadata.darkFilename.flatMap { mapBackgroundDataByFilename[$0] }
            .flatMap { Self.decodeMapBackground(data: $0, metadata: metadata) }
        guard let bitmap = light ?? dark else { return nil }
        return DecodedMapBackground(metadata: metadata, bitmap: bitmap, darkBitmap: dark,
                                    lightUsesDarkFallback: light == nil)
    }

    private static func decodeMapBackground(
        data: Data,
        metadata: MapBackground
    ) -> ASMRRouteOverlayBitmap? {
        guard metadata.pixelWidth > 0,
              metadata.pixelHeight > 0,
              metadata.scale > 0,
              metadata.mapRectWidth > 0,
              metadata.mapRectHeight > 0,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetType(source) as String? == UTType.png.identifier,
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              image.width == metadata.pixelWidth,
              image.height == metadata.pixelHeight else {
            return nil
        }

        var bitmap = ASMRRouteOverlayBitmap(width: image.width, height: image.height)
        let rendered = bitmap.rgbaPixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let baseAddress = bytes.baseAddress,
                  let context = CGContext(
                    data: baseAddress,
                    width: image.width,
                    height: image.height,
                    bitsPerComponent: 8,
                    bytesPerRow: image.width * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else { return false }
            // CGImage drawing already preserves PNG scanline order in this bitmap.
            // Keep row zero north-up to match the route projection.
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        return rendered ? bitmap : nil
    }

    var mapAvailability: ASMRRouteMapAvailability {
        if let expectedSegments = manifest.mapBackgrounds, expectedSegments.isEmpty == false {
            let availableCount = decodedMapBackgrounds().count
            return availableCount == 0
                ? .unusable
                : .segmented(available: availableCount, total: expectedSegments.count)
        }
        let hasMapMetadata = manifest.mapBackground != nil
        guard hasMapMetadata else { return .routeOnly }
        return decodedMapBackground() == nil ? .unusable : .available
    }

    struct DecodedMapBackground: Equatable, Sendable {
        let metadata: MapBackground
        let bitmap: ASMRRouteOverlayBitmap
        var darkBitmap: ASMRRouteOverlayBitmap? = nil
        var lightUsesDarkFallback = false

        func bitmap(for appearance: ASMRRouteMapAppearance) -> ASMRRouteOverlayBitmap {
            appearance == .dark ? darkBitmap ?? bitmap : bitmap
        }

        func filename(for appearance: ASMRRouteMapAppearance) -> String {
            if (appearance == .dark && darkBitmap != nil) || lightUsesDarkFallback {
                return metadata.darkFilename ?? metadata.filename
            }
            return metadata.filename
        }
    }
}

enum ASMRRouteMapAppearance: Int, Codable, CaseIterable, Sendable {
    case light
    case dark
}

enum ASMRRouteMapAvailability: Equatable, Sendable {
    case available
    case segmented(available: Int, total: Int)
    case routeOnly
    case unusable

    var statusMessage: String {
        switch self {
        case .available:
            "Map Background available"
        case let .segmented(available, total):
            available == total
                ? "Segmented Map Background available — \(total) local segments"
                : "Segmented Map Background degraded — \(available) of \(total) local segments available"
        case .routeOnly:
            "Route Only — this package does not contain a map background"
        case .unusable:
            "Route Only — the map background is missing, corrupt, unsupported, or does not match its metadata"
        }
    }

    var isAvailable: Bool {
        switch self {
        case .available, .segmented:
            true
        case .routeOnly, .unusable:
            false
        }
    }
}

final class ASMRRouteOverlayPackageCache: @unchecked Sendable {
    struct PreparedPackage: Sendable {
        let routePackage: ASMRRoutePackageInput
        let mapBackground: ASMRRouteOverlayBitmap?
        let mapBackgrounds: [ASMRRoutePackageInput.DecodedMapBackground]
        var singleMapBackground: ASMRRoutePackageInput.DecodedMapBackground? = nil

        func bitmap(filename: String) -> ASMRRouteOverlayBitmap? {
            let backgrounds = [singleMapBackground].compactMap { $0 } + mapBackgrounds
            for background in backgrounds {
                if background.filename(for: .light) == filename { return background.bitmap }
                if background.metadata.darkFilename == filename { return background.darkBitmap }
            }
            return nil
        }

        var mapAvailability: ASMRRouteMapAvailability {
            if let expectedSegments = routePackage.manifest.mapBackgrounds,
               expectedSegments.isEmpty == false {
                return mapBackgrounds.isEmpty
                    ? .unusable
                    : .segmented(available: mapBackgrounds.count, total: expectedSegments.count)
            }
            let hasMapMetadata = routePackage.manifest.mapBackground != nil
            guard hasMapMetadata else { return .routeOnly }
            return mapBackground == nil ? .unusable : .available
        }
    }

    private struct ModificationState: Equatable {
        let manifest: Date?
        let routePoints: Date?
        let mapBackgrounds: [String: Date?]
    }

    private struct Entry {
        let modificationState: ModificationState
        let preparedPackage: PreparedPackage
    }

    private let lock = NSLock()
    private var entries: [URL: Entry] = [:]
    private(set) var loadCount = 0

    func cachedPreparedPackage(at packageURL: URL) -> PreparedPackage? {
        let canonicalURL = packageURL.standardizedFileURL
        return lock.withLock { entries[canonicalURL]?.preparedPackage }
    }

    func preparedPackage(at packageURL: URL) throws -> PreparedPackage {
        let canonicalURL = packageURL.standardizedFileURL
        return try lock.withLock {
            let state = try modificationState(at: canonicalURL)
            if let entry = entries[canonicalURL], entry.modificationState == state {
                return entry.preparedPackage
            }

            let package = try ASMRRoutePackageInput.load(from: canonicalURL)
            let singleMapBackground = package.decodedSingleMapBackground()
            let preparedPackage = PreparedPackage(
                routePackage: package,
                mapBackground: singleMapBackground?.bitmap,
                mapBackgrounds: package.decodedMapBackgrounds(),
                singleMapBackground: singleMapBackground
            )
            entries[canonicalURL] = Entry(
                modificationState: state,
                preparedPackage: preparedPackage
            )
            loadCount += 1
            return preparedPackage
        }
    }

    private func modificationState(at packageURL: URL) throws -> ModificationState {
        let manifestURL = packageURL.appending(path: ASMRRoutePackageInput.manifestFilename)
        let manifestData = try Data(contentsOf: manifestURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(ASMRRoutePackageInput.Manifest.self, from: manifestData)

        return ModificationState(
            manifest: modificationDate(for: manifestURL),
            routePoints: modificationDate(for: packageURL.appending(path: manifest.routePointsFile)),
            mapBackgrounds: Dictionary(
                uniqueKeysWithValues: Set(([manifest.mapBackground].compactMap { $0 } + (manifest.mapBackgrounds ?? []))
                    .flatMap(\.assetFilenames)).map { filename in
                        (filename, modificationDate(for: packageURL.appending(path: filename)))
                    }
            )
        )
    }

    private func modificationDate(for url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
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
        var primaryVideoReferenceIndex: Int? = nil
        var mapBackground: MapBackground? = nil
        var mapBackgrounds: [MapBackground]? = nil
        let createdBy: String
    }

    struct MapBackground: Codable, Equatable, Sendable {
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
        // Both appearances share the projection and segment timing above.
        var darkFilename: String? = nil

        var assetFilenames: [String] {
            [filename] + [darkFilename].compactMap { $0 }
        }
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

struct ASMRRouteTimingAlignment: Equatable, Sendable {
    enum MetadataSource: Equatable, Sendable {
        case primaryVideoReference
        case singleVideoReference
        case noVideoReference
        case ambiguousVideoReferences
    }

    let packageOffsetSeconds: TimeInterval
    let explicitOffsetSeconds: TimeInterval
    let metadataSource: MetadataSource

    var totalOffsetSeconds: TimeInterval {
        packageOffsetSeconds + explicitOffsetSeconds
    }

    var statusMessage: String {
        switch metadataSource {
        case .primaryVideoReference, .singleVideoReference:
            "Package timing: \(packageOffsetSeconds.formatted(.number.precision(.fractionLength(2)))) s"
        case .noVideoReference:
            "No package video timing; using manual offset only"
        case .ambiguousVideoReferences:
            "Multiple video references; using manual offset only"
        }
    }

    static func resolve(
        manifest: ASMRRoutePackageInput.Manifest,
        explicitOffsetSeconds: TimeInterval
    ) -> ASMRRouteTimingAlignment {
        let reference: ASMRRoutePackageInput.VideoReference?
        let source: MetadataSource

        if let index = manifest.primaryVideoReferenceIndex,
           manifest.videoReferences.indices.contains(index) {
            reference = manifest.videoReferences[index]
            source = .primaryVideoReference
        } else if manifest.videoReferences.count == 1 {
            reference = manifest.videoReferences[0]
            source = .singleVideoReference
        } else if manifest.videoReferences.isEmpty {
            reference = nil
            source = .noVideoReference
        } else {
            reference = nil
            source = .ambiguousVideoReferences
        }

        let packageOffset = reference.flatMap { reference in
            reference.offsetSeconds
                ?? reference.startsAt?.timeIntervalSince(manifest.routeStartedAt)
        } ?? 0

        return ASMRRouteTimingAlignment(
            packageOffsetSeconds: packageOffset,
            explicitOffsetSeconds: explicitOffsetSeconds,
            metadataSource: source
        )
    }
}

struct ASMRRoutePackageSelection: Codable, Equatable, Sendable {
    let bookmarkData: Data
    let displayName: String
    let lastKnownPath: String

    func encoded() throws -> String {
        try JSONEncoder().encode(self).base64EncodedString()
    }

    static func decode(_ encoded: String) throws -> ASMRRoutePackageSelection {
        guard let data = Data(base64Encoded: encoded) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "The saved route-package selection is invalid.")
            )
        }
        return try JSONDecoder().decode(Self.self, from: data)
    }
}
