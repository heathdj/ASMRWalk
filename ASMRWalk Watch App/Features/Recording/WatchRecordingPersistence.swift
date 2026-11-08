//
//  WatchRecordingPersistence.swift
//  ASMRWalk Watch App
//

import Foundation
import SwiftData

@ModelActor
actor WatchRecordingPersistence {
    private var persistedPointCounts: [UUID: Int] = [:]

    func save(_ snapshot: WalkRecordingSnapshot) throws {
        let recording = try recording(for: snapshot)

        recording.title = snapshot.title
        recording.duration = snapshot.duration
        recording.distanceMeters = snapshot.distanceMeters
        recording.mode = snapshot.mode
        recording.recordingSource = snapshot.recordingSource.rawValue
        recording.captureDeviceName = snapshot.captureDeviceName
        recording.routeStartedAt = snapshot.routeStartedAt
        recording.routeEndedAt = snapshot.routeEndedAt

        appendMissingPoints(from: snapshot, to: recording)
        persistedPointCounts[snapshot.id] = max(
            persistedPointCounts[snapshot.id] ?? recording.points.count,
            snapshot.points.count
        )

        try modelContext.save()
    }

    func deleteRecording(id: UUID) throws {
        guard let recording = try fetchRecording(id: id) else {
            return
        }

        modelContext.delete(recording)
        persistedPointCounts[id] = nil
        try modelContext.save()
    }

    private func recording(for snapshot: WalkRecordingSnapshot) throws -> WalkRecording {
        if let recording = try fetchRecording(id: snapshot.id) {
            return recording
        }

        let recording = WalkRecording(
            id: snapshot.id,
            title: snapshot.title,
            createdAt: snapshot.createdAt,
            duration: snapshot.duration,
            distanceMeters: snapshot.distanceMeters,
            mode: snapshot.mode,
            recordingSource: snapshot.recordingSource,
            captureDeviceName: snapshot.captureDeviceName,
            routeStartedAt: snapshot.routeStartedAt,
            routeEndedAt: snapshot.routeEndedAt,
            points: snapshot.points.map { makeLocationPoint(from: $0) }
        )
        modelContext.insert(recording)
        return recording
    }

    private func makeLocationPoint(from snapshot: LocationPointSnapshot) -> LocationPoint {
        LocationPoint(
            timestamp: snapshot.timestamp,
            latitude: snapshot.latitude,
            longitude: snapshot.longitude,
            altitude: snapshot.altitude,
            horizontalAccuracy: snapshot.horizontalAccuracy,
            speed: snapshot.speed
        )
    }

    private func fetchRecording(id: UUID) throws -> WalkRecording? {
        let descriptor = FetchDescriptor<WalkRecording>(
            predicate: #Predicate { recording in
                recording.id == id
            }
        )
        return try modelContext.fetch(descriptor).first
    }

    private func appendMissingPoints(from snapshot: WalkRecordingSnapshot, to recording: WalkRecording) {
        let persistedPointCount = persistedPointCounts[snapshot.id] ?? recording.points.count
        guard snapshot.points.count > persistedPointCount else {
            return
        }

        for pointSnapshot in snapshot.points.dropFirst(persistedPointCount) {
            recording.points.append(makeLocationPoint(from: pointSnapshot))
        }
    }
}


extension WatchRecordingPersistence {
    func routesSaved(before date: Date, excluding receivedIDs: Set<UUID> = []) throws -> [WatchRouteTransfer] {
        let source = WalkRecordingSource.appleWatch.rawValue
        let descriptor = FetchDescriptor<WalkRecording>(predicate: #Predicate {
            $0.createdAt < date && $0.recordingSource == source
        })
        return try modelContext.fetch(descriptor).filter { receivedIDs.contains($0.id) == false }.map { recording in
            WatchRouteTransfer(id: recording.id, title: recording.title, createdAt: recording.createdAt,
                duration: recording.duration, distanceMeters: recording.distanceMeters,
                captureDeviceName: recording.captureDeviceName, routeStartedAt: recording.routeStartedAt,
                routeEndedAt: recording.routeEndedAt, points: recording.pointsInTimeOrder.map {
                    .init(timestamp: $0.timestamp, latitude: $0.latitude, longitude: $0.longitude,
                          altitude: $0.altitude, horizontalAccuracy: $0.horizontalAccuracy, speed: $0.speed)
                })
        }
    }
}

extension WalkRecordingSnapshot {
    var transfer: WatchRouteTransfer {
        WatchRouteTransfer(id: id, title: title, createdAt: createdAt, duration: duration,
            distanceMeters: distanceMeters, captureDeviceName: captureDeviceName,
            routeStartedAt: routeStartedAt, routeEndedAt: routeEndedAt, points: points.map {
                .init(timestamp: $0.timestamp, latitude: $0.latitude, longitude: $0.longitude,
                      altitude: $0.altitude, horizontalAccuracy: $0.horizontalAccuracy, speed: $0.speed)
            })
    }
}
