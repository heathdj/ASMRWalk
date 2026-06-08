//
//  ASMR_WalkTests.swift
//  ASMR WalkTests
//
//  Created by David Heath on 5/24/26.
//

import Foundation
import SwiftData
import Testing
@testable import ASMR_Walk

@MainActor
struct ASMR_WalkTests {
    @Test("The app exposes its three primary destinations")
    func primaryDestinations() {
        #expect(AppTab.allCases.count == 3)
        #expect(AppTab.allCases == [.history, .walk, .videoWalk])
    }

    @Test(
        "Each destination has the expected presentation",
        arguments: [
            (AppTab.history, "History", "clock.arrow.circlepath"),
            (AppTab.walk, "Walk", "figure.walk"),
            (AppTab.videoWalk, "Video Walk", "video.fill")
        ]
    )
    func destinationPresentation(tab: AppTab, title: String, systemImage: String) {
        #expect(tab.title == title)
        #expect(tab.systemImage == systemImage)
    }

    @Test("Destination titles and symbols are unique")
    func destinationPresentationIsUnique() {
        let titles = AppTab.allCases.map(\.title)
        let systemImages = AppTab.allCases.map(\.systemImage)

        #expect(Set(titles).count == titles.count)
        #expect(Set(systemImages).count == systemImages.count)
    }
}

@MainActor
struct WalkRecordingTests {
    @Test("A new walk stores its metadata and defaults")
    func recordingMetadata() {
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let recording = WalkRecording(
            title: "Test Walk",
            createdAt: createdAt,
            duration: 300,
            distanceMeters: 800,
            mode: .walk
        )

        #expect(recording.title == "Test Walk")
        #expect(recording.createdAt == createdAt)
        #expect(recording.duration == 300)
        #expect(recording.distanceMeters == 800)
        #expect(recording.mode == .walk)
        #expect(recording.points.isEmpty)
        #expect(recording.hasVideo == false)
    }

    @Test("Adding a point includes it in time-ordered route data")
    func addingPoints() {
        let recording = WalkRecording(title: "Test Walk", mode: .walk)
        let laterPoint = makePoint(timestamp: 200)
        let earlierPoint = makePoint(timestamp: 100)

        recording.addPoint(laterPoint)
        recording.addPoint(earlierPoint)

        #expect(recording.points.count == 2)
        #expect(recording.pointsInTimeOrder.map(\.timestamp) == [
            earlierPoint.timestamp,
            laterPoint.timestamp
        ])
    }

    @Test("Video presence is derived from its file URL")
    func videoPresence() {
        let walk = WalkRecording(title: "Walk", mode: .walk)
        let videoWalk = WalkRecording(
            title: "Video Walk",
            mode: .videoWalk,
            videoURL: URL(filePath: "/test/video.mov")
        )

        #expect(walk.hasVideo == false)
        #expect(videoWalk.hasVideo)
    }

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

    @Test("Sample data contains both recording modes")
    func sampleData() {
        #expect(SampleData.recordings.count == 2)
        #expect(Set(SampleData.recordings.map(\.mode)) == Set(RecordingMode.allCases))
        #expect(SampleData.recordings.allSatisfy { $0.points.isEmpty == false })
    }

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: WalkRecording.self,
            LocationPoint.self,
            configurations: configuration
        )
    }

    private func makePoint(timestamp: TimeInterval) -> LocationPoint {
        LocationPoint(
            timestamp: Date(timeIntervalSince1970: timestamp),
            latitude: 33.4484,
            longitude: -112.0740,
            horizontalAccuracy: 5
        )
    }
}
