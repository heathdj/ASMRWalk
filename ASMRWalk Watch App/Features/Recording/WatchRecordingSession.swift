//
//  WatchRecordingSession.swift
//  ASMRWalk Watch App
//

import CoreLocation
import Foundation

@MainActor
final class WatchRecordingSession {
    static let maximumHorizontalAccuracy: CLLocationAccuracy = 50
    static let minimumMovementDistance: CLLocationDistance = 3
    static let maximumLocationAge: TimeInterval = 15

    private(set) var snapshot: WalkRecordingSnapshot
    private(set) var lastAcceptedLocation: CLLocation?

    init(startedAt: Date = .now, captureDeviceName: String? = "Apple Watch") {
        snapshot = WalkRecordingSnapshot(
            id: UUID(),
            title: Self.defaultTitle(for: startedAt),
            createdAt: startedAt,
            duration: 0,
            distanceMeters: 0,
            mode: .walk,
            recordingSource: .appleWatch,
            captureDeviceName: captureDeviceName,
            routeStartedAt: startedAt,
            routeEndedAt: nil,
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

    private static func defaultTitle(for date: Date) -> String {
        "Watch Walk \(date.formatted(date: .abbreviated, time: .shortened))"
    }
}
