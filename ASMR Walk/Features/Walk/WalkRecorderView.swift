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

                    if isLocationAccessDenied {
                        openSettingsButton(label: "Open Location Settings")
                    }

                    Spacer()

                    if isRecordingWalk == false {
                        recordingButton
                    }
                }
                .padding()
            }
            .navigationTitle("Walk")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if isBlockedByVideoWalk == false {
                    recorder.refreshAuthorizationStatus()
                    recorder.setBackgroundRecordingEnabled(isBackgroundGPSRecordingEnabled, requestAuthorization: false)
                    recorder.startPreviewingLocation(requestAuthorization: false)
                }
            }
            .onDisappear {
                recorder.stopPreviewingLocation()
            }
            .onChange(of: isBackgroundGPSRecordingEnabled) {
                recorder.setBackgroundRecordingEnabled(isBackgroundGPSRecordingEnabled, requestAuthorization: false)
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
                if scenePhase == .active {
                    recorder.refreshAuthorizationStatus()
                } else if isRecordingWalk, recorder.canContinueInBackground == false {
                    Task {
                        await coordinator.stopAndSave()
                    }
                }
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
            if isBlockedByVideoWalk {
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
        .tint(.green)
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
        if Self.shouldShowDeniedLocationForUITests {
            return "Location access needed"
        }
        return isBlockedByVideoWalk ? "Video walk recording" : recorder.statusTitle
    }

    private var statusDetail: String {
        if Self.shouldShowDeniedLocationForUITests {
            return "Enable location access in Settings to record a route."
        }
        return isBlockedByVideoWalk ? "Finish the active video walk before starting a GPS walk." : recorder.statusDetail
    }

    private var recordingButtonTitle: String {
        if isBlockedByVideoWalk {
            return "Go to Video Walk"
        }
        return "Start Walk"
    }

    private var recordingButtonSystemImage: String {
        if isBlockedByVideoWalk {
            return "video.fill"
        }
        return "figure.walk"
    }

    private var isRecordingButtonDisabled: Bool {
        recorder.phase == .saving || (isRecordingWalk == false && isBlockedByVideoWalk == false && isLocationAccessDenied)
    }

    private var isLocationAccessDenied: Bool {
        recorder.isLocationAccessDenied || Self.shouldShowDeniedLocationForUITests
    }

    private static var shouldShowDeniedLocationForUITests: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["ASMR_WALK_UI_TEST_DENIED_LOCATION"] == "1"
        #else
        false
        #endif
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
