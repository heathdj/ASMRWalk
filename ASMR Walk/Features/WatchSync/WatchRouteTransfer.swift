import Foundation

/// A versioned value contract, shared by the Watch and iPhone targets.
nonisolated struct WatchRouteTransfer: Codable, Sendable, Equatable {
    struct Point: Codable, Sendable, Equatable {
        let timestamp: Date
        let latitude: Double
        let longitude: Double
        let altitude: Double?
        let horizontalAccuracy: Double
        let speed: Double?
    }

    var version = 1
    let id: UUID
    let title: String
    let createdAt: Date
    let duration: TimeInterval
    let distanceMeters: Double
    let captureDeviceName: String?
    let routeStartedAt: Date?
    let routeEndedAt: Date?
    let points: [Point]

    func validate() throws {
        guard version == 1, duration.isFinite, duration >= 0,
              distanceMeters.isFinite, distanceMeters >= 0,
              createdAt.timeIntervalSince1970.isFinite,
              routeStartedAt.map({ $0.timeIntervalSince1970.isFinite }) ?? true,
              routeEndedAt.map({ $0.timeIntervalSince1970.isFinite }) ?? true,
              points.count <= 1_000_000,
              points.allSatisfy({
                  $0.timestamp.timeIntervalSince1970.isFinite &&
                  $0.latitude.isFinite && (-90...90).contains($0.latitude) &&
                  $0.longitude.isFinite && (-180...180).contains($0.longitude) &&
                  $0.horizontalAccuracy.isFinite && $0.horizontalAccuracy >= 0 &&
                  ($0.altitude?.isFinite ?? true) && ($0.speed?.isFinite ?? true)
              }) else {
            throw TransferError.invalidRoute
        }
    }

    enum TransferError: LocalizedError {
        case invalidRoute
        case conflictingRecording

        var errorDescription: String? {
            switch self {
            case .invalidRoute: "The Watch route is invalid or uses an unsupported transfer version."
            case .conflictingRecording: "A different recording already uses this Watch recording identifier."
            }
        }
    }
}

/// Only immutable URLs cross delegate/actor boundaries. Every write is atomic;
/// received files survive process suspension before SwiftData import completes.
nonisolated struct WatchTransferFiles: Sendable {
    let root: URL

    static var standard: Self {
        Self(root: URL.applicationSupportDirectory.appending(path: "WatchTransfers", directoryHint: .isDirectory))
    }

    func directory(_ name: String) throws -> URL {
        let url = root.appending(path: name, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func receiptExists(_ id: UUID) -> Bool {
        FileManager.default.fileExists(atPath: root.appending(path: "Receipts/\(id.uuidString)").path)
    }

    func acknowledgedIDs() throws -> Set<UUID> {
        Set(try FileManager.default.contentsOfDirectory(atPath: directory("Receipts").path)
            .compactMap(UUID.init(uuidString:)))
    }

    func recordReceipt(_ id: UUID) throws {
        try Data().write(to: directory("Receipts").appending(path: id.uuidString), options: .atomic)
    }

    func enqueue(_ route: WatchRouteTransfer) throws {
        try route.validate()
        guard receiptExists(route.id) == false else { return }
        let destination = try directory("Outbox").appending(path: "\(route.id.uuidString).json")
        guard FileManager.default.fileExists(atPath: destination.path) == false else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        try encoder.encode(route).write(to: destination, options: .atomic)
    }

    func files(in directoryName: String) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: directory(directoryName), includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    func acknowledge(_ id: UUID) throws {
        // Persist the receipt before removing the retry source.
        try recordReceipt(id)
        let url = try directory("Outbox").appending(path: "\(id.uuidString).json")
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    func receive(_ source: URL) throws -> URL {
        let destination = try directory("Inbox").appending(path: "\(UUID().uuidString).json")
        try FileManager.default.moveItem(at: source, to: destination)
        return destination
    }

    func decode(_ url: URL) throws -> WatchRouteTransfer {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber, size.intValue <= 128 * 1_024 * 1_024 else {
            throw WatchRouteTransfer.TransferError.invalidRoute
        }
        let route = try JSONDecoder().decode(WatchRouteTransfer.self, from: Data(contentsOf: url))
        try route.validate()
        return route
    }
}


nonisolated enum WatchRouteDelivery {
    @concurrent
    static func importFile(
        _ url: URL,
        files: WatchTransferFiles,
        importRoute: @Sendable (WatchRouteTransfer) async throws -> Void
    ) async throws -> UUID {
        let route = try files.decode(url)
        if files.receiptExists(route.id) == false {
            try await importRoute(route)
            try files.recordReceipt(route.id)
        }
        return route.id
    }
}
