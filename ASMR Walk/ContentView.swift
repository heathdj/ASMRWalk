//
//  ContentView.swift
//  ASMR Walk
//
//  Created by David Heath on 5/24/26.
//

import SwiftUI
import SwiftData

enum AppTab: CaseIterable {
    case history
    case walk
    case videoWalk

    var title: String {
        switch self {
        case .history:
            "History"
        case .walk:
            "Walk"
        case .videoWalk:
            "Video Walk"
        }
    }

    var systemImage: String {
        switch self {
        case .history:
            "clock.arrow.circlepath"
        case .walk:
            "figure.walk"
        case .videoWalk:
            "video.fill"
        }
    }
}

enum AccessibilityID {
    static let historyEmptyState = "history.emptyState"
    static let historyList = "history.list"
    static let recordingDetail = "history.recordingDetail"
    static let exportRecordingButton = "history.exportRecordingButton"
    static let walkStatus = "walk.status"
    static let walkMetrics = "walk.metrics"
    static let startWalkButton = "walk.startButton"
    static let videoStatus = "videoWalk.status"
    static let videoMetrics = "videoWalk.metrics"
    static let startVideoWalkButton = "videoWalk.startButton"
}

struct ContentView: View {
    var body: some View {
        TabView {
            Tab(AppTab.history.title, systemImage: AppTab.history.systemImage) {
                HistoryView()
            }

            Tab(AppTab.walk.title, systemImage: AppTab.walk.systemImage) {
                WalkRecorderView()
            }

            Tab(AppTab.videoWalk.title, systemImage: AppTab.videoWalk.systemImage) {
                VideoWalkView()
            }
        }
        .tint(.green)
    }
}

private struct VideoWalkView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [.black, .gray.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 16) {
                    RecordingStatusCard(
                        title: "Camera ready",
                        detail: "Video and route recording start together.",
                        systemImage: "video.fill"
                    )
                    .accessibilityIdentifier(AccessibilityID.videoStatus)

                    Spacer()

                    Label("Camera preview will appear here", systemImage: "camera.aperture")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.8))

                    Spacer()

                    RecordingMetrics(duration: 0, distanceMeters: 0)
                        .accessibilityIdentifier(AccessibilityID.videoMetrics)

                    Button("Start Video Walk", systemImage: "record.circle") {
                        // Camera and GPS recording will be added in the video phase.
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .controlSize(.large)
                    .buttonStyle(.glassProminent)
                    .tint(.red)
                    .accessibilityIdentifier(AccessibilityID.startVideoWalkButton)
                }
                .padding()
            }
            .navigationTitle("Video Walk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

struct RecordingStatusCard: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.green)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }
}

struct RecordingMetrics: View {
    let duration: TimeInterval
    let distanceMeters: Double

    var body: some View {
        HStack(spacing: 12) {
            MetricView(value: duration.timerText, label: "TIME")
            MetricView(value: distanceMeters.distanceText, label: "DISTANCE")
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Elapsed time \(duration.timerText). Distance \(distanceMeters.distanceText).")
    }
}

private struct MetricView: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title, design: .rounded, weight: .semibold))
                .monospacedDigit()

            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ContentView()
        .modelContainer(SampleData.previewContainer)
}
