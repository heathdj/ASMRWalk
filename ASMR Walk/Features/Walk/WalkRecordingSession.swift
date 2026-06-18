//
//  WalkRecordingSession.swift
//  ASMR Walk
//

import CoreLocation
import Foundation

@MainActor
final class WalkRecordingSession {
    static let maximumHorizontalAccuracy: CLLocationAccuracy = 50
    static let minimumMovementDistance: CLLocationDistance = 3
    static let maximumLocationAge: TimeInterval = 15

    let recording: WalkRecording
    private(set) var lastAcceptedLocation: CLLocation?

    init(startedAt: Date = .now, mode: RecordingMode = .walk) {
        recording = WalkRecording(
            title: Self.defaultTitle(for: startedAt, mode: mode),
            createdAt: startedAt,
            mode: mode
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
            recording.distanceMeters += distance
        }

        recording.addPoint(
            LocationPoint(
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
        recording.duration = max(0, date.timeIntervalSince(recording.createdAt))
    }

    private static func defaultTitle(for date: Date, mode: RecordingMode) -> String {
        "\(mode.title) \(date.formatted(date: .abbreviated, time: .shortened))"
    }
}
