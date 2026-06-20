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
    @State private var recorder = WalkRecorder()
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var hasPositionedCamera = false
    @State private var isShowingShortRecordingConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                liveMap

                VStack(spacing: 16) {
                    RecordingStatusCard(
                        title: recorder.statusTitle,
                        detail: recorder.statusDetail,
                        systemImage: recorder.isRecording ? "location.fill.viewfinder" : "location.fill"
                    )
                    .accessibilityIdentifier(AccessibilityID.walkStatus)

                    if recorder.isLocationAccessDenied {
                        openSettingsButton(label: "Open Location Settings")
                    }

                    Spacer()

                    RecordingMetrics(
                        duration: recorder.recording?.duration ?? 0,
                        distanceMeters: recorder.recording?.distanceMeters ?? 0
                    )
                    .accessibilityIdentifier(AccessibilityID.walkMetrics)

                    recordingButton
                }
                .padding()
            }
            .navigationTitle("Walk")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                recorder.startPreviewingLocation()
            }
            .onDisappear {
                recorder.stopPreviewingLocation()
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
                if scenePhase != .active, recorder.isRecording {
                    recorder.stopAndSave()
                }
            }
            .confirmationDialog("Save Short Walk?", isPresented: $isShowingShortRecordingConfirmation) {
                Button("Save Walk") {
                    recorder.saveFinishedRecording()
                }
                Button("Discard Walk", role: .destructive) {
                    recorder.discard()
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
            recorder.isRecording ? "Stop and Save" : "Start Walk",
            systemImage: recorder.isRecording ? "stop.fill" : "figure.walk"
        ) {
            if recorder.isRecording {
                stopWalk()
            } else {
                recorder.start(in: modelContext)
            }
        }
        .font(.headline)
        .frame(maxWidth: .infinity)
        .controlSize(.large)
        .buttonStyle(.glassProminent)
        .tint(recorder.isRecording ? .red : .green)
        .disabled(recorder.phase == .saving || recorder.isLocationAccessDenied)
        .accessibilityIdentifier(AccessibilityID.startWalkButton)
    }

    private func stopWalk() {
        if recorder.isShortRecording {
            recorder.finishRecording()
            isShowingShortRecordingConfirmation = true
        } else {
            recorder.stopAndSave()
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
