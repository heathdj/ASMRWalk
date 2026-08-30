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
        VStack(spacing: 10) {
            statusHeader
            metrics

            if recorder.isRecording {
                Button("Stop", systemImage: "stop.fill") {
                    Task {
                        await recorder.stopAndSave()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

                Button("Discard", role: .destructive) {
                    Task {
                        await recorder.discard()
                    }
                }
                .font(.footnote)
            } else {
                Button("Start Walk", systemImage: "figure.walk") {
                    Task {
                        await recorder.start(in: modelContext)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(recorder.canStartRecording == false)
            }
        }
        .padding()
        .task {
            recorder.refreshAuthorizationStatus()
        }
    }

    private var statusHeader: some View {
        VStack(spacing: 4) {
            Image(systemName: recorder.isRecording ? "figure.walk.circle.fill" : "figure.walk.circle")
                .font(.system(size: 34))
                .foregroundStyle(recorder.isRecording ? .green : .secondary)

            Text(recorder.statusTitle)
                .font(.headline)

            Text(recorder.statusDetail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .accessibilityElement(children: .combine)
    }

    private var metrics: some View {
        HStack(spacing: 12) {
            metric(recorder.currentDuration.timerText, label: "Time")
            metric(recorder.currentDistanceMeters.distanceText, label: "Distance")
            metric("\(recorder.pointCount)", label: "Points")
        }
        .font(.caption2)
    }

    private func metric(_ value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption)
                .monospacedDigit()
            Text(label)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
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
