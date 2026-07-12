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
final class WalkRecorder: NSObject {
    enum Phase: Equatable {
        case ready
        case recording
        case saving
    }

    private(set) var phase: Phase = .ready
    private(set) var session: WalkRecordingSession?
    private(set) var latestLocation: CLLocation?
    private(set) var headingDegrees: CLLocationDirection?
    private(set) var errorMessage: String?
    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var isPreviewingLocation = false
    private(set) var isBackgroundRecordingEnabled = BackgroundGPSRecording.defaultValue
    private(set) var currentDuration: TimeInterval = 0
    private(set) var currentDistanceMeters: Double = 0
    private(set) var coordinates: [CLLocationCoordinate2D] = []

    private let locationManager: CLLocationManager
    private var updateTask: Task<Void, Never>?
    private var clockTask: Task<Void, Never>?
    private var backgroundActivitySession: CLBackgroundActivitySession?
    private var persistence: WalkRecordingPersistence?
    private var acceptedPointsSinceSave = 0
    private var secondsSinceSave = 0

    init(locationManager: CLLocationManager = CLLocationManager()) {
        self.locationManager = locationManager
        authorizationStatus = locationManager.authorizationStatus
        super.init()
        self.locationManager.delegate = self
    }

    var isRecording: Bool {
        phase == .recording
    }

    var isShortRecording: Bool {
        recording?.isShortRecording ?? (currentDuration < WalkRecording.shortRecordingThreshold)
    }

    var isLocationAccessDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    var canContinueInBackground: Bool {
        BackgroundRecordingPolicy.canContinueInBackground(
            isRecording: isRecording,
            isBackgroundRecordingEnabled: isBackgroundRecordingEnabled,
            authorizationStatus: authorizationStatus
        )
    }

    var recording: WalkRecordingSnapshot? {
        session?.snapshot
    }

    func setBackgroundRecordingEnabled(_ isEnabled: Bool, requestAuthorization: Bool = true) {
        let mode = recording?.mode ?? .walk
        isBackgroundRecordingEnabled = BackgroundRecordingPolicy.isEnabledForRecording(
            mode: mode,
            userEnabled: isEnabled
        )

        if isBackgroundRecordingEnabled, requestAuthorization {
            requestAlwaysAuthorizationIfPossible()
        }

        configureBackgroundLocationUpdates()
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = locationManager.authorizationStatus
    }

    func startPreviewingLocation(requestAuthorization: Bool = true) {
        guard isPreviewingLocation == false else {
            return
        }

        errorMessage = nil
        authorizationStatus = locationManager.authorizationStatus

        guard authorizationStatus != .denied, authorizationStatus != .restricted else {
            errorMessage = "Location access is unavailable."
            return
        }

        if authorizationStatus == .notDetermined, requestAuthorization {
            locationManager.requestWhenInUseAuthorization()
        }

        guard authorizationStatus != .notDetermined else {
            return
        }

        isPreviewingLocation = true
        startLocationUpdates()
        startHeadingUpdatesIfAvailable()
    }

    func stopPreviewingLocation() {
        isPreviewingLocation = false

        guard isRecording == false else {
            return
        }

        updateTask?.cancel()
        updateTask = nil
        stopHeadingUpdatesIfIdle()
    }

    var statusTitle: String {
        if isLocationAccessDenied {
            "Location access needed"
        } else {
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
                if isBackgroundRecordingEnabled, authorizationStatus != .authorizedAlways {
                    return "GPS accuracy: \(Int(latestLocation.horizontalAccuracy.rounded())) m. Always location is needed for background recording."
                }
                if canContinueInBackground {
                    return "GPS accuracy: \(Int(latestLocation.horizontalAccuracy.rounded())) m. Background recording is enabled."
                }
                return "GPS accuracy: \(Int(latestLocation.horizontalAccuracy.rounded())) m"
            }
            if isBackgroundRecordingEnabled, authorizationStatus != .authorizedAlways {
                return "Always location permission is required for background recording."
            }
            return "Your route will stay on this device."
        }
    }

    func start(
        in modelContext: ModelContext,
        mode: RecordingMode = .walk,
        allowsBackgroundRecording: Bool = false
    ) async {
        guard phase == .ready else {
            return
        }

        errorMessage = nil
        isBackgroundRecordingEnabled = BackgroundRecordingPolicy.isEnabledForRecording(
            mode: mode,
            userEnabled: allowsBackgroundRecording
        )
        authorizationStatus = locationManager.authorizationStatus

        guard authorizationStatus != .denied, authorizationStatus != .restricted else {
            errorMessage = "Location access is unavailable."
            return
        }

        if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        if isBackgroundRecordingEnabled {
            requestAlwaysAuthorizationIfPossible()
        }

        let session = WalkRecordingSession(mode: mode)
        let persistence = WalkRecordingPersistence(modelContainer: modelContext.container)
        self.session = session
        self.persistence = persistence
        syncLiveSnapshot()

        do {
            try await persistence.save(session.snapshot)
        } catch {
            self.session = nil
            self.persistence = nil
            errorMessage = "Unable to start recording: \(error.localizedDescription)"
            return
        }

        phase = .recording
        configureBackgroundLocationUpdates()
        startLocationUpdates()
        startHeadingUpdatesIfAvailable()
        startClock()
    }

    func attachVideo(at url: URL) {
        session?.attachVideo(at: url)
    }

    func attachPhotoLibraryVideo(assetIdentifier: String) {
        session?.attachPhotoLibraryVideo(assetIdentifier: assetIdentifier)
    }

    func stopAndSave() async {
        guard finishRecording() else {
            return
        }

        await saveFinishedRecording()
    }

    @discardableResult
    func finishRecording() -> Bool {
        guard phase == .recording else {
            return false
        }

        phase = .saving
        if isPreviewingLocation == false {
            updateTask?.cancel()
        }
        clockTask?.cancel()
        session?.updateDuration()
        syncLiveSnapshot()
        stopBackgroundActivitySession()
        configureBackgroundLocationUpdates()
        stopHeadingUpdatesIfIdle()
        return true
    }

    func saveFinishedRecording() async {
        guard phase == .saving else {
            return
        }

        guard let persistence, let snapshot = session?.snapshot else {
            reset()
            return
        }

        do {
            try await persistence.save(snapshot)
            reset()
        } catch {
            phase = .recording
            errorMessage = "Unable to save walk: \(error.localizedDescription)"
            configureBackgroundLocationUpdates()
            startLocationUpdates()
            startHeadingUpdatesIfAvailable()
            startClock()
        }
    }

    func discard() async {
        if isPreviewingLocation == false {
            updateTask?.cancel()
        }
        clockTask?.cancel()
        stopBackgroundActivitySession()
        configureBackgroundLocationUpdates()

        if let videoURL = recording?.videoURL {
            try? FileManager.default.removeItem(at: videoURL)
        }

        if let recordingID = recording?.id {
            try? await persistence?.deleteRecording(id: recordingID)
        }

        reset()
    }

    func accept(_ location: CLLocation, now: Date = .now) async {
        latestLocation = location
        guard let session, session.accept(location, now: now) else {
            return
        }

        acceptedPointsSinceSave += 1
        syncLiveSnapshot()
        await checkpointIfNeeded()
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
                        stopBackgroundActivitySession()
                        configureBackgroundLocationUpdates()
                        if isRecording {
                            errorMessage = "Location access was denied. The walk was saved."
                            await stopAndSave()
                        } else {
                            errorMessage = "Location access is unavailable."
                        }
                        break
                    }

                    if let location = update.location {
                        authorizationStatus = locationManager.authorizationStatus
                        configureBackgroundLocationUpdates()
                        await accept(location)
                    }
                }
            } catch is CancellationError {
                // Cancellation is expected when a recording stops.
            } catch {
                errorMessage = "GPS updates stopped: \(error.localizedDescription)"
                if isRecording {
                    await stopAndSave()
                }
            }
        }
    }

    private func startHeadingUpdatesIfAvailable() {
        guard CLLocationManager.headingAvailable() else {
            headingDegrees = nil
            return
        }

        locationManager.startUpdatingHeading()
    }

    private func requestAlwaysAuthorizationIfPossible() {
        authorizationStatus = locationManager.authorizationStatus
        switch authorizationStatus {
        case .authorizedWhenInUse:
            locationManager.requestAlwaysAuthorization()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        default:
            break
        }
    }

    private func configureBackgroundLocationUpdates() {
        let shouldAllowBackgroundUpdates = canContinueInBackground

        assert(
            shouldAllowBackgroundUpdates == false || recording?.mode == .walk,
            "Background location updates must only be enabled for GPS walk recordings."
        )

        locationManager.allowsBackgroundLocationUpdates = shouldAllowBackgroundUpdates
        locationManager.pausesLocationUpdatesAutomatically = shouldAllowBackgroundUpdates == false

        if shouldAllowBackgroundUpdates, backgroundActivitySession == nil {
            backgroundActivitySession = CLBackgroundActivitySession()
        } else if shouldAllowBackgroundUpdates == false {
            stopBackgroundActivitySession()
        }
    }

    private func stopBackgroundActivitySession() {
        backgroundActivitySession?.invalidate()
        backgroundActivitySession = nil
    }

    private func stopHeadingUpdatesIfIdle() {
        guard isRecording == false, isPreviewingLocation == false else {
            return
        }

        locationManager.stopUpdatingHeading()
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
                syncLiveSnapshot()
                secondsSinceSave += 1
                await checkpointIfNeeded()
            }
        }
    }

    private func syncLiveSnapshot() {
        guard let snapshot = session?.snapshot else {
            currentDuration = 0
            currentDistanceMeters = 0
            coordinates = []
            return
        }

        currentDuration = snapshot.duration
        currentDistanceMeters = snapshot.distanceMeters
        coordinates = snapshot.points.map(\.coordinate)
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
            errorMessage = "Recording continues, but the latest checkpoint could not be saved."
        }
    }

    private func reset() {
        if isPreviewingLocation == false {
            updateTask = nil
            latestLocation = nil
            headingDegrees = nil
        }
        clockTask = nil
        session = nil
        persistence = nil
        syncLiveSnapshot()
        acceptedPointsSinceSave = 0
        secondsSinceSave = 0
        configureBackgroundLocationUpdates()
        phase = .ready
    }
}

extension WalkRecorder: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            self?.authorizationStatus = manager.authorizationStatus
            if self?.isBackgroundRecordingEnabled == true {
                self?.requestAlwaysAuthorizationIfPossible()
            }
            self?.configureBackgroundLocationUpdates()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        Task { @MainActor [weak self] in
            guard newHeading.headingAccuracy >= 0 else {
                return
            }

            let trueHeading = newHeading.trueHeading
            self?.headingDegrees = trueHeading >= 0 ? trueHeading : newHeading.magneticHeading
        }
    }
}
