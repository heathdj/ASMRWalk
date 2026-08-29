//
//  WalkRecordingPersistenceTests.swift
//  ASMR WalkTests
//

import Foundation
import CoreLocation
import AVFoundation
import CloudKit
import SwiftUI
import SwiftData
import Testing
@testable import ASMR_Walk

@MainActor
struct WalkRecordingPersistenceTests {
    @Test("Recordings can be inserted, fetched, updated, and deleted")
    func recordingLifecycle() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let recording = WalkRecording(
            title: "Original Title",
            duration: 120,
            distanceMeters: 400,
            mode: .walk,
            points: [makePoint(timestamp: 100)]
        )

        context.insert(recording)
        try context.save()

        var fetched = try context.fetch(FetchDescriptor<WalkRecording>())
        let savedRecording = try #require(fetched.first)
        #expect(fetched.count == 1)
        #expect(savedRecording.points.count == 1)

        savedRecording.title = "Updated Title"
        try context.save()

        fetched = try context.fetch(FetchDescriptor<WalkRecording>())
        #expect(fetched.first?.title == "Updated Title")

        context.delete(savedRecording)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<WalkRecording>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<LocationPoint>()) == 0)
    }

    @Test("Persistence checkpoints append only new route points")
    func persistenceCheckpointsAppendOnlyNewPoints() async throws {
        let recordingID = try #require(UUID(uuidString: "E94C5F79-B21C-4687-9345-D640978534E1"))
        let container = try makeContainer()
        let persistence = WalkRecordingPersistence(modelContainer: container)
        let firstCheckpoint = makeSnapshot(
            id: recordingID,
            duration: 30,
            distanceMeters: 90,
            pointCount: 10
        )
        let secondCheckpoint = makeSnapshot(
            id: recordingID,
            duration: 60,
            distanceMeters: 180,
            pointCount: 15
        )

        try await persistence.save(firstCheckpoint)
        try await persistence.save(secondCheckpoint)

        let recording = try #require(try fetchRecording(id: recordingID, in: container))
        #expect(recording.points.count == 15)
        #expect(recording.duration == 60)
        #expect(recording.distanceMeters == 180)
        #expect(recording.recordingSource == WalkRecordingSource.iPhone.rawValue)
        #expect(recording.routeStartedAt == firstCheckpoint.routeStartedAt)
        #expect(recording.routeEndedAt == secondCheckpoint.routeEndedAt)
        #expect(recording.pointsInTimeOrder.map(\.timestamp) == secondCheckpoint.points.map(\.timestamp))
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<WalkRecording>()) == 1)
    }

    @Test("Repeated persistence checkpoints do not duplicate points")
    func repeatedPersistenceCheckpointsDoNotDuplicatePoints() async throws {
        let recordingID = try #require(UUID(uuidString: "5E19B546-9E52-4C93-9086-4C263FB8384D"))
        let container = try makeContainer()
        let persistence = WalkRecordingPersistence(modelContainer: container)
        let checkpoint = makeSnapshot(
            id: recordingID,
            duration: 45,
            distanceMeters: 135,
            pointCount: 12
        )

        try await persistence.save(checkpoint)
        try await persistence.save(checkpoint)
        try await persistence.save(checkpoint)

        let recording = try #require(try fetchRecording(id: recordingID, in: container))
        #expect(recording.points.count == 12)
        #expect(Set(recording.points.map(\.timestamp)).count == 12)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<WalkRecording>()) == 1)
    }

    @Test("Schema hardening retains route data and local file references")
    func schemaHardeningRetainsLocalRecordingData() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let videoURL = URL(filePath: "/tmp/local-video.mov")
        let recording = WalkRecording(
            title: "Beta Walk",
            duration: 180,
            distanceMeters: 540,
            mode: .videoWalk,
            videoURL: videoURL,
            points: [
                makePoint(timestamp: 100),
                makePoint(timestamp: 120)
            ]
        )

        context.insert(recording)
        try context.save()

        let fetched = try #require(try fetchRecording(id: recording.id, in: container))
        #expect(fetched.title == "Beta Walk")
        #expect(fetched.videoURL == videoURL)
        #expect(fetched.points.count == 2)
        #expect(fetched.pointsInTimeOrder.map(\.timestamp) == recording.pointsInTimeOrder.map(\.timestamp))
    }

    @Test("Final persistence save retains all points after partial checkpoints")
    func finalPersistenceSaveRetainsAllPointsAfterPartialCheckpoints() async throws {
        let recordingID = try #require(UUID(uuidString: "8F23B3D8-6911-4193-A558-D52704386507"))
        let container = try makeContainer()
        let persistence = WalkRecordingPersistence(modelContainer: container)
        let firstCheckpoint = makeSnapshot(
            id: recordingID,
            duration: 120,
            distanceMeters: 360,
            pointCount: 40
        )
        let finalSnapshot = makeSnapshot(
            id: recordingID,
            title: "Finished Walk",
            duration: 180,
            distanceMeters: 540,
            pointCount: 75
        )

        try await persistence.save(firstCheckpoint)
        try await persistence.save(finalSnapshot)

        let recording = try #require(try fetchRecording(id: recordingID, in: container))
        #expect(recording.title == "Finished Walk")
        #expect(recording.points.count == 75)
        #expect(recording.pointsInTimeOrder.map(\.timestamp) == finalSnapshot.points.map(\.timestamp))
    }

    @Test("Final persistence save recovers points after a missed checkpoint")
    func finalPersistenceSaveRecoversPointsAfterMissedCheckpoint() async throws {
        let recordingID = try #require(UUID(uuidString: "9EB7066D-6430-4F2D-9639-A91E0505D294"))
        let container = try makeContainer()
        let persistence = WalkRecordingPersistence(modelContainer: container)
        let firstCheckpoint = makeSnapshot(
            id: recordingID,
            duration: 120,
            distanceMeters: 360,
            pointCount: 40
        )
        _ = makeSnapshot(
            id: recordingID,
            duration: 150,
            distanceMeters: 450,
            pointCount: 60
        )
        let finalSnapshot = makeSnapshot(
            id: recordingID,
            duration: 210,
            distanceMeters: 630,
            pointCount: 90
        )

        try await persistence.save(firstCheckpoint)
        try await persistence.save(finalSnapshot)

        let recording = try #require(try fetchRecording(id: recordingID, in: container))
        #expect(recording.points.count == 90)
        #expect(recording.pointsInTimeOrder.map(\.timestamp) == finalSnapshot.points.map(\.timestamp))
        #expect(recording.duration == 210)
        #expect(recording.distanceMeters == 630)
    }

    @Test("Persistence updates metadata without rewriting existing points")
    func persistenceUpdatesMetadataWithoutRewritingExistingPoints() async throws {
        let recordingID = try #require(UUID(uuidString: "2823E0B3-0866-43EA-A1D9-9404C28A0201"))
        let container = try makeContainer()
        let persistence = WalkRecordingPersistence(modelContainer: container)
        let firstCheckpoint = makeSnapshot(
            id: recordingID,
            duration: 30,
            distanceMeters: 90,
            pointCount: 8
        )
        let metadataOnlyCheckpoint = makeSnapshot(
            id: recordingID,
            title: "Updated Metadata",
            duration: 75,
            distanceMeters: 90,
            pointCount: 8
        )

        try await persistence.save(firstCheckpoint)
        try await persistence.save(metadataOnlyCheckpoint)

        let recording = try #require(try fetchRecording(id: recordingID, in: container))
        #expect(recording.title == "Updated Metadata")
        #expect(recording.duration == 75)
        #expect(recording.points.count == 8)
        #expect(recording.pointsInTimeOrder.map(\.timestamp) == metadataOnlyCheckpoint.points.map(\.timestamp))
    }

    @Test("Persistence stores Watch source and external camera timing metadata")
    func persistenceStoresWatchSourceAndExternalCameraTiming() async throws {
        let recordingID = try #require(UUID(uuidString: "F30E2C38-8714-4FA5-B30D-817AE52A0E77"))
        let routeStartedAt = Date(timeIntervalSince1970: 2_000)
        let routeEndedAt = Date(timeIntervalSince1970: 2_420)
        let externalVideoStartedAt = Date(timeIntervalSince1970: 1_995)
        let container = try makeContainer()
        let persistence = WalkRecordingPersistence(modelContainer: container)
        let snapshot = makeSnapshot(
            id: recordingID,
            createdAt: routeStartedAt,
            duration: 420,
            distanceMeters: 1_200,
            pointCount: 12,
            recordingSource: .appleWatch,
            captureDeviceName: "Apple Watch Ultra",
            routeStartedAt: routeStartedAt,
            routeEndedAt: routeEndedAt,
            externalVideoReference: "Camera A clip 001",
            externalVideoStartedAt: externalVideoStartedAt
        )

        try await persistence.save(snapshot)

        let recording = try #require(try fetchRecording(id: recordingID, in: container))
        #expect(recording.source == .appleWatch)
        #expect(recording.captureDeviceName == "Apple Watch Ultra")
        #expect(recording.routeStartedAt == routeStartedAt)
        #expect(recording.routeEndedAt == routeEndedAt)
        #expect(recording.externalVideoReference == "Camera A clip 001")
        #expect(recording.externalVideoStartedAt == externalVideoStartedAt)
    }

    @Test("Persistence applies generated metadata without overwriting user edits")
    func persistenceAppliesGeneratedMetadataWithoutOverwritingUserEdits() async throws {
        let recordingID = try #require(UUID(uuidString: "EF7D1418-0606-4013-9503-A4B3F609D17A"))
        let generatedAt = Date(timeIntervalSince1970: 2_000)
        let container = try makeContainer()
        let persistence = WalkRecordingPersistence(modelContainer: container)
        let snapshot = makeSnapshot(
            id: recordingID,
            title: "Default Walk",
            duration: 75,
            distanceMeters: 210,
            pointCount: 8
        )

        try await persistence.save(snapshot)
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<WalkRecording>(
            predicate: #Predicate { recording in
                recording.id == recordingID
            }
        )
        let recording = try #require(try context.fetch(descriptor).first)
        recording.title = "User Title"
        recording.isTitleUserEdited = true
        try context.save()

        try await persistence.updateGeneratedMetadata(
            recordingID: recordingID,
            metadata: WalkGeneratedRecordingMetadata(
                title: "Generated Title",
                walkDescription: "Generated description.",
                placeName: "Papago Park",
                generatedAt: generatedAt
            )
        )

        let updatedRecording = try #require(try fetchRecording(id: recordingID, in: container))
        #expect(updatedRecording.title == "User Title")
        #expect(updatedRecording.walkDescription == "Generated description.")
        #expect(updatedRecording.generatedPlaceName == "Papago Park")
        #expect(updatedRecording.metadataGeneratedAt == generatedAt)
    }

}
