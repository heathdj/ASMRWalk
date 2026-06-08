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

private struct HistoryView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("No Walks Yet", systemImage: "map")
            } description: {
                Text("Your recorded routes, stats, and videos will appear here.")
            } actions: {
                Button("Record a Walk", systemImage: "figure.walk") {
                    // Tab selection will be wired up with the recording flow.
                }
                .buttonStyle(.borderedProminent)
            }
            .accessibilityIdentifier(AccessibilityID.historyEmptyState)
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("More", systemImage: "ellipsis") {
                        // History actions will be added with export support.
                    }
                    .disabled(true)
                }
            }
        }
    }
}

private struct WalkRecorderView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                RouteBackground()

                VStack(spacing: 16) {
                    RecordingStatusCard(
                        title: "Ready to walk",
                        detail: "Your route will stay on this device.",
                        systemImage: "location.fill"
                    )
                    .accessibilityIdentifier(AccessibilityID.walkStatus)

                    Spacer()

                    RecordingMetrics()
                        .accessibilityIdentifier(AccessibilityID.walkMetrics)

                    Button("Start Walk", systemImage: "figure.walk") {
                        // GPS recording will be added in the recorder phase.
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .controlSize(.large)
                    .buttonStyle(.glassProminent)
                    .accessibilityIdentifier(AccessibilityID.startWalkButton)
                }
                .padding()
            }
            .navigationTitle("Walk")
            .navigationBarTitleDisplayMode(.inline)
        }
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

                    RecordingMetrics()
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

private struct RecordingStatusCard: View {
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

private struct RecordingMetrics: View {
    var body: some View {
        HStack(spacing: 12) {
            MetricView(value: "0:00", label: "TIME")
            MetricView(value: "0.00", label: "MILES")
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Elapsed time 0 minutes. Distance 0 miles.")
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

private struct RouteBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.80, green: 0.90, blue: 0.82),
                    Color(red: 0.93, green: 0.90, blue: 0.77)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Path { path in
                path.move(to: CGPoint(x: 40, y: 640))
                path.addCurve(
                    to: CGPoint(x: 350, y: 120),
                    control1: CGPoint(x: 250, y: 560),
                    control2: CGPoint(x: 100, y: 250)
                )
            }
            .stroke(.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
            .shadow(color: .white.opacity(0.8), radius: 0, x: 0, y: 0)

            Image(systemName: "location.fill")
                .font(.title)
                .foregroundStyle(.green)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

#Preview {
    ContentView()
        .modelContainer(SampleData.previewContainer)
}
