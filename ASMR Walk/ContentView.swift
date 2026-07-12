//
//  ContentView.swift
//  ASMR Walk
//
//  Created by David Heath on 5/24/26.
//

import SwiftUI
import SwiftData

enum AppTab: CaseIterable, Hashable {
    case history
    case walk
    case videoWalk
    case settings

    var title: String {
        switch self {
        case .history:
            "History"
        case .walk:
            "Walk"
        case .videoWalk:
            "Video Walk"
        case .settings:
            "Settings"
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
        case .settings:
            "gearshape.fill"
        }
    }
}

enum AccessibilityID {
    static let onboardingScreen = "onboarding.screen"
    static let onboardingPrimaryButton = "onboarding.primaryButton"
    static let onboardingSkipButton = "onboarding.skipButton"
    static let historyEmptyState = "history.emptyState"
    static let historyList = "history.list"
    static let recordingDetail = "history.recordingDetail"
    static let exportRecordingButton = "history.exportRecordingButton"
    static let videoPlayback = "history.videoPlayback"
    static let videoRouteOverlay = "history.videoRouteOverlay"
    static let openSettingsButton = "permissions.openSettings"
    static let walkStatus = "walk.status"
    static let walkMetrics = "walk.metrics"
    static let startWalkButton = "walk.startButton"
    static let videoStatus = "videoWalk.status"
    static let videoMetrics = "videoWalk.metrics"
    static let startVideoWalkButton = "videoWalk.startButton"
    static let videoWalkScreen = "videoWalk.screen"
    static let videoRecordingIndicator = "videoWalk.recordingIndicator"
    static let settingsScreen = "settings.screen"
    static let themePicker = "settings.themePicker"
    static let startRecordingDestinationPicker = "settings.startRecordingDestinationPicker"
    static let backgroundGPSRecordingToggle = "settings.backgroundGPSRecordingToggle"
    static let showOnboardingButton = "settings.showOnboardingButton"
    static let aboutButton = "settings.aboutButton"
    static let aboutSheet = "settings.aboutSheet"
}

struct ContentView: View {
    @AppStorage(AppTheme.storageKey) private var appThemeRawValue = AppTheme.system.rawValue
    @AppStorage(OnboardingCompletion.storageKey) private var hasCompletedOnboarding = false
    @AppStorage(StartRecordingDestination.storageKey) private var startRecordingDestinationRawValue = StartRecordingDestination.walk.rawValue
    @State private var selectedTab: AppTab = .history

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                TabView(selection: $selectedTab) {
                    Tab(AppTab.history.title, systemImage: AppTab.history.systemImage, value: AppTab.history) {
                        HistoryView {
                            selectedTab = selectedStartRecordingDestination.tab
                        }
                    }

                    Tab(AppTab.walk.title, systemImage: AppTab.walk.systemImage, value: AppTab.walk) {
                        WalkRecorderView()
                    }

                    Tab(AppTab.videoWalk.title, systemImage: AppTab.videoWalk.systemImage, value: AppTab.videoWalk) {
                        VideoWalkView()
                    }

                    Tab(AppTab.settings.title, systemImage: AppTab.settings.systemImage, value: AppTab.settings) {
                        SettingsView()
                    }
                }
            } else {
                OnboardingView()
            }
        }
        .tint(.green)
        .preferredColorScheme(selectedTheme.colorScheme)
    }

    private var selectedTheme: AppTheme {
        AppTheme(rawValue: appThemeRawValue) ?? .system
    }

    private var selectedStartRecordingDestination: StartRecordingDestination {
        StartRecordingDestination(rawValue: startRecordingDestinationRawValue) ?? .walk
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
