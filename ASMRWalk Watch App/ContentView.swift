//
//  ContentView.swift
//  ASMRWalk Watch App
//
//  Created by David Heath on 8/29/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var recorder = WatchRecorder()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                statusHeader
                primaryRecordingControl
                metricsGrid
                gpsStatus
                secondaryRecordingControl
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .accessibilityElement(children: .contain)
        .task {
            recorder.refreshAuthorizationStatus()
        }
    }

    private var statusHeader: some View {
        VStack(spacing: 4) {
            Image(systemName: statusSymbol)
                .font(.system(size: 40))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(statusColor)

            Text(recorder.statusTitle)
                .font(.title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            Text(recorder.statusDetail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var metricsGrid: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                metric(recorder.currentDuration.timerText, label: "Time", systemImage: "timer")
                metric(recorder.currentDistanceMeters.distanceText, label: "Distance", systemImage: "map")
            }

            GridRow {
                metric("\(recorder.pointCount)", label: "Points", systemImage: "mappin.and.ellipse")
                metric(accuracyText, label: "GPS", systemImage: gpsSymbol)
            }
        }
    }

    private var gpsStatus: some View {
        Label(gpsStatusText, systemImage: gpsSymbol)
            .font(.caption2)
            .foregroundStyle(gpsColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
    }

    private var primaryRecordingControl: some View {
        Group {
            switch recorder.phase {
            case .saving:
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Saving walk")
            case .recording:
                Button("Stop", systemImage: "stop.fill") {
                    Task {
                        await recorder.stopAndSave()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
                .accessibilityHint("Stops and saves the current Watch walk.")
            case .ready:
                Button("Start", systemImage: "figure.walk") {
                    Task {
                        await recorder.start(in: modelContext)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.large)
                .disabled(recorder.canStartRecording == false)
                .accessibilityHint("Starts a GPS-only Watch walk.")
            }
        }
    }

    @ViewBuilder
    private var secondaryRecordingControl: some View {
        if recorder.isRecording {
            Button("Discard", role: .destructive) {
                Task {
                    await recorder.discard()
                }
            }
            .font(.caption)
            .accessibilityHint("Deletes the current unsaved Watch walk.")
        }
    }

    private func metric(_ value: String, label: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(label, systemImage: systemImage)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(value)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var statusSymbol: String {
        switch recorder.phase {
        case .ready:
            if isLocationAccessDenied {
                "location.slash.circle.fill"
            } else if recorder.lastCompletedAt != nil {
                "checkmark.circle.fill"
            } else {
                "figure.walk.circle"
            }
        case .recording:
            "figure.walk.circle.fill"
        case .saving:
            "icloud.and.arrow.up.fill"
        }
    }

    private var statusColor: Color {
        switch recorder.phase {
        case .ready:
            if isLocationAccessDenied {
                .orange
            } else if recorder.lastCompletedAt != nil {
                .blue
            } else {
                .secondary
            }
        case .recording:
            .green
        case .saving:
            .blue
        }
    }

    private var gpsStatusText: String {
        switch recorder.authorizationStatus {
        case .notDetermined:
            return "Location permission pending"
        case .denied, .restricted:
            return "Location access unavailable"
        default:
            guard let latestAccuracyMeters = recorder.latestAccuracyMeters else {
                return recorder.isRecording ? "Waiting for GPS fix" : "GPS ready"
            }

            if latestAccuracyMeters > WatchRecordingSession.maximumHorizontalAccuracy {
                return "Poor GPS signal"
            }

            return "GPS signal good"
        }
    }

    private var gpsSymbol: String {
        if isLocationAccessDenied {
            return "location.slash"
        }

        guard recorder.latestAccuracyMeters != nil else {
            return "location"
        }

        return isPoorGPS ? "exclamationmark.triangle.fill" : "location.fill"
    }

    private var gpsColor: Color {
        if isLocationAccessDenied || isPoorGPS {
            return .orange
        }

        return recorder.isRecording ? .green : .secondary
    }

    private var accuracyText: String {
        guard let latestAccuracyMeters = recorder.latestAccuracyMeters else {
            return "--"
        }

        return "\(Int(latestAccuracyMeters.rounded())) m"
    }

    private var isPoorGPS: Bool {
        guard let latestAccuracyMeters = recorder.latestAccuracyMeters else {
            return false
        }

        return latestAccuracyMeters > WatchRecordingSession.maximumHorizontalAccuracy
    }

    private var isLocationAccessDenied: Bool {
        recorder.authorizationStatus == .denied || recorder.authorizationStatus == .restricted
    }
}

private extension TimeInterval {
    var timerText: String {
        let totalSeconds = max(0, Int(self))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%d:%02d", minutes, seconds)
    }
}

private extension Double {
    var distanceText: String {
        if self >= 1_000 {
            return String(format: "%.2f km", self / 1_000)
        }

        return "\(Int(self.rounded())) m"
    }
}
