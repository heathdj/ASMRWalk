//
//  ASMRWalk_Watch_AppTests.swift
//  ASMRWalk Watch AppTests
//

import CoreLocation
import SwiftData
import Testing
@testable import ASMRWalk_Watch_App

@MainActor
struct ASMRWalk_Watch_AppTests {
    @Test("Watch recording sessions use Apple Watch metadata")
    func watchRecordingSessionMetadata() {
        let start = Date(timeIntervalSince1970: 1_000)
        let session = WatchRecordingSession(startedAt: start)

        #expect(session.snapshot.mode == .walk)
        #expect(session.snapshot.recordingSource == .appleWatch)
        #expect(session.snapshot.captureDeviceName == "Apple Watch")
        #expect(session.snapshot.routeStartedAt == start)
        #expect(session.snapshot.routeEndedAt == nil)
    }

    @Test("Watch recording session filters GPS points like iPhone walks")
    func watchRecordingSessionFiltersLocationQuality() {
        let now = Date(timeIntervalSince1970: 1_000)
        let session = WatchRecordingSession(startedAt: now)
        let accepted = makeLocation(latitude: 33, longitude: -112, accuracy: 5, timestamp: now)
        let inaccurate = makeLocation(latitude: 33.001, longitude: -112, accuracy: 75, timestamp: now)
        let stale = makeLocation(latitude: 33.002, longitude: -112, accuracy: 5, timestamp: now.addingTimeInterval(-30))

        #expect(session.accept(accepted, now: now))
        #expect(session.accept(inaccurate, now: now) == false)
        #expect(session.accept(stale, now: now) == false)
        #expect(session.snapshot.points.count == 1)
    }

    @Test("Watch recording session measures accepted movement")
    func watchRecordingSessionMeasuresDistance() {
        let now = Date(timeIntervalSince1970: 1_000)
        let session = WatchRecordingSession(startedAt: now)
        let first = makeLocation(latitude: 33, longitude: -112, accuracy: 5, timestamp: now)
        let noise = makeLocation(latitude: 33.000001, longitude: -112, accuracy: 5, timestamp: now.addingTimeInterval(2))
        let second = makeLocation(latitude: 33.001, longitude: -112, accuracy: 5, timestamp: now.addingTimeInterval(10))

        #expect(session.accept(first, now: now))
        #expect(session.accept(noise, now: now.addingTimeInterval(2)) == false)
        #expect(session.accept(second, now: now.addingTimeInterval(10)))
        #expect(session.snapshot.points.count == 2)
        #expect(session.snapshot.distanceMeters > 100)
    }

    @Test("Watch recorder waits for explicit authorization")
    func watchRecorderRequestsAuthorizationBeforeStarting() async throws {
        let container = try makeTestContainer()
        let locationClient = FakeWatchLocationClient(authorizationStatus: .notDetermined)
        let recorder = WatchRecorder(locationClient: locationClient, requiresLocationUsageDescription: false)

        await recorder.start(in: container.mainContext, requestAuthorization: true)

        #expect(locationClient.requestWhenInUseAuthorizationCount == 1)
        #expect(recorder.isRecording == false)
        #expect(recorder.errorMessage == "Allow location access, then start again.")
        #expect(try fetchRecordingCount(in: container) == 0)
    }

    @Test("Watch recorder surfaces denied location access")
    func watchRecorderSurfacesDeniedAuthorization() async throws {
        let container = try makeTestContainer()
        let locationClient = FakeWatchLocationClient(authorizationStatus: .denied)
        let recorder = WatchRecorder(locationClient: locationClient, requiresLocationUsageDescription: false)

        await recorder.start(in: container.mainContext)

        #expect(locationClient.requestWhenInUseAuthorizationCount == 0)
        #expect(recorder.isRecording == false)
        #expect(recorder.errorMessage == "Location access is unavailable.")
        #expect(try fetchRecordingCount(in: container) == 0)
    }

    @Test("Watch recorder persists completed routes")
    func watchRecorderPersistsCompletedRoutes() async throws {
        let container = try makeTestContainer()
        let locationClient = FakeWatchLocationClient(authorizationStatus: .authorizedWhenInUse)
        let recorder = WatchRecorder(locationClient: locationClient, requiresLocationUsageDescription: false)
        let start = Date(timeIntervalSince1970: 1_000)
        let first = makeLocation(latitude: 33, longitude: -112, accuracy: 5, timestamp: start)
        let second = makeLocation(latitude: 33.001, longitude: -112, accuracy: 5, timestamp: start.addingTimeInterval(10))

        await recorder.start(in: container.mainContext)
        await recorder.accept(first, now: start)
        await recorder.accept(second, now: start.addingTimeInterval(10))
        await recorder.stopAndSave()

        let recording = try #require(try fetchOnlyRecording(in: container))
        #expect(recording.recordingSource == WalkRecordingSource.appleWatch.rawValue)
        #expect(recording.captureDeviceName == "Apple Watch")
        #expect(recording.points.count == 2)
        #expect(recording.distanceMeters > 100)
        #expect(recording.routeEndedAt != nil)
        #expect(recorder.isRecording == false)
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

private func makeTestContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: WalkRecording.self,
        LocationPoint.self,
        configurations: configuration
    )
}

private func fetchRecordingCount(in container: ModelContainer) throws -> Int {
    let context = ModelContext(container)
    return try context.fetchCount(FetchDescriptor<WalkRecording>())
}

private func fetchOnlyRecording(in container: ModelContainer) throws -> WalkRecording? {
    let context = ModelContext(container)
    return try context.fetch(FetchDescriptor<WalkRecording>()).first
}

@MainActor
private final class FakeWatchLocationClient: WatchLocationClient {
    var authorizationStatus: CLAuthorizationStatus
    private(set) var requestWhenInUseAuthorizationCount = 0

    init(authorizationStatus: CLAuthorizationStatus) {
        self.authorizationStatus = authorizationStatus
    }

    func requestWhenInUseAuthorization() {
        requestWhenInUseAuthorizationCount += 1
    }

    func liveUpdates() -> AsyncThrowingStream<WatchLocationUpdateSnapshot, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}
