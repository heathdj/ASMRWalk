//
//  WalkRecordingPersistence.swift
//  ASMR Walk
//

import Foundation
import SwiftData

@ModelActor
actor WalkRecordingPersistence {
    func save(_ snapshot: WalkRecordingSnapshot) throws {
        let recording = try recording(for: snapshot)

        recording.title = snapshot.title
        recording.duration = snapshot.duration
        recording.distanceMeters = snapshot.distanceMeters
        recording.mode = snapshot.mode
        recording.videoURL = snapshot.videoURL
        recording.videoAssetIdentifier = snapshot.videoAssetIdentifier

        for point in recording.points {
            modelContext.delete(point)
        }
        recording.points = snapshot.points.map { makeLocationPoint(from: $0) }

        try modelContext.save()
    }

    func deleteRecording(id: UUID) throws {
        guard let recording = try fetchRecording(id: id) else {
            return
        }

        modelContext.delete(recording)
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
            videoURL: snapshot.videoURL,
            videoAssetIdentifier: snapshot.videoAssetIdentifier,
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
}
