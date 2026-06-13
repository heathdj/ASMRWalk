//
//  WalkRecorder.swift
//  ASMR Walk
//

import CoreLocation
import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class WalkRecorder {
    enum Phase: Equatable {
        case ready
        case recording
        case saving
    }

    private(set) var phase: Phase = .ready
    private(set) var session: WalkRecordingSession?
    private(set) var latestLocation: CLLocation?
    private(set) var errorMessage: String?
    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var isPreviewingLocation = false

    private let locationManager: CLLocationManager
    private var updateTask: Task<Void, Never>?
    private var clockTask: Task<Void, Never>?
    private var modelContext: ModelContext?
    private var acceptedPointsSinceSave = 0
    private var secondsSinceSave = 0

    init(locationManager: CLLocationManager = CLLocationManager()) {
        self.locationManager = locationManager
        authorizationStatus = locationManager.authorizationStatus
    }

    var isRecording: Bool {
        phase == .recording
    }

    var recording: WalkRecording? {
        session?.recording
    }

    func startPreviewingLocation() {
        guard isPreviewingLocation == false else {
            return
        }

        errorMessage = nil
        authorizationStatus = locationManager.authorizationStatus

        guard authorizationStatus != .denied, authorizationStatus != .restricted else {
            errorMessage = "Location access is unavailable."
            return
        }

        if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }

        isPreviewingLocation = true
        startLocationUpdates()
    }

    func stopPreviewingLocation() {
        isPreviewingLocation = false

        guard isRecording == false else {
            return
        }

        updateTask?.cancel()
        updateTask = nil
    }

    var coordinates: [CLLocationCoordinate2D] {
        recording?.pointsInTimeOrder.map(\.coordinate) ?? []
    }

    var statusTitle: String {
        switch authorizationStatus {
        case .denied, .restricted:
            "Location access needed"
        default:
            isRecording ? "Recording walk" : "Ready to walk"
        }
    }

    var statusDetail: String {
        if let errorMessage {
            return errorMessage
        }

        switch authorizationStatus {
        case .denied, .restricted:
            return "Enable location access in Settings to record a route."
        case .notDetermined:
            return "Location permission will be requested when recording starts."
        default:
            if isRecording, let latestLocation {
                return "GPS accuracy: \(Int(latestLocation.horizontalAccuracy.rounded())) m"
            }
            return "Your route will stay on this device."
        }
    }

    func start(in modelContext: ModelContext) {
        guard phase == .ready else {
            return
        }

        errorMessage = nil
        authorizationStatus = locationManager.authorizationStatus

        guard authorizationStatus != .denied, authorizationStatus != .restricted else {
            errorMessage = "Location access is unavailable."
            return
        }

        if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }

        let session = WalkRecordingSession()
        self.session = session
        self.modelContext = modelContext
        modelContext.insert(session.recording)

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            self.session = nil
            self.modelContext = nil
            errorMessage = "Unable to start recording: \(error.localizedDescription)"
            return
        }

        phase = .recording
        startLocationUpdates()
        startClock()
    }

    func stopAndSave() {
        guard phase == .recording else {
            return
        }

        phase = .saving
        if isPreviewingLocation == false {
            updateTask?.cancel()
        }
        clockTask?.cancel()
        session?.updateDuration()

        do {
            try modelContext?.save()
            reset()
        } catch {
            phase = .recording
            errorMessage = "Unable to save walk: \(error.localizedDescription)"
            startLocationUpdates()
            startClock()
        }
    }

    func discard() {
        if isPreviewingLocation == false {
            updateTask?.cancel()
        }
        clockTask?.cancel()

        if let recording {
            modelContext?.delete(recording)
            try? modelContext?.save()
        }

        reset()
    }

    func accept(_ location: CLLocation, now: Date = .now) {
        latestLocation = location
        guard let session, session.accept(location, now: now) else {
            return
        }

        acceptedPointsSinceSave += 1
        checkpointIfNeeded()
    }

    private func startLocationUpdates() {
        updateTask?.cancel()
        updateTask = Task {
            do {
                for try await update in CLLocationUpdate.liveUpdates(.fitness) {
                    guard Task.isCancelled == false, isRecording || isPreviewingLocation else {
                        break
                    }

                    if update.authorizationDenied {
                        authorizationStatus = .denied
                        if isRecording {
                            errorMessage = "Location access was denied. The walk was saved."
                            stopAndSave()
                        } else {
                            errorMessage = "Location access is unavailable."
                        }
                        break
                    }

                    if let location = update.location {
                        authorizationStatus = locationManager.authorizationStatus
                        accept(location)
                    }
                }
            } catch is CancellationError {
                // Cancellation is expected when a recording stops.
            } catch {
                errorMessage = "GPS updates stopped: \(error.localizedDescription)"
                if isRecording {
                    stopAndSave()
                }
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
                checkpointIfNeeded()
            }
        }
    }

    private func checkpointIfNeeded() {
        guard acceptedPointsSinceSave >= 10 || secondsSinceSave >= 30 else {
            return
        }

        do {
            try modelContext?.save()
            acceptedPointsSinceSave = 0
            secondsSinceSave = 0
        } catch {
            errorMessage = "Recording continues, but the latest checkpoint could not be saved."
        }
    }

    private func reset() {
        if isPreviewingLocation == false {
            updateTask = nil
            latestLocation = nil
        }
        clockTask = nil
        session = nil
        modelContext = nil
        acceptedPointsSinceSave = 0
        secondsSinceSave = 0
        phase = .ready
    }
}
