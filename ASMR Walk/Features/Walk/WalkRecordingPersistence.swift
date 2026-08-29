//
//  WalkRecordingPersistence.swift
//  ASMR Walk
//

import Foundation
import SwiftData

@ModelActor
actor WalkRecordingPersistence {
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
        recording.externalVideoReference = snapshot.externalVideoReference
        recording.externalVideoStartedAt = snapshot.externalVideoStartedAt
        recording.videoURL = snapshot.videoURL
        recording.videoAssetIdentifier = snapshot.videoAssetIdentifier

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

    func updateGeneratedMetadata(
        recordingID: UUID,
        metadata: WalkGeneratedRecordingMetadata
    ) throws {
        guard let recording = try fetchRecording(id: recordingID) else {
            return
        }

        if recording.isTitleUserEdited == false {
            recording.title = metadata.title
        }

        if recording.isDescriptionUserEdited == false {
            recording.walkDescription = metadata.walkDescription
        }

        recording.generatedPlaceName = metadata.placeName
        recording.metadataGeneratedAt = metadata.generatedAt
        try modelContext.save()
    }

    func updateThumbnailURL(recordingID: UUID, thumbnailURL: URL, styleVersion: Int) throws {
        guard let recording = try fetchRecording(id: recordingID) else {
            return
        }

        recording.thumbnailURL = thumbnailURL
        recording.thumbnailStyleVersion = styleVersion
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
            externalVideoReference: snapshot.externalVideoReference,
            externalVideoStartedAt: snapshot.externalVideoStartedAt,
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
