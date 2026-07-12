//
//  WalkRecorderView.swift
//  ASMR Walk
//

import MapKit
import SwiftData
import SwiftUI
import UIKit

struct WalkRecorderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(BackgroundGPSRecording.storageKey) private var isBackgroundGPSRecordingEnabled = BackgroundGPSRecording.defaultValue
    let coordinator: RecordingCoordinator
    let showActiveRecording: () -> Void
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var hasPositionedCamera = false
    @State private var isShowingShortRecordingConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                liveMap

                VStack(spacing: 16) {
                    RecordingStatusCard(
                        title: statusTitle,
                        detail: statusDetail,
                        systemImage: isBlockedByVideoWalk ? "video.fill" : recorder.isRecording ? "location.fill.viewfinder" : "location.fill"
                    )
                    .accessibilityIdentifier(AccessibilityID.walkStatus)

                    if recorder.isLocationAccessDenied {
                        openSettingsButton(label: "Open Location Settings")
                    }

                    Spacer()

                    RecordingMetrics(
                        duration: recorder.currentDuration,
                        distanceMeters: recorder.currentDistanceMeters
                    )
                    .accessibilityIdentifier(AccessibilityID.walkMetrics)

                    recordingButton
                }
                .padding()
            }
            .navigationTitle("Walk")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if isBlockedByVideoWalk == false {
                    recorder.setBackgroundRecordingEnabled(isBackgroundGPSRecordingEnabled)
                    recorder.startPreviewingLocation()
                }
            }
            .onDisappear {
                recorder.stopPreviewingLocation()
            }
            .onChange(of: isBackgroundGPSRecordingEnabled) {
                recorder.setBackgroundRecordingEnabled(isBackgroundGPSRecordingEnabled)
            }
            .onChange(of: recorder.latestLocation?.timestamp) {
                guard hasPositionedCamera == false, let location = recorder.latestLocation else {
                    return
                }

                cameraPosition = .camera(
                    MapCamera(
                        centerCoordinate: location.coordinate,
                        distance: 800,
                        heading: 0,
                        pitch: 0
                    )
                )
                hasPositionedCamera = true
            }
            .onChange(of: scenePhase) {
                if scenePhase != .active, isRecordingWalk, recorder.canContinueInBackground == false {
                    Task {
                        await coordinator.stopAndSave()
                    }
                }
            }
            .confirmationDialog("Save Short Walk?", isPresented: $isShowingShortRecordingConfirmation) {
                Button("Save Walk") {
                    Task {
                        await coordinator.saveFinishedRecording()
                    }
                }
                Button("Discard Walk", role: .destructive) {
                    Task {
                        await coordinator.discard()
                    }
                }
            } message: {
                Text("This walk is shorter than 10 seconds.")
            }
        }
    }

    private var liveMap: some View {
        Map(position: $cameraPosition) {
            UserAnnotation {
                FacingLocationIndicator(headingDegrees: recorder.headingDegrees)
            }

            if recorder.coordinates.count > 1 {
                MapPolyline(coordinates: recorder.coordinates)
                    .stroke(.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .ignoresSafeArea()
    }

    private var recordingButton: some View {
        Button(
            recordingButtonTitle,
            systemImage: recordingButtonSystemImage
        ) {
            if isRecordingWalk {
                stopWalk()
            } else if isBlockedByVideoWalk {
                showActiveRecording()
            } else {
                Task {
                    await coordinator.start(
                        in: modelContext,
                        mode: .walk,
                        allowsBackgroundRecording: isBackgroundGPSRecordingEnabled
                    )
                }
            }
        }
        .font(.headline)
        .frame(maxWidth: .infinity)
        .controlSize(.large)
        .buttonStyle(.glassProminent)
        .tint(isRecordingWalk ? .red : .green)
        .disabled(isRecordingButtonDisabled)
        .accessibilityIdentifier(AccessibilityID.startWalkButton)
    }

    private var recorder: WalkRecorder {
        coordinator.recorder
    }

    private var isRecordingWalk: Bool {
        coordinator.activeMode == .walk && recorder.isRecording
    }

    private var isBlockedByVideoWalk: Bool {
        coordinator.blockingMode(for: .walk) == .videoWalk
    }

    private var statusTitle: String {
        isBlockedByVideoWalk ? "Video walk recording" : recorder.statusTitle
    }

    private var statusDetail: String {
        isBlockedByVideoWalk ? "Finish the active video walk before starting a GPS walk." : recorder.statusDetail
    }

    private var recordingButtonTitle: String {
        if isRecordingWalk {
            return "Stop and Save"
        }
        if isBlockedByVideoWalk {
            return "Go to Video Walk"
        }
        return "Start Walk"
    }

    private var recordingButtonSystemImage: String {
        if isRecordingWalk {
            return "stop.fill"
        }
        if isBlockedByVideoWalk {
            return "video.fill"
        }
        return "figure.walk"
    }

    private var isRecordingButtonDisabled: Bool {
        recorder.phase == .saving || (isRecordingWalk == false && isBlockedByVideoWalk == false && recorder.isLocationAccessDenied)
    }

    private func stopWalk() {
        if recorder.isShortRecording {
            recorder.finishRecording()
            isShowingShortRecordingConfirmation = true
        } else {
            Task {
                await coordinator.stopAndSave()
            }
        }
    }

    private func openSettingsButton(label: String) -> some View {
        Button(label, systemImage: "gear") {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }
        }
        .buttonStyle(.glass)
        .accessibilityIdentifier(AccessibilityID.openSettingsButton)
    }
}
