//
//  VideoWalkView.swift
//  ASMR Walk
//

import MapKit
import SwiftData
import SwiftUI
import UIKit

enum VideoWalkStopOutcome: Equatable {
    case savedToPhotos(assetIdentifier: String, localVideoURL: URL)
    case keptLocalVideo(videoURL: URL, message: String)
    case discarded(message: String)

    static func photosSaveSucceeded(assetIdentifier: String, localVideoURL: URL) -> Self {
        .savedToPhotos(assetIdentifier: assetIdentifier, localVideoURL: localVideoURL)
    }

    static func photosSaveFailed(videoURL: URL, error: Error) -> Self {
        .keptLocalVideo(videoURL: videoURL, message: error.localizedDescription)
    }

    static func stopFailed(error: Error) -> Self {
        .discarded(message: error.localizedDescription)
    }
}

struct VideoWalkView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var camera = VideoCaptureService()
    @State private var dockKitAccessory = DockKitAccessoryService()
    let coordinator: RecordingCoordinator
    let stopRequestID: UUID?
    let showActiveRecording: () -> Void
    @State private var isStopping = false
    @State private var isShowingShortRecordingConfirmation = false
    @State private var shouldStopSessionAfterShortConfirmation = false

    private let maximumRouteMapSize: CGFloat = 220
    private let minimumRouteMapSize: CGFloat = 128

    var body: some View {
        ZStack {
            CameraPreview(
                session: camera.session,
                videoRotationAngle: InterfaceOrientationController.videoRotationAngle(
                    for: InterfaceOrientationController.videoWalkOrientation
                )
            )
                .ignoresSafeArea()

            LinearGradient(
                colors: gradientColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            GeometryReader { proxy in
                overlayLayout(availableSize: proxy.size)
            }
        }
        .accessibilityIdentifier(AccessibilityID.videoWalkScreen)
        .toolbarVisibility(isRecordingVideoWalk ? .hidden : .visible, for: .tabBar)
        .task {
            InterfaceOrientationController.lockVideoWalkLandscape()
            await preparePreviewIfAuthorized()
            dockKitAccessory.start(
                shutterAction: handleDockKitShutter,
                zoomAction: camera.updateZoomFromDockKitAccessory
            )
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            dockKitAccessory.stop()
            if isRecordingVideoWalk {
                stopVideoWalk(stopSessionWhenFinished: true, confirmShortRecording: false)
            } else {
                if coordinator.activeMode == nil {
                    walkRecorder.stopPreviewingLocation()
                }
                camera.stopSession()
            }
            InterfaceOrientationController.restoreDefaultOrientation()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                Task {
                    await preparePreviewIfAuthorized()
                }
            } else if isRecordingVideoWalk {
                stopVideoWalk(confirmShortRecording: false)
            }
        }
        .onChange(of: stopRequestID, initial: true) {
            guard stopRequestID != nil, isRecordingVideoWalk else {
                return
            }
            stopVideoWalk()
        }
        .confirmationDialog("Save Short Video Walk?", isPresented: $isShowingShortRecordingConfirmation) {
            Button("Save Video Walk") {
                Task {
                    await coordinator.saveFinishedRecording()
                    cleanupAfterShortRecordingDecision()
                }
            }
            Button("Discard Video Walk", role: .destructive) {
                Task {
                    await coordinator.discard()
                    cleanupAfterShortRecordingDecision()
                }
            }
        } message: {
            Text("This video walk is shorter than 10 seconds.")
        }
    }

    private var statusCard: some View {
        RecordingStatusCard(
            title: statusTitle,
            detail: statusDetail,
            systemImage: isBlockedByWalk ? "figure.walk" : isRecordingVideoWalk ? "record.circle.fill" : "video.fill",
            accessibilityIdentifier: AccessibilityID.videoStatus
        )
        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 360, alignment: .leading)
    }

    private var shouldShowStatusCard: Bool {
        shouldShowRecordingIndicator == false || isStopping || camera.errorMessage != nil || walkRecorder.errorMessage != nil
    }

    private var recordingIndicator: some View {
        PulsingRecordingIndicator()
            .accessibilityIdentifier(AccessibilityID.videoRecordingIndicator)
    }

    private func overlayLayout(availableSize: CGSize) -> some View {
        let mapSize = routeMapSize(for: availableSize)

        return HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                if shouldShowStatusCard {
                    statusCard
                } else if shouldShowRecordingIndicator {
                    recordingIndicator
                }
                if isPrivacyAccessDenied {
                    openSettingsButton
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? availableSize.width * 0.54 : .infinity, alignment: .leading)

            Spacer(minLength: 12)

            VStack(spacing: 16) {
                routeMap(size: mapSize)
                if isRecordingVideoWalk == false {
                    recordingButton
                }
            }
            .frame(width: mapSize)
        }
        .padding()
    }

    private func routeMap(size: CGFloat) -> some View {
        Map(initialPosition: .userLocation(followsHeading: false, fallback: .automatic)) {
            UserAnnotation {
                FacingLocationIndicator(headingDegrees: walkRecorder.headingDegrees)
            }

            if walkRecorder.coordinates.count > 1 {
                MapPolyline(coordinates: walkRecorder.coordinates)
                    .stroke(.green, style: StrokeStyle(lineWidth: 5, lineCap: .round))
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    .primary.opacity(usesHighContrastSurfaces ? 0.45 : 0.18),
                    lineWidth: usesHighContrastSurfaces ? 2 : 1
                )
        }
        .accessibilityLabel("Live walking route")
        .accessibilityHint("Shows your current position and recorded route while video walk recording is available.")
    }

    private var recordingButton: some View {
        Button(
            recordingButtonTitle,
            systemImage: recordingButtonSystemImage
        ) {
            if isBlockedByWalk {
                showActiveRecording()
            } else {
                startVideoWalk()
            }
        }
        .font(.headline)
        .frame(maxWidth: .infinity)
        .controlSize(.large)
        .buttonStyle(.glassProminent)
        .tint(.red)
        .disabled(isRecordingButtonDisabled)
        .accessibilityIdentifier(AccessibilityID.startVideoWalkButton)
    }

    private var openSettingsButton: some View {
        Button("Open Privacy Settings", systemImage: "gear") {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }
        }
        .buttonStyle(.glass)
        .accessibilityIdentifier(AccessibilityID.openSettingsButton)
    }

    private var statusTitle: String {
        if isStopping {
            return "Saving video walk"
        }
        if isBlockedByWalk {
            return "GPS walk recording"
        }
        if Self.shouldShowDeniedVideoPrivacyForUITests {
            return "Privacy access needed"
        }
        if isPrivacyAccessDenied {
            return "Privacy access needed"
        }
        if isRecordingVideoWalk {
            return "Recording video walk"
        }
        if camera.errorMessage != nil || walkRecorder.errorMessage != nil {
            return "Video unavailable"
        }
        if camera.needsPermissionRequest {
            return "Ready when you are"
        }
        if camera.canPreparePreviewWithoutPrompt {
            return camera.isReady ? "Camera ready" : "Preparing camera"
        }
        return "Ready when you are"
    }

    private var statusDetail: String {
        if isBlockedByWalk {
            return "Finish the active GPS walk before starting a video walk."
        }

        if Self.shouldShowDeniedVideoPrivacyForUITests {
            return "Enable camera, microphone, and location access in Settings to record a video walk."
        }

        if isPrivacyAccessDenied {
            return "Enable camera, microphone, and location access in Settings to record a video walk."
        }

        if let errorMessage = camera.errorMessage ?? walkRecorder.errorMessage {
            return errorMessage
        }

        if camera.needsPermissionRequest, walkRecorder.authorizationStatus == .notDetermined {
            return "Starting a video walk asks for camera, microphone, and location access."
        }

        if camera.needsPermissionRequest {
            return "Starting a video walk asks for camera and microphone access."
        }

        if walkRecorder.authorizationStatus == .notDetermined {
            return "Starting a video walk asks for location access to save your route."
        }

        if camera.canPreparePreviewWithoutPrompt, camera.isReady == false {
            return "Starting the live preview."
        }

        return "Video and route recording start together."
    }

    private var walkRecorder: WalkRecorder {
        coordinator.recorder
    }

    private var gradientColors: [Color] {
        if reduceTransparency || usesHighContrastSurfaces {
            return [.black.opacity(0.72), .black.opacity(0.2), .black.opacity(0.78)]
        }

        return [.black.opacity(0.5), .clear, .black.opacity(0.65)]
    }

    private var usesHighContrastSurfaces: Bool {
        colorSchemeContrast == .increased || AccessibilityQALaunchConfiguration.usesAdaptiveAccessibilitySurfaces
    }

    private func routeMapSize(for availableSize: CGSize) -> CGFloat {
        let widthLimit = availableSize.width * (dynamicTypeSize.isAccessibilitySize ? 0.24 : 0.28)
        let heightLimit = availableSize.height * (dynamicTypeSize.isAccessibilitySize ? 0.36 : 0.44)
        return min(maximumRouteMapSize, max(minimumRouteMapSize, min(widthLimit, heightLimit)))
    }

    private var isRecordingVideoWalk: Bool {
        coordinator.activeMode == .videoWalk && walkRecorder.isRecording
    }

    private var shouldShowRecordingIndicator: Bool {
        isRecordingVideoWalk || Self.shouldShowRecordingIndicatorForUITests
    }

    private var isBlockedByWalk: Bool {
        coordinator.blockingMode(for: .videoWalk) == .walk
    }

    private var recordingButtonTitle: String {
        if isBlockedByWalk {
            return "Go to Walk"
        }
        return "Start Video Walk"
    }

    private var recordingButtonSystemImage: String {
        if isBlockedByWalk {
            return "figure.walk"
        }
        return "record.circle"
    }

    private var isRecordingButtonDisabled: Bool {
        isStopping || (isBlockedByWalk == false && isPrivacyAccessDenied)
    }

    private var isPrivacyAccessDenied: Bool {
        camera.isPermissionDenied
            || walkRecorder.isLocationAccessDenied
            || Self.shouldShowDeniedVideoPrivacyForUITests
    }

    private static var shouldShowRecordingIndicatorForUITests: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["ASMR_WALK_UI_TEST_SHOW_VIDEO_RECORDING_INDICATOR"] == "1"
        #else
        false
        #endif
    }

    private static var shouldShowDeniedVideoPrivacyForUITests: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["ASMR_WALK_UI_TEST_DENIED_VIDEO_PRIVACY"] == "1"
        #else
        false
        #endif
    }

    private func preparePreviewIfAuthorized() async {
        camera.refreshAuthorizationStatus()
        if coordinator.activeMode != .walk {
            walkRecorder.refreshAuthorizationStatus()
            walkRecorder.startPreviewingLocation(requestAuthorization: false)
        }
        await camera.prepareIfAuthorized()
    }

    private func startVideoWalk() {
        Task {
            await camera.prepare()
            guard camera.isReady else {
                return
            }

            let didStartRecording = await coordinator.start(in: modelContext, mode: .videoWalk)
            guard didStartRecording else {
                return
            }

            do {
                try camera.startRecording(orientation: InterfaceOrientationController.videoWalkOrientation)
                UIApplication.shared.isIdleTimerDisabled = true
            } catch {
                await coordinator.discard()
                camera.report(error)
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }

    private func handleDockKitShutter() {
        if isBlockedByWalk {
            showActiveRecording()
            return
        }

        if isRecordingVideoWalk {
            stopVideoWalk()
            return
        }

        guard camera.isPermissionDenied == false, walkRecorder.isLocationAccessDenied == false else {
            return
        }

        if camera.isReady {
            startVideoWalk()
        } else {
            Task {
                await camera.prepareIfAuthorized()
                guard camera.isReady else {
                    return
                }
                startVideoWalk()
            }
        }
    }

    private func stopVideoWalk(
        stopSessionWhenFinished: Bool = false,
        confirmShortRecording: Bool = true
    ) {
        guard isStopping == false else {
            return
        }

        isStopping = true
        Task {
            do {
                let videoURL = try await camera.stopRecording()
                do {
                    camera.reportMessage(PhotoLibraryVideoStore.saveAccessExplanation)
                    let assetIdentifier = try await PhotoLibraryVideoStore.saveVideoToPhotoLibrary(from: videoURL)
                    apply(VideoWalkStopOutcome.photosSaveSucceeded(assetIdentifier: assetIdentifier, localVideoURL: videoURL))
                } catch {
                    apply(VideoWalkStopOutcome.photosSaveFailed(videoURL: videoURL, error: error))
                }
                UIApplication.shared.isIdleTimerDisabled = false
            } catch {
                UIApplication.shared.isIdleTimerDisabled = false
                apply(VideoWalkStopOutcome.stopFailed(error: error))
                await coordinator.discard()
                if stopSessionWhenFinished {
                    walkRecorder.stopPreviewingLocation()
                    camera.stopSession()
                }
                isStopping = false
                return
            }

            guard coordinator.finishRecording() else {
                isStopping = false
                return
            }

            if confirmShortRecording, walkRecorder.isShortRecording {
                shouldStopSessionAfterShortConfirmation = stopSessionWhenFinished
                isShowingShortRecordingConfirmation = true
            } else {
                await coordinator.saveFinishedRecording()
                if stopSessionWhenFinished {
                    walkRecorder.stopPreviewingLocation()
                    camera.stopSession()
                }
            }
            isStopping = false
        }
    }

    private func apply(_ outcome: VideoWalkStopOutcome) {
        switch outcome {
        case let .savedToPhotos(assetIdentifier, localVideoURL):
            walkRecorder.attachPhotoLibraryVideo(assetIdentifier: assetIdentifier)
            try? FileManager.default.removeItem(at: localVideoURL)
            camera.reportMessage("Video walk saved to Photos.")
        case let .keptLocalVideo(videoURL, message):
            walkRecorder.attachVideo(at: videoURL)
            camera.reportMessage(message)
        case let .discarded(message):
            camera.reportMessage(message)
        }
    }

    private func cleanupAfterShortRecordingDecision() {
        if shouldStopSessionAfterShortConfirmation {
            walkRecorder.stopPreviewingLocation()
            camera.stopSession()
        }
        shouldStopSessionAfterShortConfirmation = false
    }
}

private struct PulsingRecordingIndicator: View {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var isExpanded = false

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(.green)
                    .frame(width: isExpanded ? 14 : 7, height: isExpanded ? 14 : 7)
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.9), lineWidth: 2)
                    }
            }
            .frame(width: 14, height: 14)

            Text("REC")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .monospaced()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(indicatorBackgroundColor, in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Recording video")
        .accessibilityValue("REC")
        .onAppear {
            guard reduceMotion == false else {
                isExpanded = false
                return
            }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                isExpanded = true
            }
        }
        .onDisappear {
            isExpanded = false
        }
    }

    private var indicatorBackgroundColor: Color {
        if reduceTransparency
            || colorSchemeContrast == .increased
            || AccessibilityQALaunchConfiguration.usesAdaptiveAccessibilitySurfaces {
            return .black
        }

        return .black.opacity(0.7)
    }
}
