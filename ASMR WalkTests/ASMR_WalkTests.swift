//
//  ASMR_WalkTests.swift
//  ASMR WalkTests
//
//  Created by David Heath on 5/24/26.
//

import Foundation
import CoreLocation
import SwiftUI
import SwiftData
import Testing
@testable import ASMR_Walk

@MainActor
struct ASMR_WalkTests {
    @Test("The app exposes its primary destinations")
    func primaryDestinations() {
        #expect(AppTab.allCases.count == 4)
        #expect(AppTab.allCases == [.history, .walk, .videoWalk, .settings])
    }

    @Test(
        "Each destination has the expected presentation",
        arguments: [
            (AppTab.history, "History", "clock.arrow.circlepath"),
            (AppTab.walk, "Walk", "figure.walk"),
            (AppTab.videoWalk, "Video Walk", "video.fill"),
            (AppTab.settings, "Settings", "gearshape.fill")
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

    @Test("Theme choices map to the expected app color scheme")
    func appThemePresentation() {
        #expect(AppTheme.system.title == "System")
        #expect(AppTheme.system.colorScheme == nil)
        #expect(AppTheme.light.colorScheme == .light)
        #expect(AppTheme.dark.colorScheme == .dark)
    }

    @Test("Start recording destination defaults to GPS walk and maps to the expected tab")
    func startRecordingDestinationPresentation() {
        #expect(StartRecordingDestination.walk.title == "GPS Walk")
        #expect(StartRecordingDestination.walk.tab == .walk)
        #expect(StartRecordingDestination.videoWalk.title == "Video Walk")
        #expect(StartRecordingDestination.videoWalk.tab == .videoWalk)
        #expect(StartRecordingDestination(rawValue: StartRecordingDestination.walk.rawValue) == .walk)
    }

    @Test("About info exposes app metadata and support contact")
    func aboutInfo() {
        let info = AboutInfo.current

        #expect(info.appName.isEmpty == false)
        #expect(info.version.isEmpty == false)
        #expect(info.build.isEmpty == false)
        #expect(info.contactEmail == "heathdj@me.com")
    }
}

@MainActor
struct WalkRecordingSessionTests {
    @Test("The first accurate location starts the route")
    func acceptsFirstAccurateLocation() {
        let now = Date(timeIntervalSince1970: 1_000)
        let session = WalkRecordingSession(startedAt: now)
        let location = makeLocation(latitude: 33, longitude: -112, accuracy: 5, timestamp: now)

        #expect(session.accept(location, now: now))
        #expect(session.recording.points.count == 1)
        #expect(session.recording.distanceMeters == 0)
    }

    @Test("Inaccurate and stale locations are rejected")
    func rejectsLowQualityLocations() {
        let now = Date(timeIntervalSince1970: 1_000)
        let session = WalkRecordingSession(startedAt: now)
        let inaccurate = makeLocation(latitude: 33, longitude: -112, accuracy: 75, timestamp: now)
        let stale = makeLocation(
            latitude: 33,
            longitude: -112,
            accuracy: 5,
            timestamp: now.addingTimeInterval(-30)
        )

        #expect(session.accept(inaccurate, now: now) == false)
        #expect(session.accept(stale, now: now) == false)
        #expect(session.recording.points.isEmpty)
    }

    @Test("Noise below the movement threshold is rejected")
    func rejectsNoise() {
        let now = Date(timeIntervalSince1970: 1_000)
        let session = WalkRecordingSession(startedAt: now)
        let first = makeLocation(latitude: 33, longitude: -112, accuracy: 5, timestamp: now)
        let nearby = makeLocation(
            latitude: 33.000001,
            longitude: -112,
            accuracy: 5,
            timestamp: now.addingTimeInterval(2)
        )

        #expect(session.accept(first, now: now))
        #expect(session.accept(nearby, now: now.addingTimeInterval(2)) == false)
        #expect(session.recording.points.count == 1)
    }

    @Test("Accepted movement increases the route distance")
    func accumulatesDistance() {
        let now = Date(timeIntervalSince1970: 1_000)
        let session = WalkRecordingSession(startedAt: now)
        let first = makeLocation(latitude: 33, longitude: -112, accuracy: 5, timestamp: now)
        let second = makeLocation(
            latitude: 33.001,
            longitude: -112,
            accuracy: 5,
            timestamp: now.addingTimeInterval(10)
        )

        #expect(session.accept(first, now: now))
        #expect(session.accept(second, now: now.addingTimeInterval(10)))
        #expect(session.recording.points.count == 2)
        #expect(session.recording.distanceMeters > 100)
    }

    @Test("Duration is measured from the session start")
    func updatesDuration() {
        let start = Date(timeIntervalSince1970: 1_000)
        let session = WalkRecordingSession(startedAt: start)

        session.updateDuration(at: start.addingTimeInterval(125))

        #expect(session.recording.duration == 125)
        #expect(session.recording.durationText == "2:05")
    }

    @Test("A video walk session creates video walk metadata")
    func createsVideoWalkSession() {
        let start = Date(timeIntervalSince1970: 1_000)
        let session = WalkRecordingSession(startedAt: start, mode: .videoWalk)

        #expect(session.recording.mode == .videoWalk)
        #expect(session.recording.title.hasPrefix("Video Walk"))
        #expect(session.recording.hasVideo == false)
    }

    private func makeLocation(
        latitude: CLLocationDegrees,
        longitude: CLLocationDegrees,
        accuracy: CLLocationAccuracy,
        timestamp: Date
    ) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: 300,
            horizontalAccuracy: accuracy,
            verticalAccuracy: 5,
            course: -1,
            speed: 1.2,
            timestamp: timestamp
        )
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

    @Test("Short recordings use a 10 second save confirmation threshold")
    func shortRecordingThreshold() {
        let shortWalk = WalkRecording(title: "Short Walk", duration: 9.9, mode: .walk)
        let tenSecondWalk = WalkRecording(title: "Ten Second Walk", duration: 10, mode: .walk)

        #expect(WalkRecording.shortRecordingThreshold == 10)
        #expect(shortWalk.isShortRecording)
        #expect(tenSecondWalk.isShortRecording == false)
    }

    @Test("Video playback route progress follows recorded point timing")
    func videoPlaybackRouteProgress() throws {
        let recording = WalkRecording(
            title: "Video Walk",
            mode: .videoWalk,
            points: [
                makePoint(timestamp: 220, latitude: 33.4500, longitude: -112.0710),
                makePoint(timestamp: 100, latitude: 33.4484, longitude: -112.0740),
                makePoint(timestamp: 160, latitude: 33.4490, longitude: -112.0728)
            ]
        )

        #expect(try #require(recording.playbackPoint(at: 0)).latitude == 33.4484)
        #expect(try #require(recording.playbackPoint(at: 65)).latitude == 33.4490)
        #expect(try #require(recording.playbackPoint(at: 500)).latitude == 33.4500)
    }

    @Test("Duration presentation handles minutes and hours")
    func durationPresentation() {
        let shortWalk = WalkRecording(title: "Short", duration: 125, mode: .walk)
        let longWalk = WalkRecording(title: "Long", duration: 3_725, mode: .walk)

        #expect(shortWalk.durationText == "2:05")
        #expect(longWalk.durationText == "1:02:05")
    }

    @Test("Location points expose their map coordinate")
    func locationCoordinate() {
        let point = makePoint(timestamp: 100)

        #expect(point.coordinate.latitude == point.latitude)
        #expect(point.coordinate.longitude == point.longitude)
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

    @Test("Google Maps export includes the route endpoints and walking mode")
    func googleMapsExport() throws {
        let recording = WalkRecording(
            title: "Export Walk",
            mode: .walk,
            points: [
                makePoint(timestamp: 100, latitude: 33.4484, longitude: -112.0740),
                makePoint(timestamp: 200, latitude: 33.4490, longitude: -112.0728),
                makePoint(timestamp: 300, latitude: 33.4500, longitude: -112.0710)
            ]
        )

        let url = try #require(WalkRouteExport(recording: recording).googleMapsURL)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })

        #expect(query["origin"] == "33.448400,-112.074000")
        #expect(query["destination"] == "33.450000,-112.071000")
        #expect(query["travelmode"] == "walking")
        #expect(query["waypoints"] == "33.449000,-112.072800")
    }

    @Test("GPX export preserves every point in time order and escapes its title")
    func gpxExport() throws {
        let recording = WalkRecording(
            title: "Creek & Canal",
            createdAt: Date(timeIntervalSince1970: 300),
            mode: .walk,
            points: [
                makePoint(timestamp: 200, latitude: 33.4490, longitude: -112.0728),
                makePoint(timestamp: 100, latitude: 33.4484, longitude: -112.0740)
            ]
        )

        let export = WalkRouteExport(recording: recording)
        let firstPoint = try #require(export.gpxText.range(of: "lat=\"33.448400\""))
        let secondPoint = try #require(export.gpxText.range(of: "lat=\"33.449000\""))

        #expect(export.gpxText.contains("<name>Creek &amp; Canal</name>"))
        #expect(export.gpxText.components(separatedBy: "<trkpt ").count - 1 == 2)
        #expect(firstPoint.lowerBound < secondPoint.lowerBound)
        #expect(export.gpxFile.filename == "Creek-Canal.gpx")
    }

    @Test("GPX export includes ASMR Walk extensions for importer sync and diagnostics")
    func gpxExportExtensions() throws {
        let recordingID = try #require(UUID(uuidString: "3B278DC8-F7C6-4A01-8B55-C627DD6F00E1"))
        let recording = WalkRecording(
            id: recordingID,
            title: "Video Export",
            createdAt: Date(timeIntervalSince1970: 300),
            duration: 142.75,
            mode: .videoWalk,
            videoURL: URL(filePath: "/private/var/mobile/Containers/Data/Application/video.mov"),
            points: [
                makePoint(timestamp: 100, horizontalAccuracy: 4.25, speed: 1.5),
                makePoint(timestamp: 120, latitude: 33.4490, longitude: -112.0728, horizontalAccuracy: 8)
            ]
        )

        let gpxText = WalkRouteExport(recording: recording).gpxText

        #expect(gpxText.contains("xmlns:asmrwalk=\"https://asmrwalk.app/gpx/1\""))
        #expect(gpxText.contains("<asmrwalk:recordingID>\(recordingID.uuidString)</asmrwalk:recordingID>"))
        #expect(gpxText.contains("<asmrwalk:durationSeconds>142.75</asmrwalk:durationSeconds>"))
        #expect(gpxText.contains("<asmrwalk:recordingMode>videoWalk</asmrwalk:recordingMode>"))
        #expect(gpxText.contains("<asmrwalk:hasVideo>true</asmrwalk:hasVideo>"))
        #expect(gpxText.contains("<asmrwalk:horizontalAccuracyMeters>4.25</asmrwalk:horizontalAccuracyMeters>"))
        #expect(gpxText.contains("<asmrwalk:horizontalAccuracyMeters>8</asmrwalk:horizontalAccuracyMeters>"))
        #expect(gpxText.contains("<asmrwalk:speedMetersPerSecond>1.5</asmrwalk:speedMetersPerSecond>"))
        #expect(gpxText.components(separatedBy: "<asmrwalk:speedMetersPerSecond>").count - 1 == 1)
        #expect(gpxText.contains("video.mov") == false)
        #expect(gpxText.contains("/private/var/mobile") == false)
    }

    @Test("GPX export uses POSIX-safe number formatting for elevation")
    func gpxExportElevationFormatting() {
        let recording = WalkRecording(
            title: "Elevation Export",
            mode: .walk,
            points: [
                makePoint(timestamp: 100, altitude: 331.25)
            ]
        )

        #expect(WalkRouteExport(recording: recording).gpxText.contains("<ele>331.25</ele>"))
    }

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: WalkRecording.self,
            LocationPoint.self,
            configurations: configuration
        )
    }

    private func makePoint(
        timestamp: TimeInterval,
        latitude: Double = 33.4484,
        longitude: Double = -112.0740,
        altitude: Double? = nil,
        horizontalAccuracy: Double = 5,
        speed: Double? = nil
    ) -> LocationPoint {
        LocationPoint(
            timestamp: Date(timeIntervalSince1970: timestamp),
            latitude: latitude,
            longitude: longitude,
            altitude: altitude,
            horizontalAccuracy: horizontalAccuracy,
            speed: speed
        )
    }
}
