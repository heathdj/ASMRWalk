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
    @State private var walkRecorder = WalkRecorder()
    @State private var isStopping = false
    @State private var isShowingShortRecordingConfirmation = false
    @State private var shouldStopSessionAfterShortConfirmation = false

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

            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    if shouldShowStatusCard {
                        statusCard
                    } else if walkRecorder.isRecording {
                        recordingIndicator
                    }
                    if camera.isPermissionDenied || walkRecorder.isLocationAccessDenied {
                        openSettingsButton
                    }
                    Spacer()
                    RecordingMetrics(
                        duration: walkRecorder.recording?.duration ?? 0,
                        distanceMeters: walkRecorder.recording?.distanceMeters ?? 0
                    )
                    .frame(maxWidth: 360)
                    .accessibilityIdentifier(AccessibilityID.videoMetrics)
                }

                Spacer()

                VStack(spacing: 16) {
                    routeMap
                    recordingButton
                }
                .frame(width: 220)
            }
            .padding()
        }
        .accessibilityIdentifier(AccessibilityID.videoWalkScreen)
        .task {
            InterfaceOrientationController.lockVideoWalkLandscape()
            walkRecorder.startPreviewingLocation()
            camera.refreshPreview()
            await camera.prepare()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            if walkRecorder.isRecording {
                stopVideoWalk(stopSessionWhenFinished: true, confirmShortRecording: false)
            } else {
                walkRecorder.stopPreviewingLocation()
                camera.stopSession()
            }
            InterfaceOrientationController.restoreDefaultOrientation()
        }
        .onChange(of: scenePhase) {
            guard scenePhase != .active, walkRecorder.isRecording else {
                return
            }
            stopVideoWalk(confirmShortRecording: false)
        }
        .confirmationDialog("Save Short Video Walk?", isPresented: $isShowingShortRecordingConfirmation) {
            Button("Save Video Walk") {
                walkRecorder.saveFinishedRecording()
                cleanupAfterShortRecordingDecision()
            }
            Button("Discard Video Walk", role: .destructive) {
                walkRecorder.discard()
                cleanupAfterShortRecordingDecision()
            }
        } message: {
            Text("This video walk is shorter than 10 seconds.")
        }
    }

    private var statusCard: some View {
        RecordingStatusCard(
            title: statusTitle,
            detail: statusDetail,
            systemImage: walkRecorder.isRecording ? "record.circle.fill" : "video.fill"
        )
        .frame(maxWidth: 360)
        .accessibilityIdentifier(AccessibilityID.videoStatus)
    }

    private var shouldShowStatusCard: Bool {
        walkRecorder.isRecording == false || isStopping || camera.errorMessage != nil || walkRecorder.errorMessage != nil
    }

    private var recordingIndicator: some View {
        Circle()
            .fill(.green)
            .frame(width: 14, height: 14)
            .overlay {
                Circle()
                    .stroke(.white.opacity(0.9), lineWidth: 2)
            }
            .shadow(radius: 2)
            .accessibilityLabel("Camera recording")
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
        .clipShape(.rect(cornerRadius: 20))
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .accessibilityLabel("Live walking route")
    }

    private var recordingButton: some View {
        Button(
            walkRecorder.isRecording ? "Stop and Save" : "Start Video Walk",
            systemImage: walkRecorder.isRecording ? "stop.fill" : "record.circle"
        ) {
            if walkRecorder.isRecording {
                stopVideoWalk()
            } else {
                startVideoWalk()
            }
        }
        .font(.headline)
        .frame(maxWidth: .infinity)
        .controlSize(.large)
        .buttonStyle(.glassProminent)
        .tint(.red)
        .disabled(camera.isReady == false || camera.isPermissionDenied || walkRecorder.isLocationAccessDenied || isStopping)
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
        if walkRecorder.isRecording {
            return "Recording video walk"
        }
        return camera.isReady ? "Camera ready" : "Preparing camera"
    }

    private var statusDetail: String {
        camera.errorMessage
            ?? walkRecorder.errorMessage
            ?? "Video and route recording start together."
    }

    private func startVideoWalk() {
        walkRecorder.start(in: modelContext, mode: .videoWalk)
        guard walkRecorder.isRecording else {
            return
        }

        do {
            try camera.startRecording(orientation: InterfaceOrientationController.videoWalkOrientation)
            UIApplication.shared.isIdleTimerDisabled = true
        } catch {
            walkRecorder.discard()
            camera.report(error)
            UIApplication.shared.isIdleTimerDisabled = false
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
                walkRecorder.discard()
                if stopSessionWhenFinished {
                    walkRecorder.stopPreviewingLocation()
                    camera.stopSession()
                }
                isStopping = false
                return
            }

            guard walkRecorder.finishRecording() else {
                isStopping = false
                return
            }

            if confirmShortRecording, walkRecorder.isShortRecording {
                shouldStopSessionAfterShortConfirmation = stopSessionWhenFinished
                isShowingShortRecordingConfirmation = true
            } else {
                walkRecorder.saveFinishedRecording()
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
