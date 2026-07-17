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
    private(set) var cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    private(set) var microphoneAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)

    private var movieOutput = AVCaptureMovieFileOutput()
    private var stopContinuation: CheckedContinuation<URL, Error>?
    private var activeVideoDevice: AVCaptureDevice?

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
        cameraAuthorizationStatus = Self.authorizationStatus(for: .video)
        microphoneAuthorizationStatus = Self.authorizationStatus(for: .audio)
    }

    func prepare() async {
        await prepare(requestsPermissionIfNeeded: true)
    }

    func prepareIfAuthorized() async {
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
        guard isReady == false || session.isRunning == false else {
            return
        }

        do {
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
            resetCapturePipeline()
            try configureSession()
            await startSession()
            try Task.checkCancellation()
            isReady = true
            errorMessage = nil
        } catch is CancellationError {
            stopSession()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startRecording(orientation: UIInterfaceOrientation = .landscapeRight) throws {
        guard isReady, movieOutput.isRecording == false else {
            throw CaptureError.notReady
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
        errorMessage = nil
    }

    func report(_ error: Error) {
        errorMessage = error.localizedDescription
    }

    func reportMessage(_ message: String) {
        errorMessage = message
    }

    func stopRecording() async throws -> URL {
        guard movieOutput.isRecording else {
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
        isReady = false

        guard session.isRunning else {
            resetCapturePipeline()
            return
        }

        let session = session
        Task { @concurrent in
            session.stopRunning()
        }
        resetCapturePipeline()
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
        activeVideoDevice = camera
    }

    private func resetCapturePipeline() {
        activeVideoDevice = nil
        movieOutput = AVCaptureMovieFileOutput()
        session = AVCaptureSession()
    }

    private func startSession() async {
        let session = session
        await Task { @concurrent in
            session.startRunning()
        }.value
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
