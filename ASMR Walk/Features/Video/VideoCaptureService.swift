//
//  VideoCaptureService.swift
//  ASMR Walk
//

@preconcurrency import AVFoundation
import Foundation
import Observation
import UIKit

struct VideoCaptureAuthorizationSnapshot: Equatable {
    let camera: AVAuthorizationStatus
    let microphone: AVAuthorizationStatus
}

enum VideoCapturePreviewPreparationDecision: Equatable {
    case prepare
    case waitForUserIntent
    case blocked
}

enum VideoCapturePreviewPolicy {
    static func decision(for snapshot: VideoCaptureAuthorizationSnapshot) -> VideoCapturePreviewPreparationDecision {
        if snapshot.camera == .authorized, snapshot.microphone == .authorized {
            return .prepare
        }

        if snapshot.camera == .notDetermined || snapshot.microphone == .notDetermined {
            return .waitForUserIntent
        }

        return .blocked
    }
}

@MainActor
@Observable
final class VideoCaptureService: NSObject {
    enum CaptureError: LocalizedError {
        case permissionDenied
        case cameraUnavailable
        case microphoneUnavailable
        case cannotAddInput
        case cannotAddOutput
        case notReady
        case outputFileMissing

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                "Camera and microphone access are required for video walks."
            case .cameraUnavailable:
                "The camera is unavailable."
            case .microphoneUnavailable:
                "The microphone is unavailable."
            case .cannotAddInput:
                "The camera or microphone could not be connected."
            case .cannotAddOutput:
                "Video recording could not be configured."
            case .notReady:
                "The camera is not ready yet."
            case .outputFileMissing:
                "The video file was not written correctly."
            }
        }
    }

    private(set) var session = AVCaptureSession()

    private(set) var isReady = false
    private(set) var isRecording = false
    private(set) var errorMessage: String?
    private(set) var successMessage: String?
    private(set) var audioLevel: Float = 0
    let audioInputs: VideoAudioInputController
    private(set) var isPreparing = false
    private var audioObservationTasks: [Task<Void, Never>] = []
    private var configuredAudioInputID: String?
    private var isMicrophoneUITest = false

    var audioInputName: String? { audioInputs.currentInput?.name }

    private(set) var cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    private(set) var microphoneAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)

    private var movieOutput = AVCaptureMovieFileOutput()
    private var stopContinuation: CheckedContinuation<URL, Error>?
    private var activeVideoDevice: AVCaptureDevice?
    private var meterTask: Task<Void, Never>?
    private var isSessionActive = false
    private var sessionStopTask: Task<Void, Never>?
    private var sessionStartTask: Task<Void, Never>?
    private var preparationGeneration = 0

    override init() {
        #if DEBUG
        if ProcessInfo.processInfo.environment["ASMR_WALK_UI_TEST_MICROPHONES"] == "1" {
            audioInputs = VideoAudioInputController(routing: PreviewVideoAudioSession())
            isMicrophoneUITest = true
        } else {
            audioInputs = VideoAudioInputController()
        }
        #else
        audioInputs = VideoAudioInputController()
        #endif
        super.init()
        if isMicrophoneUITest {
            try? audioInputs.activate()
            isReady = true
            isRecording = ProcessInfo.processInfo.environment["ASMR_WALK_UI_TEST_MICROPHONE_RECORDING"] == "1"
            audioInputs.setRecording(isRecording)
        }
    }

    var isPermissionDenied: Bool {
        cameraAuthorizationStatus == .denied
            || cameraAuthorizationStatus == .restricted
            || microphoneAuthorizationStatus == .denied
            || microphoneAuthorizationStatus == .restricted
    }

    var needsPermissionRequest: Bool {
        cameraAuthorizationStatus == .notDetermined || microphoneAuthorizationStatus == .notDetermined
    }

    var canPreparePreviewWithoutPrompt: Bool {
        previewPreparationDecision == .prepare
    }

    private var authorizationSnapshot: VideoCaptureAuthorizationSnapshot {
        VideoCaptureAuthorizationSnapshot(
            camera: cameraAuthorizationStatus,
            microphone: microphoneAuthorizationStatus
        )
    }

    private var previewPreparationDecision: VideoCapturePreviewPreparationDecision {
        VideoCapturePreviewPolicy.decision(for: authorizationSnapshot)
    }

    func refreshAuthorizationStatus() {
        guard isMicrophoneUITest == false else { return }
        cameraAuthorizationStatus = Self.authorizationStatus(for: .video)
        microphoneAuthorizationStatus = Self.authorizationStatus(for: .audio)
    }

    func prepare() async {
        await prepare(requestsPermissionIfNeeded: true)
    }

    func prepareIfAuthorized() async {
        guard isMicrophoneUITest == false else { return }
        guard isRecording == false else {
            return
        }

        refreshAuthorizationStatus()

        switch previewPreparationDecision {
        case .prepare:
            await prepare(requestsPermissionIfNeeded: false)
        case .waitForUserIntent:
            errorMessage = nil
            isReady = session.isRunning
        case .blocked:
            errorMessage = CaptureError.permissionDenied.localizedDescription
            stopSession()
        }
    }

    private func prepare(requestsPermissionIfNeeded: Bool) async {
        guard isMicrophoneUITest == false, isPreparing == false else { return }
        guard isReady == false || session.isRunning == false else {
            return
        }

        isPreparing = true
        let generation = preparationGeneration
        defer { isPreparing = false }
        do {
            await sessionStopTask?.value
            sessionStopTask = nil
            cameraAuthorizationStatus = Self.authorizationStatus(for: .video)
            microphoneAuthorizationStatus = Self.authorizationStatus(for: .audio)

            guard await Self.authorizeAccess(for: .video, requestIfNeeded: requestsPermissionIfNeeded),
                  await Self.authorizeAccess(for: .audio, requestIfNeeded: requestsPermissionIfNeeded) else {
                cameraAuthorizationStatus = Self.authorizationStatus(for: .video)
                microphoneAuthorizationStatus = Self.authorizationStatus(for: .audio)
                throw CaptureError.permissionDenied
            }

            cameraAuthorizationStatus = Self.authorizationStatus(for: .video)
            microphoneAuthorizationStatus = Self.authorizationStatus(for: .audio)
            try Task.checkCancellation()
            guard generation == preparationGeneration else { throw CancellationError() }
            resetCapturePipeline()
            try audioInputs.activate()
            try configureSession()
            isSessionActive = true
            await startSession()
            try Task.checkCancellation()
            guard generation == preparationGeneration else { throw CancellationError() }
            isReady = true
            errorMessage = nil
            try audioInputs.refresh()
            configuredAudioInputID = audioInputs.currentInput?.id
            startAudioObservation()
            startAudioMetering()
        } catch is CancellationError {
            stopSession()
        } catch {
            errorMessage = error.localizedDescription
            stopSession()
        }
    }

    func startRecording(orientation: UIInterfaceOrientation = .landscapeRight) throws {
        guard isReady, isPreparing == false, isMicrophoneUITest == false, movieOutput.isRecording == false else {
            throw CaptureError.notReady
        }

        try audioInputs.verifyEffectiveInput()
        if configuredAudioInputID != audioInputs.currentInput?.id {
            try rebuildAudioInput()
        }
        let url = try Self.makeVideoURL()
        if let connection = movieOutput.connection(with: .video),
           let activeVideoDevice {
            let coordinator = AVCaptureDevice.RotationCoordinator(device: activeVideoDevice, previewLayer: nil)
            let sceneAngle = InterfaceOrientationController.videoRotationAngle(for: orientation)
            let angle = orientation.isLandscape ? sceneAngle : coordinator.videoRotationAngleForHorizonLevelCapture
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            } else if connection.isVideoRotationAngleSupported(sceneAngle) {
                connection.videoRotationAngle = sceneAngle
            }
        }

        movieOutput.startRecording(to: url, recordingDelegate: self)
        isRecording = true
        audioInputs.setRecording(true)
        errorMessage = nil
        successMessage = nil
    }

    func report(_ error: Error) {
        errorMessage = error.localizedDescription
    }

    func reportMessage(_ message: String) {
        successMessage = message
    }

    func stopRecording() async throws -> URL {
        guard movieOutput.isRecording, stopContinuation == nil else {
            throw CaptureError.notReady
        }

        return try await withCheckedThrowingContinuation { continuation in
            stopContinuation = continuation
            movieOutput.stopRecording()
        }
    }

    func updateZoomFromDockKitAccessory(factor: Double) {
        guard isReady, let activeVideoDevice else {
            return
        }

        guard factor != 1 else {
            return
        }

        let zoomDirection = factor > 1 ? 1.0 : -1.0
        let zoomStep = 0.2
        let minimumZoomFactor = max(activeVideoDevice.minAvailableVideoZoomFactor, 1.0)
        let maximumZoomFactor = min(activeVideoDevice.maxAvailableVideoZoomFactor, 10.0)
        let requestedZoomFactor = activeVideoDevice.videoZoomFactor + (zoomDirection * zoomStep)
        let nextZoomFactor = min(max(requestedZoomFactor, minimumZoomFactor), maximumZoomFactor)

        do {
            try activeVideoDevice.lockForConfiguration()
            activeVideoDevice.videoZoomFactor = nextZoomFactor
            activeVideoDevice.unlockForConfiguration()
        } catch {
            report(error)
        }
    }

    func stopSession() {
        preparationGeneration += 1
        stopAudioObservation()
        let wasAudioActive = audioInputs.isActive
        audioInputs.stop()
        guard isSessionActive || wasAudioActive else { return }

        isSessionActive = false
        isReady = false
        stopAudioMetering()
        activeVideoDevice = nil

        let session = session
        let audioInputs = audioInputs
        let sessionStartTask = sessionStartTask
        // A subsequent prepare waits for this stop before activating audio again.
        sessionStopTask = Task { @MainActor in
            await sessionStartTask?.value
            await Task { @concurrent in
                if session.isRunning { session.stopRunning() }
            }.value
            do {
                try audioInputs.deactivate()
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func refreshPreview() {
        guard isRecording == false else {
            return
        }

        isReady = false
        resetCapturePipeline()
    }

    private func configureSession() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .high
        session.usesApplicationAudioSession = true
        session.automaticallyConfiguresApplicationAudioSession = false

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CaptureError.cameraUnavailable
        }
        guard let microphone = AVCaptureDevice.default(for: .audio) else {
            throw CaptureError.microphoneUnavailable
        }

        let cameraInput = try AVCaptureDeviceInput(device: camera)
        let microphoneInput = try AVCaptureDeviceInput(device: microphone)

        guard session.canAddInput(cameraInput), session.canAddInput(microphoneInput) else {
            throw CaptureError.cannotAddInput
        }
        session.addInput(cameraInput)
        session.addInput(microphoneInput)

        guard session.canAddOutput(movieOutput) else {
            throw CaptureError.cannotAddOutput
        }
        session.addOutput(movieOutput)
        configureVideoStabilization()
        activeVideoDevice = camera
    }

    var canSelectAudioInput: Bool {
        isReady && isPreparing == false && isRecording == false
    }

    func selectAudioInput(id: String?) {
        guard canSelectAudioInput else { return }
        do {
            try audioInputs.select(id: id)
            if isMicrophoneUITest == false { try rebuildAudioInput() }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func rebuildAudioInput() throws {
        guard isRecording == false else { return }
        guard let microphone = AVCaptureDevice.default(for: .audio) else {
            throw CaptureError.microphoneUnavailable
        }
        let replacement = try AVCaptureDeviceInput(device: microphone)
        let oldInputs = session.inputs.compactMap { $0 as? AVCaptureDeviceInput }
            .filter { $0.device.hasMediaType(.audio) }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        for input in oldInputs { session.removeInput(input) }
        guard session.canAddInput(replacement) else {
            for input in oldInputs where session.canAddInput(input) { session.addInput(input) }
            throw CaptureError.cannotAddInput
        }
        session.addInput(replacement)
        configuredAudioInputID = audioInputs.currentInput?.id
    }

    private func startAudioObservation() {
        stopAudioObservation()
        for name in [AVAudioSession.routeChangeNotification, AVAudioSession.availableInputsChangeNotification] {
            let notifications = NotificationCenter.default.notifications(named: name)
            audioObservationTasks.append(Task { @MainActor [weak self] in
                for await _ in notifications {
                    guard Task.isCancelled == false else { return }
                    self?.handleAudioRouteChange()
                }
            })
        }
    }

    private func stopAudioObservation() {
        for task in audioObservationTasks { task.cancel() }
        audioObservationTasks = []
    }

    private func handleAudioRouteChange() {
        guard audioInputs.isActive else { return }
        do {
            try audioInputs.refresh()
            // Let iOS handle unavoidable hardware removal during a take; never rebuild
            // the capture graph while the movie output is writing the user's file.
            if isReady, isPreparing == false, isRecording == false,
               configuredAudioInputID != audioInputs.currentInput?.id {
                try rebuildAudioInput()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func configureVideoStabilization() {
        guard let connection = movieOutput.connection(with: .video),
              connection.isVideoStabilizationSupported else {
            return
        }

        connection.preferredVideoStabilizationMode = .auto
    }

    private func resetCapturePipeline() {
        stopAudioMetering()
        activeVideoDevice = nil
        movieOutput = AVCaptureMovieFileOutput()
        session = AVCaptureSession()
    }

    private func startAudioMetering() {
        guard meterTask == nil else { return }
        meterTask = Task { @MainActor [weak self] in
            while Task.isCancelled == false {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, Task.isCancelled == false else { return }
                let channels = self.movieOutput.connection(with: .audio)?.audioChannels ?? []
                if channels.isEmpty == false {
                    let avg = channels.map(\.averagePowerLevel).reduce(0, +) / Float(channels.count)
                    // Map dBFS range (-60…0) to linear 0…1; below -60 dBFS treated as silence
                    self.audioLevel = max(0, min(1, (avg + 60) / 60))
                } else {
                    self.audioLevel = 0
                }
            }
        }
    }

    private func stopAudioMetering() {
        meterTask?.cancel()
        meterTask = nil
        audioLevel = 0
    }

    private func startSession() async {
        let session = session
        let task = Task { @concurrent in
            session.startRunning()
        }
        sessionStartTask = task
        await task.value
        sessionStartTask = nil
    }

    private static func authorizationStatus(for mediaType: AVMediaType) -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: mediaType)
    }

    private static func authorizeAccess(for mediaType: AVMediaType, requestIfNeeded: Bool) async -> Bool {
        switch authorizationStatus(for: mediaType) {
        case .authorized:
            true
        case .notDetermined:
            requestIfNeeded ? await AVCaptureDevice.requestAccess(for: mediaType) : false
        case .denied, .restricted:
            false
        @unknown default:
            false
        }
    }

    private static func makeVideoURL() throws -> URL {
        let directory = URL.documentsDirectory
            .appending(path: "Video Walks", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "\(UUID().uuidString).mov")
    }

    private func finishRecording(url: URL, error: Error?) {
        isRecording = false
        audioInputs.setRecording(false)
        handleAudioRouteChange()

        if let error {
            errorMessage = error.localizedDescription
            try? FileManager.default.removeItem(at: url)
            stopContinuation?.resume(throwing: error)
        } else if FileManager.default.fileExists(atPath: url.path) == false {
            errorMessage = CaptureError.outputFileMissing.localizedDescription
            stopContinuation?.resume(throwing: CaptureError.outputFileMissing)
        } else {
            stopContinuation?.resume(returning: url)
        }
        stopContinuation = nil
    }
}

@MainActor
protocol VideoRecordingControlling: AnyObject {
    func stopRecording() async throws -> URL
    func report(_ error: Error)
    func reportMessage(_ message: String)
    func stopSession()
}

extension VideoCaptureService: VideoRecordingControlling {}

extension VideoCaptureService: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            self?.finishRecording(url: outputFileURL, error: error)
        }
    }
}
