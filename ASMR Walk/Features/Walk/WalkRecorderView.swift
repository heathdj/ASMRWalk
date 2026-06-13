//
//  WalkRecorderView.swift
//  ASMR Walk
//

import MapKit
import SwiftData
import SwiftUI

struct WalkRecorderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var recorder = WalkRecorder()
    @State private var cameraPosition: MapCameraPosition = .userLocation(
        followsHeading: false,
        fallback: .automatic
    )

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
            .onChange(of: recorder.coordinates.count) {
                guard recorder.coordinates.isEmpty == false else {
                    return
                }
                cameraPosition = .automatic
            }
            .onChange(of: scenePhase) {
                if scenePhase != .active, recorder.isRecording {
                    recorder.stopAndSave()
                }
            }
        }
    }

    private var liveMap: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()

            if recorder.coordinates.count > 1 {
                MapPolyline(coordinates: recorder.coordinates)
                    .stroke(.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .ignoresSafeArea()
    }

    private var recordingButton: some View {
        Button(
            recorder.isRecording ? "Stop and Save" : "Start Walk",
            systemImage: recorder.isRecording ? "stop.fill" : "figure.walk"
        ) {
            if recorder.isRecording {
                recorder.stopAndSave()
            } else {
                recorder.start(in: modelContext)
            }
        }
        .font(.headline)
        .frame(maxWidth: .infinity)
        .controlSize(.large)
        .buttonStyle(.glassProminent)
        .tint(recorder.isRecording ? .red : .green)
        .disabled(recorder.phase == .saving)
        .accessibilityIdentifier(AccessibilityID.startWalkButton)
    }
}
