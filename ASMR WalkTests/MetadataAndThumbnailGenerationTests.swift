//
//  MetadataAndThumbnailGenerationTests.swift
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
struct MetadataAndThumbnailGenerationTests {
    @Test("Generated recording metadata uses place name for title")
    func generatedRecordingMetadata() throws {
        let metadata = try #require(WalkRecordingMetadataBuilder.metadata(
            for: WalkPlaceMetadata(
                name: "Papago Park",
                subLocality: "Camelback East",
                locality: "Phoenix",
                administrativeArea: "Arizona",
                country: "United States"
            ),
            mode: .videoWalk,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            duration: 125,
            distanceMeters: 840,
            generatedAt: Date(timeIntervalSince1970: 2_000)
        ))

        #expect(metadata.title == "Papago Park Video Walk")
        #expect(metadata.placeName == "Papago Park")
        #expect(metadata.walkDescription.contains("Video Walk near Papago Park"))
        #expect(metadata.walkDescription.contains("2:05"))
        #expect(metadata.generatedAt == Date(timeIntervalSince1970: 2_000))
    }

    @Test("Generated recording metadata falls back when no place name exists")
    func generatedRecordingMetadataRequiresPlaceName() {
        let metadata = WalkRecordingMetadataBuilder.metadata(
            for: WalkPlaceMetadata(),
            mode: .walk,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            duration: 125,
            distanceMeters: 840
        )

        #expect(metadata == nil)
    }

    @Test("Route metadata uses the middle point for place lookup")
    func routeMetadataRepresentativeCoordinate() throws {
        let createdAt = Date(timeIntervalSince1970: 1_000)
        let snapshot = makeSnapshot(
            id: UUID(),
            createdAt: createdAt,
            duration: 30,
            distanceMeters: 90,
            pointCount: 5
        )

        let coordinate = try #require(WalkRecordingMetadataGenerator.representativeCoordinate(from: snapshot.points))

        #expect(coordinate.latitude == snapshot.points[2].latitude)
        #expect(coordinate.longitude == snapshot.points[2].longitude)
    }

    @Test("Metadata generator updates saved recordings when place lookup succeeds")
    func metadataGeneratorUpdatesSavedRecordings() async throws {
        let recordingID = try #require(UUID(uuidString: "45C81AB1-0404-4C6A-AAB2-14AD16437F32"))
        let generatedAt = Date(timeIntervalSince1970: 4_000)
        let container = try makeContainer()
        let persistence = WalkRecordingPersistence(modelContainer: container)
        let snapshot = makeSnapshot(
            id: recordingID,
            title: "Aug 13, 2026 Walk",
            createdAt: Date(timeIntervalSince1970: 1_800),
            duration: 95,
            distanceMeters: 420,
            pointCount: 5,
            latitude: 33.5000,
            longitude: -112.1000
        )

        try await persistence.save(snapshot)

        await WalkRecordingMetadataGenerator.generate(
            for: snapshot,
            in: container,
            geocoder: FakeWalkPlaceGeocoder(metadata: WalkPlaceMetadata(name: "Encanto Park")),
            date: generatedAt
        )

        let recording = try #require(try fetchRecording(id: recordingID, in: container))
        #expect(recording.title == "Encanto Park Walk")
        #expect(recording.walkDescription.contains("Walk near Encanto Park"))
        #expect(recording.generatedPlaceName == "Encanto Park")
        #expect(recording.metadataGeneratedAt == generatedAt)
    }

    @Test("Metadata generator leaves saved recordings alone when place lookup fails")
    func metadataGeneratorIgnoresLookupFailures() async throws {
        let recordingID = try #require(UUID(uuidString: "075250E1-CF1B-49E6-AC6A-317A7A046470"))
        let container = try makeContainer()
        let persistence = WalkRecordingPersistence(modelContainer: container)
        let snapshot = makeSnapshot(
            id: recordingID,
            title: "Fallback Walk",
            duration: 95,
            distanceMeters: 420,
            pointCount: 5,
            latitude: 33.6000,
            longitude: -112.2000
        )

        try await persistence.save(snapshot)

        await WalkRecordingMetadataGenerator.generate(
            for: snapshot,
            in: container,
            geocoder: FailingWalkPlaceGeocoder()
        )

        let recording = try #require(try fetchRecording(id: recordingID, in: container))
        #expect(recording.title == "Fallback Walk")
        #expect(recording.walkDescription.isEmpty)
        #expect(recording.generatedPlaceName == nil)
        #expect(recording.metadataGeneratedAt == nil)
    }

    @Test("Persistence stores generated route thumbnail URLs")
    func persistenceStoresGeneratedRouteThumbnailURLs() async throws {
        let recordingID = try #require(UUID(uuidString: "CC9044A6-89AF-4BA9-9B8F-C4CC25E4313F"))
        let thumbnailURL = URL(filePath: "/tmp/route-thumbnail.jpg")
        let container = try makeContainer()
        let persistence = WalkRecordingPersistence(modelContainer: container)
        let snapshot = makeSnapshot(
            id: recordingID,
            title: "Thumbnail Walk",
            duration: 75,
            distanceMeters: 210,
            pointCount: 8
        )

        try await persistence.save(snapshot)
        try await persistence.updateThumbnailURL(
            recordingID: recordingID,
            thumbnailURL: thumbnailURL,
            styleVersion: WalkRouteThumbnailGenerator.styleVersion
        )

        let recording = try #require(try fetchRecording(id: recordingID, in: container))
        #expect(recording.thumbnailURL == thumbnailURL)
        #expect(recording.thumbnailStyleVersion == WalkRouteThumbnailGenerator.styleVersion)
    }

    @Test("Route thumbnail filenames are tied to recording IDs")
    func routeThumbnailFilenamesAreTiedToRecordingIDs() throws {
        let recordingID = try #require(UUID(uuidString: "C88807DA-8957-4B6F-A6C7-1D1C37BA9515"))
        let url = try WalkRouteThumbnailGenerator.thumbnailURL(recordingID: recordingID)

        #expect(WalkRouteThumbnailGenerator.styleVersion == 1)
        #expect(url.lastPathComponent == "\(recordingID.uuidString).jpg")
        #expect(url.deletingLastPathComponent().lastPathComponent == "Route Thumbnails")
    }
}
