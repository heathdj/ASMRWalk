//
//  WalkRecordingSessionTests.swift
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
struct WalkRecordingSessionTests {
    @Test("The first accurate location starts the route")
    func acceptsFirstAccurateLocation() {
        let now = Date(timeIntervalSince1970: 1_000)
        let session = WalkRecordingSession(startedAt: now)
        let location = makeLocation(latitude: 33, longitude: -112, accuracy: 5, timestamp: now)

        #expect(session.accept(location, now: now))
        #expect(session.snapshot.points.count == 1)
        #expect(session.snapshot.distanceMeters == 0)
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
        #expect(session.snapshot.points.isEmpty)
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
        #expect(session.snapshot.points.count == 1)
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
        #expect(session.snapshot.points.count == 2)
        #expect(session.snapshot.distanceMeters > 100)
    }

    @Test("Duration is measured from the session start")
    func updatesDuration() {
        let start = Date(timeIntervalSince1970: 1_000)
        let session = WalkRecordingSession(startedAt: start)

        session.updateDuration(at: start.addingTimeInterval(125))

        #expect(session.snapshot.duration == 125)
        #expect(session.snapshot.duration.timerText == "2:05")
    }

    @Test("A video walk session creates video walk metadata")
    func createsVideoWalkSession() {
        let start = Date(timeIntervalSince1970: 1_000)
        let session = WalkRecordingSession(startedAt: start, mode: .videoWalk)

        #expect(session.snapshot.mode == .videoWalk)
        #expect(session.snapshot.title.hasPrefix("Video Walk"))
        #expect(session.snapshot.hasVideo == false)
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
