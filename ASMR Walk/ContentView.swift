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
    static let startWalkButton = "walk.startButton"
    static let activeRecordingBanner = "recording.activeBanner"
    static let activeRecordingReturnButton = "recording.returnButton"
    static let activeRecordingStopButton = "recording.stopButton"
    static let videoStatus = "videoWalk.status"
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
    @State private var recordingCoordinator: RecordingCoordinator
    @State private var isShowingShortRecordingConfirmation = false
    @State private var videoWalkStopRequestID: UUID?

    init(recordingCoordinator: RecordingCoordinator? = nil) {
        _recordingCoordinator = State(initialValue: recordingCoordinator ?? RecordingCoordinator(activeMode: Self.launchActiveRecordingMode))
    }

    var body: some View {
        Group {
            if hasCompletedOnboarding || Self.shouldSkipOnboardingForUITests {
                TabView(selection: $selectedTab) {
                    Tab(AppTab.history.title, systemImage: AppTab.history.systemImage, value: AppTab.history) {
                        HistoryView {
                            selectedTab = recordingCoordinator.activeTab ?? selectedStartRecordingDestination.tab
                        }
                    }

                    Tab(AppTab.walk.title, systemImage: AppTab.walk.systemImage, value: AppTab.walk) {
                        WalkRecorderView(coordinator: recordingCoordinator, showActiveRecording: showActiveRecording)
                    }

                    Tab(AppTab.videoWalk.title, systemImage: AppTab.videoWalk.systemImage, value: AppTab.videoWalk) {
                        VideoWalkView(
                            coordinator: recordingCoordinator,
                            stopRequestID: videoWalkStopRequestID,
                            showActiveRecording: showActiveRecording
                        )
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
        .safeAreaInset(edge: .bottom) {
            if recordingCoordinator.hasActiveRecording {
                ActiveRecordingBanner(
                    mode: recordingCoordinator.activeMode,
                    duration: recordingCoordinator.recorder.currentDuration,
                    distanceMeters: recordingCoordinator.recorder.currentDistanceMeters,
                    returnAction: showActiveRecording,
                    stopAction: stopActiveRecording
                )
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .confirmationDialog("Save Short Walk?", isPresented: $isShowingShortRecordingConfirmation) {
            Button("Save Walk") {
                Task {
                    await recordingCoordinator.saveFinishedRecording()
                }
            }
            Button("Discard Walk", role: .destructive) {
                Task {
                    await recordingCoordinator.discard()
                }
            }
        } message: {
            Text("This walk is shorter than 10 seconds.")
        }
    }

    private var selectedTheme: AppTheme {
        AppTheme(rawValue: appThemeRawValue) ?? .system
    }

    private var selectedStartRecordingDestination: StartRecordingDestination {
        StartRecordingDestination(rawValue: startRecordingDestinationRawValue) ?? .walk
    }

    private func showActiveRecording() {
        if let activeTab = recordingCoordinator.activeTab {
            selectedTab = activeTab
        }
    }

    private func stopActiveRecording() {
        switch recordingCoordinator.activeMode {
        case .walk:
            if recordingCoordinator.recorder.isShortRecording {
                recordingCoordinator.finishRecording()
                isShowingShortRecordingConfirmation = true
            } else {
                Task {
                    await recordingCoordinator.stopAndSave()
                }
            }
        case .videoWalk:
            selectedTab = .videoWalk
            videoWalkStopRequestID = UUID()
        case nil:
            break
        }
    }

    private static var launchActiveRecordingMode: RecordingMode? {
        #if DEBUG
        switch ProcessInfo.processInfo.environment["ASMR_WALK_UI_TEST_ACTIVE_RECORDING_MODE"] {
        case RecordingMode.walk.rawValue:
            return .walk
        case RecordingMode.videoWalk.rawValue:
            return .videoWalk
        default:
            return nil
        }
        #else
        return nil
        #endif
    }

    private static var shouldSkipOnboardingForUITests: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["ASMR_WALK_UI_TEST_SKIP_ONBOARDING"] == "1"
        #else
        false
        #endif
    }
}

private struct ActiveRecordingBanner: View {
    let mode: RecordingMode?
    let duration: TimeInterval
    let distanceMeters: Double
    let returnAction: () -> Void
    let stopAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: returnAction) {
                HStack(spacing: 12) {
                    Image(systemName: systemImage)
                        .font(.headline)
                        .foregroundStyle(.green)
                        .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text("\(duration.timerText) - \(distanceMeters.distanceText)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityID.activeRecordingReturnButton)

            Button(stopTitle, systemImage: "stop.fill", action: stopAction)
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.glassProminent)
                .tint(.red)
                .accessibilityIdentifier(AccessibilityID.activeRecordingStopButton)
        }
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.activeRecordingBanner)
    }

    private var title: String {
        switch mode {
        case .walk:
            return "Recording GPS walk"
        case .videoWalk:
            return "Recording video walk"
        case nil:
            return "Recording active"
        }
    }

    private var stopTitle: String {
        switch mode {
        case .videoWalk:
            return "Stop Video"
        default:
            return "Stop"
        }
    }

    private var systemImage: String {
        switch mode {
        case .walk:
            return "figure.walk"
        case .videoWalk:
            return "video.fill"
        case nil:
            return "record.circle"
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

#Preview {
    ContentView()
        .modelContainer(SampleData.previewContainer)
}
