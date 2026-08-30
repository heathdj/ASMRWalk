//
//  WatchRecordingModels.swift
//  ASMRWalk Watch App
//

import CoreLocation
import Foundation
import SwiftData

nonisolated enum RecordingMode: String, Codable, CaseIterable, Sendable {
    case walk
    case videoWalk

    var title: String {
        switch self {
        case .walk:
            "Walk"
        case .videoWalk:
            "Video Walk"
        }
    }
}

enum WalkRecordingSource: String, Codable, CaseIterable, Sendable {
    case iPhone
    case appleWatch

    var title: String {
        switch self {
        case .iPhone:
            "iPhone"
        case .appleWatch:
            "Apple Watch"
        }
    }
}

enum WalkRecordingVideoStoragePolicy: String, Codable, CaseIterable, Sendable {
    case localOnly
}

@Model
final class LocationPoint {
    var timestamp: Date = Date.now
    var latitude: Double = 0
    var longitude: Double = 0
    var altitude: Double?
    var horizontalAccuracy: Double = 0
    var speed: Double?
    var recording: WalkRecording?

    init(
        timestamp: Date,
        latitude: Double,
        longitude: Double,
        altitude: Double? = nil,
        horizontalAccuracy: Double,
        speed: Double? = nil
    ) {
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
        self.speed = speed
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

@Model
final class WalkRecording {
    static let shortRecordingThreshold: TimeInterval = 10

    #Index<WalkRecording>([\.createdAt])

    var id: UUID = UUID()
    var title: String = ""
    var createdAt: Date = Date.now
    var duration: TimeInterval = 0
    var distanceMeters: Double = 0
    var mode: RecordingMode = RecordingMode.walk
    var walkDescription: String = ""
    var generatedPlaceName: String?
    var metadataGeneratedAt: Date?
    var isTitleUserEdited: Bool = false
    var isDescriptionUserEdited: Bool = false
    var titleEditedAt: Date?
    var descriptionEditedAt: Date?
    var recordingSource: String = WalkRecordingSource.appleWatch.rawValue
    var captureDeviceName: String?
    var routeStartedAt: Date?
    var routeEndedAt: Date?
    var externalVideoReference: String?
    var externalVideoStartedAt: Date?
    var videoURL: URL?
    var videoAssetIdentifier: String?
    var videoStoragePolicy: String = WalkRecordingVideoStoragePolicy.localOnly.rawValue
    var thumbnailURL: URL?
    var thumbnailStyleVersion: Int = 0

    @Relationship(deleteRule: .cascade, originalName: "points", inverse: \LocationPoint.recording)
    private var storedPoints: [LocationPoint]?

    var points: [LocationPoint] {
        get { storedPoints ?? [] }
        set { storedPoints = newValue }
    }

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = .now,
        duration: TimeInterval = 0,
        distanceMeters: Double = 0,
        mode: RecordingMode = .walk,
        recordingSource: WalkRecordingSource = .appleWatch,
        captureDeviceName: String? = nil,
        routeStartedAt: Date? = nil,
        routeEndedAt: Date? = nil,
        points: [LocationPoint] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.duration = duration
        self.distanceMeters = distanceMeters
        self.mode = mode
        self.recordingSource = recordingSource.rawValue
        self.captureDeviceName = captureDeviceName
        self.routeStartedAt = routeStartedAt
        self.routeEndedAt = routeEndedAt
        self.storedPoints = points
    }

    var pointsInTimeOrder: [LocationPoint] {
        points.sorted { $0.timestamp < $1.timestamp }
    }
}

struct LocationPointSnapshot: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let latitude: Double
    let longitude: Double
    let altitude: Double?
    let horizontalAccuracy: Double
    let speed: Double?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct WalkRecordingSnapshot: Identifiable, Sendable {
    let id: UUID
    var title: String
    let createdAt: Date
    var duration: TimeInterval
    var distanceMeters: Double
    var mode: RecordingMode
    var recordingSource: WalkRecordingSource
    var captureDeviceName: String?
    var routeStartedAt: Date?
    var routeEndedAt: Date?
    var points: [LocationPointSnapshot]
}

enum CloudSyncConfiguration {
    static let containerIdentifier = "iCloud.com.bald-traveler.ASMRWalk"
}

enum WatchModelContainerFactory {
    static let schema = Schema([WalkRecording.self, LocationPoint.self])

    static func makeModelContainer(
        cloudSyncEnabled: Bool = true,
        isStoredInMemoryOnly: Bool = false
    ) -> ModelContainer {
        let configuration: ModelConfiguration
        if isStoredInMemoryOnly {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else if cloudSyncEnabled {
            configuration = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private(CloudSyncConfiguration.containerIdentifier)
            )
        } else {
            configuration = ModelConfiguration(schema: schema)
        }

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Unable to create ASMR Walk Watch model container: \(error.localizedDescription)")
        }
    }
}
