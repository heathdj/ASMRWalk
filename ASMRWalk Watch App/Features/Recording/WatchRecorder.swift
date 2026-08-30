//
//  WatchRecorder.swift
//  ASMRWalk Watch App
//

import CoreLocation
import Foundation
import Observation
import SwiftData

struct WatchLocationUpdateSnapshot {
    let authorizationDenied: Bool
    let location: CLLocation?
}

@MainActor
protocol WatchLocationClient: AnyObject {
    var authorizationStatus: CLAuthorizationStatus { get }

    func requestWhenInUseAuthorization()
    func liveUpdates() -> AsyncThrowingStream<WatchLocationUpdateSnapshot, Error>
}

@MainActor
final class CoreWatchLocationClient: WatchLocationClient {
    private let locationManager: CLLocationManager

    init(locationManager: CLLocationManager = CLLocationManager()) {
        self.locationManager = locationManager
    }

    var authorizationStatus: CLAuthorizationStatus {
        locationManager.authorizationStatus
    }

    func requestWhenInUseAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    func liveUpdates() -> AsyncThrowingStream<WatchLocationUpdateSnapshot, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await update in CLLocationUpdate.liveUpdates(.fitness) {
                        continuation.yield(WatchLocationUpdateSnapshot(
                            authorizationDenied: update.authorizationDenied,
                            location: update.location
                        ))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

@MainActor
@Observable
final class WatchRecorder {
    enum Phase: Equatable {
        case ready
        case recording
        case saving
    }

    private(set) var phase: Phase = .ready
    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var errorMessage: String?
    private(set) var latestAccuracyMeters: CLLocationAccuracy?
    private(set) var currentDuration: TimeInterval = 0
    private(set) var currentDistanceMeters: Double = 0
    private(set) var pointCount = 0
    private(set) var lastCompletedAt: Date?

    private let locationClient: any WatchLocationClient
    private let requiresLocationUsageDescription: Bool
    private var session: WatchRecordingSession?
    private var persistence: WatchRecordingPersistence?
    private var updateTask: Task<Void, Never>?
    private var clockTask: Task<Void, Never>?
    private var acceptedPointsSinceSave = 0
    private var secondsSinceSave = 0

    init(
        locationClient: (any WatchLocationClient)? = nil,
        requiresLocationUsageDescription: Bool = true
    ) {
        let locationClient = locationClient ?? CoreWatchLocationClient()
        self.locationClient = locationClient
        self.requiresLocationUsageDescription = requiresLocationUsageDescription
        authorizationStatus = locationClient.authorizationStatus
    }

    var isRecording: Bool {
        phase == .recording
    }

    var canStartRecording: Bool {
        phase == .ready
    }

    var statusTitle: String {
        switch phase {
        case .ready:
            if isLocationAccessDenied {
                "Location Needed"
            } else if lastCompletedAt != nil {
                "Saved"
            } else {
                "Ready"
            }
        case .recording:
            "Recording"
        case .saving:
            "Saving"
        }
    }

    var statusDetail: String {
        if let errorMessage {
            return errorMessage
        }

        switch authorizationStatus {
        case .notDetermined:
            return "Location permission is requested when you start."
        case .denied, .restricted:
            return "Enable location access in Settings to record Watch walks."
        default:
            if let lastCompletedAt, phase == .ready {
                return "Saved \(lastCompletedAt.formatted(date: .omitted, time: .shortened)). Waiting for iCloud sync."
            }
            if let latestAccuracyMeters {
                return "GPS accuracy: \(Int(latestAccuracyMeters.rounded())) m"
            }
            return "Your Watch route syncs with ASMR Walk."
        }
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = locationClient.authorizationStatus
    }

    func start(in modelContext: ModelContext, requestAuthorization: Bool = true) async {
        guard phase == .ready else {
            return
        }

        errorMessage = nil
        lastCompletedAt = nil
        authorizationStatus = locationClient.authorizationStatus

        guard requiresLocationUsageDescription == false || WatchLocationUsageConfiguration.hasWhenInUseUsageDescription else {
            errorMessage = "Watch location usage description is missing."
            return
        }

        guard isLocationAccessDenied == false else {
            errorMessage = "Location access is unavailable."
            return
        }

        guard authorizationStatus != .notDetermined else {
            if requestAuthorization {
                locationClient.requestWhenInUseAuthorization()
            }
            errorMessage = "Allow location access, then start again."
            return
        }

        let session = WatchRecordingSession()
        let persistence = WatchRecordingPersistence(modelContainer: modelContext.container)
        self.session = session
        self.persistence = persistence
        syncLiveSnapshot()

        do {
            try await persistence.save(session.snapshot)
        } catch {
            reset()
            errorMessage = "Unable to start recording: \(error.localizedDescription)"
            return
        }

        phase = .recording
        startLocationUpdates()
        startClock()
    }

    func stopAndSave() async {
        guard phase == .recording else {
            return
        }

        phase = .saving
        updateTask?.cancel()
        clockTask?.cancel()
        session?.updateDuration()
        syncLiveSnapshot()

        do {
            if let persistence, let snapshot = session?.snapshot {
                try await persistence.save(snapshot)
            }
            reset()
            lastCompletedAt = .now
        } catch {
            phase = .recording
            errorMessage = "Unable to save walk: \(error.localizedDescription)"
            startLocationUpdates()
            startClock()
        }
    }

    func discard() async {
        updateTask?.cancel()
        clockTask?.cancel()

        if let recordingID = session?.snapshot.id {
            try? await persistence?.deleteRecording(id: recordingID)
        }

        lastCompletedAt = nil
        reset()
    }

    func accept(_ location: CLLocation, now: Date = .now) async {
        latestAccuracyMeters = location.horizontalAccuracy
        guard let session, session.accept(location, now: now) else {
            return
        }

        acceptedPointsSinceSave += 1
        syncLiveSnapshot()
        await checkpointIfNeeded()
    }

    private var isLocationAccessDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    private func startLocationUpdates() {
        updateTask?.cancel()
        updateTask = Task {
            do {
                for try await update in locationClient.liveUpdates() {
                    guard Task.isCancelled == false, isRecording else {
                        break
                    }

                    if update.authorizationDenied {
                        authorizationStatus = .denied
                        errorMessage = "Location access was denied. The walk was saved."
                        await stopAndSave()
                        break
                    }

                    if let location = update.location {
                        authorizationStatus = locationClient.authorizationStatus
                        await accept(location)
                    }
                }
            } catch is CancellationError {
                // Cancellation is expected when a recording stops.
            } catch {
                errorMessage = "GPS updates stopped: \(error.localizedDescription)"
                await stopAndSave()
            }
        }
    }

    private func startClock() {
        clockTask?.cancel()
        clockTask = Task {
            while Task.isCancelled == false, isRecording {
                try? await Task.sleep(for: .seconds(1))
                guard Task.isCancelled == false, isRecording else {
                    break
                }

                session?.updateDuration()
                secondsSinceSave += 1
                syncLiveSnapshot()
                await checkpointIfNeeded()
            }
        }
    }

    private func checkpointIfNeeded() async {
        guard acceptedPointsSinceSave >= 10 || secondsSinceSave >= 30 else {
            return
        }
        guard let persistence, let snapshot = session?.snapshot else {
            return
        }

        do {
            try await persistence.save(snapshot)
            acceptedPointsSinceSave = 0
            secondsSinceSave = 0
        } catch {
            errorMessage = "Unable to save checkpoint: \(error.localizedDescription)"
        }
    }

    private func syncLiveSnapshot() {
        guard let snapshot = session?.snapshot else {
            currentDuration = 0
            currentDistanceMeters = 0
            pointCount = 0
            return
        }

        currentDuration = snapshot.duration
        currentDistanceMeters = snapshot.distanceMeters
        pointCount = snapshot.points.count
    }

    private func reset() {
        updateTask?.cancel()
        updateTask = nil
        clockTask?.cancel()
        clockTask = nil
        errorMessage = nil
        session = nil
        persistence = nil
        phase = .ready
        latestAccuracyMeters = nil
        acceptedPointsSinceSave = 0
        secondsSinceSave = 0
        syncLiveSnapshot()
        refreshAuthorizationStatus()
    }
}

enum WatchLocationUsageConfiguration {
    static var hasWhenInUseUsageDescription: Bool {
        Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") is String
    }
}
