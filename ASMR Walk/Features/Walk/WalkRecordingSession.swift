//
//  WalkRecordingSession.swift
//  ASMR Walk
//

import CoreLocation
import Foundation

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
    var externalVideoReference: String?
    var externalVideoStartedAt: Date?
    var videoURL: URL?
    var videoAssetIdentifier: String?
    var points: [LocationPointSnapshot]

    var hasVideo: Bool {
        videoAssetIdentifier != nil || videoURL != nil
    }

    var isShortRecording: Bool {
        duration < WalkRecording.shortRecordingThreshold
    }
}

@MainActor
final class WalkRecordingSession {
    static let maximumHorizontalAccuracy: CLLocationAccuracy = 50
    static let minimumMovementDistance: CLLocationDistance = 3
    static let maximumLocationAge: TimeInterval = 15

    private(set) var snapshot: WalkRecordingSnapshot
    private(set) var lastAcceptedLocation: CLLocation?

    init(startedAt: Date = .now, mode: RecordingMode = .walk) {
        snapshot = WalkRecordingSnapshot(
            id: UUID(),
            title: Self.defaultTitle(for: startedAt, mode: mode),
            createdAt: startedAt,
            duration: 0,
            distanceMeters: 0,
            mode: mode,
            recordingSource: .iPhone,
            captureDeviceName: nil,
            routeStartedAt: startedAt,
            routeEndedAt: nil,
            externalVideoReference: nil,
            externalVideoStartedAt: nil,
            points: []
        )
    }

    @discardableResult
    func accept(_ location: CLLocation, now: Date = .now) -> Bool {
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= Self.maximumHorizontalAccuracy,
              abs(location.timestamp.timeIntervalSince(now)) <= Self.maximumLocationAge else {
            return false
        }

        if let lastAcceptedLocation {
            let distance = location.distance(from: lastAcceptedLocation)
            guard distance >= Self.minimumMovementDistance else {
                return false
            }
            snapshot.distanceMeters += distance
        }

        snapshot.points.append(
            LocationPointSnapshot(
                timestamp: location.timestamp,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                altitude: location.verticalAccuracy >= 0 ? location.altitude : nil,
                horizontalAccuracy: location.horizontalAccuracy,
                speed: location.speed >= 0 ? location.speed : nil
            )
        )
        lastAcceptedLocation = location
        return true
    }

    func updateDuration(at date: Date = .now) {
        snapshot.duration = max(0, date.timeIntervalSince(snapshot.createdAt))
        snapshot.routeEndedAt = date
    }

    func attachVideo(at url: URL) {
        snapshot.mode = .videoWalk
        snapshot.videoURL = url
    }

    func attachPhotoLibraryVideo(assetIdentifier: String) {
        snapshot.mode = .videoWalk
        snapshot.videoAssetIdentifier = assetIdentifier
        snapshot.videoURL = nil
    }

    private static func defaultTitle(for date: Date, mode: RecordingMode) -> String {
        "\(mode.title) \(date.formatted(date: .abbreviated, time: .shortened))"
    }
}
