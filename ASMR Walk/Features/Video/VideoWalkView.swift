//
//  VideoWalkView.swift
//  ASMR Walk
//

import MapKit
import SwiftData
import SwiftUI
import UIKit

struct VideoWalkView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var camera = VideoCaptureService()
    @State private var dockKitAccessory = DockKitAccessoryService()
    let coordinator: RecordingCoordinator
    let stopRequestID: UUID?
    let showActiveRecording: () -> Void
    @State private var isStopping = false
    @State private var isShowingShortRecordingConfirmation = false
    @State private var shouldStopSessionAfterShortConfirmation = false

    private let routeMapSize: CGFloat = 220

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
                colors: [.black.opacity(0.5), .clear, .black.opacity(0.65)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    if shouldShowStatusCard {
                        statusCard
                    } else if shouldShowRecordingIndicator {
                        recordingIndicator
                    }
                    if camera.isPermissionDenied || walkRecorder.isLocationAccessDenied {
                        openSettingsButton
                    }
                    Spacer()
                }

                Spacer()

                VStack(spacing: 16) {
                    routeMap
                    if isRecordingVideoWalk == false {
                        recordingButton
                    }
                }
                .frame(width: routeMapSize)
            }
            .padding()
        }
        .accessibilityIdentifier(AccessibilityID.videoWalkScreen)
        .toolbarVisibility(isRecordingVideoWalk ? .hidden : .visible, for: .tabBar)
        .task {
            InterfaceOrientationController.lockVideoWalkLandscape()
            if coordinator.activeMode != .walk {
                walkRecorder.startPreviewingLocation()
            }
            camera.refreshPreview()
            dockKitAccessory.start(
                shutterAction: handleDockKitShutter,
                zoomAction: camera.updateZoomFromDockKitAccessory
            )
            await camera.prepare()
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
            guard scenePhase != .active, isRecordingVideoWalk else {
                return
            }
            stopVideoWalk(confirmShortRecording: false)
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
            systemImage: isBlockedByWalk ? "figure.walk" : isRecordingVideoWalk ? "record.circle.fill" : "video.fill"
        )
        .frame(maxWidth: 360)
        .accessibilityIdentifier(AccessibilityID.videoStatus)
    }

    private var shouldShowStatusCard: Bool {
        shouldShowRecordingIndicator == false || isStopping || camera.errorMessage != nil || walkRecorder.errorMessage != nil
    }

    private var recordingIndicator: some View {
        PulsingRecordingIndicator()
            .accessibilityIdentifier(AccessibilityID.videoRecordingIndicator)
    }

    private var routeMap: some View {
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
        .frame(width: routeMapSize, height: routeMapSize)
        .clipShape(.rect(cornerRadius: 20))
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .accessibilityLabel("Live walking route")
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
        if isRecordingVideoWalk {
            return "Recording video walk"
        }
        return camera.isReady ? "Camera ready" : "Preparing camera"
    }

    private var statusDetail: String {
        if isBlockedByWalk {
            return "Finish the active GPS walk before starting a video walk."
        }

        return camera.errorMessage
            ?? walkRecorder.errorMessage
            ?? "Video and route recording start together."
    }

    private var walkRecorder: WalkRecorder {
        coordinator.recorder
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
        isStopping || (isBlockedByWalk == false && (camera.isReady == false || camera.isPermissionDenied || walkRecorder.isLocationAccessDenied))
    }

    private static var shouldShowRecordingIndicatorForUITests: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["ASMR_WALK_UI_TEST_SHOW_VIDEO_RECORDING_INDICATOR"] == "1"
        #else
        false
        #endif
    }

    private func startVideoWalk() {
        Task {
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

        guard camera.isReady, camera.isPermissionDenied == false, walkRecorder.isLocationAccessDenied == false else {
            return
        }

        if isRecordingVideoWalk {
            stopVideoWalk()
        } else {
            startVideoWalk()
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
                    let assetIdentifier = try await PhotoLibraryVideoStore.saveVideoToPhotoLibrary(from: videoURL)
                    walkRecorder.attachPhotoLibraryVideo(assetIdentifier: assetIdentifier)
                    try? FileManager.default.removeItem(at: videoURL)
                } catch {
                    walkRecorder.attachVideo(at: videoURL)
                    camera.report(error)
                }
                UIApplication.shared.isIdleTimerDisabled = false
            } catch {
                UIApplication.shared.isIdleTimerDisabled = false
                camera.report(error)
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

    private func cleanupAfterShortRecordingDecision() {
        if shouldStopSessionAfterShortConfirmation {
            walkRecorder.stopPreviewingLocation()
            camera.stopSession()
        }
        shouldStopSessionAfterShortConfirmation = false
    }
}

private struct PulsingRecordingIndicator: View {
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
        .background(.black.opacity(0.7), in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Recording video")
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                isExpanded = true
            }
        }
        .onDisappear {
            isExpanded = false
        }
    }
}
