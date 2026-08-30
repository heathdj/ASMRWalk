//
//  TestSupport.swift
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

func makeContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: WalkRecording.self,
        LocationPoint.self,
        configurations: configuration
    )
}

func makePoint(
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

func makeSnapshot(
    id: UUID,
    title: String = "Checkpoint Walk",
    createdAt: Date = Date(timeIntervalSince1970: 1_000),
    duration: TimeInterval,
    distanceMeters: Double,
    pointCount: Int,
    latitude: Double = 33.4484,
    longitude: Double = -112.0740,
    recordingSource: WalkRecordingSource = .iPhone,
    captureDeviceName: String? = nil,
    routeStartedAt: Date? = nil,
    routeEndedAt: Date? = nil,
    externalVideoReference: String? = nil,
    externalVideoStartedAt: Date? = nil
) -> WalkRecordingSnapshot {
    WalkRecordingSnapshot(
        id: id,
        title: title,
        createdAt: createdAt,
        duration: duration,
        distanceMeters: distanceMeters,
        mode: .walk,
        recordingSource: recordingSource,
        captureDeviceName: captureDeviceName,
        routeStartedAt: routeStartedAt ?? createdAt,
        routeEndedAt: routeEndedAt ?? createdAt.addingTimeInterval(duration),
        externalVideoReference: externalVideoReference,
        externalVideoStartedAt: externalVideoStartedAt,
        points: (0..<pointCount).map { index in
            LocationPointSnapshot(
                timestamp: createdAt.addingTimeInterval(TimeInterval(index)),
                latitude: latitude + (Double(index) * 0.0001),
                longitude: longitude + (Double(index) * 0.0001),
                altitude: nil,
                horizontalAccuracy: 5,
                speed: 1.2
            )
        }
    )
}

func fetchRecording(id: UUID, in container: ModelContainer) throws -> WalkRecording? {
    let context = ModelContext(container)
    let descriptor = FetchDescriptor<WalkRecording>(
        predicate: #Predicate { recording in
            recording.id == id
        }
    )
    return try context.fetch(descriptor).first
}

func makeTestContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: WalkRecording.self,
        LocationPoint.self,
        configurations: configuration
    )
}

func fetchOnlyRecording(in container: ModelContainer) throws -> WalkRecording? {
    let context = ModelContext(container)
    let recordings = try context.fetch(FetchDescriptor<WalkRecording>())
    return recordings.first
}

nonisolated struct TestError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}

nonisolated struct FakeWalkPlaceGeocoder: WalkPlaceGeocoding {
    let metadata: WalkPlaceMetadata

    func place(for coordinate: WalkRouteMetadataCoordinate) async throws -> WalkPlaceMetadata {
        metadata
    }
}

nonisolated struct FailingWalkPlaceGeocoder: WalkPlaceGeocoding {
    func place(for coordinate: WalkRouteMetadataCoordinate) async throws -> WalkPlaceMetadata {
        throw TestError(message: "Place lookup failed")
    }
}

@MainActor
final class FakeBackgroundActivity: WalkBackgroundActivity {
    private(set) var didInvalidate = false

    func invalidate() {
        didInvalidate = true
    }
}

@MainActor
final class FakeWalkLocationClient: WalkLocationClient {
    var authorizationStatus: CLAuthorizationStatus
    var allowsBackgroundLocationUpdates = false
    var pausesLocationUpdatesAutomatically = true
    var headingUpdatesAvailable = true
    private(set) var requestWhenInUseAuthorizationCount = 0
    private(set) var requestAlwaysAuthorizationCount = 0
    private(set) var didStartHeadingUpdates = false
    private(set) var didStopHeadingUpdates = false
    private(set) var backgroundActivityCount = 0
    private(set) var backgroundActivities: [FakeBackgroundActivity] = []
    private weak var delegate: CLLocationManagerDelegate?

    init(authorizationStatus: CLAuthorizationStatus) {
        self.authorizationStatus = authorizationStatus
    }

    func setDelegate(_ delegate: CLLocationManagerDelegate?) {
        self.delegate = delegate
    }

    func requestWhenInUseAuthorization() {
        requestWhenInUseAuthorizationCount += 1
    }

    func requestAlwaysAuthorization() {
        requestAlwaysAuthorizationCount += 1
    }

    func startUpdatingHeading() {
        didStartHeadingUpdates = true
    }

    func stopUpdatingHeading() {
        didStopHeadingUpdates = true
    }

    func liveUpdates() -> AsyncThrowingStream<WalkLocationUpdateSnapshot, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func makeBackgroundActivity() -> any WalkBackgroundActivity {
        backgroundActivityCount += 1
        let activity = FakeBackgroundActivity()
        backgroundActivities.append(activity)
        return activity
    }
}

@MainActor
final class FakeVideoRecordingController: VideoRecordingControlling {
    let stopURL: URL?
    let stopError: (any Error)?
    private(set) var messages: [String] = []
    private(set) var errors: [String] = []
    private(set) var didStopSession = false

    init(stopResult: Result<URL, TestError>) {
        switch stopResult {
        case let .success(url):
            stopURL = url
            stopError = nil
        case let .failure(error):
            stopURL = nil
            stopError = error
        }
    }

    func stopRecording() async throws -> URL {
        if let stopURL {
            return stopURL
        }

        throw stopError ?? TestError(message: "Video stop failed")
    }

    func report(_ error: Error) {
        errors.append(error.localizedDescription)
    }

    func reportMessage(_ message: String) {
        messages.append(message)
    }

    func stopSession() {
        didStopSession = true
    }
}
