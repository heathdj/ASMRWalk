//
//  SettingsView.swift
//  ASMR Walk
//

import CloudKit
import SwiftUI

struct SettingsView: View {
    @AppStorage(AppTheme.storageKey) private var selectedThemeRawValue = AppTheme.system.rawValue
    @AppStorage(OnboardingCompletion.storageKey) private var hasCompletedOnboarding = false
    @AppStorage(StartRecordingDestination.storageKey) private var selectedStartDestinationRawValue = StartRecordingDestination.walk.rawValue
    @AppStorage(BackgroundGPSRecording.storageKey) private var isBackgroundGPSRecordingEnabled = BackgroundGPSRecording.defaultValue
    @State private var cloudSyncStatus = CloudSyncStatus()
    @State private var isShowingAbout = false

    private let privacyPolicyURL = URL(string: "https://bald-traveler.com/asmr-walk-privacy-policy/")

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $selectedThemeRawValue) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.title)
                                .tag(theme.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier(AccessibilityID.themePicker)
                }

                Section {
                    LabeledContent {
                        Text(cloudSyncStatus.state.title)
                    } label: {
                        Label("iCloud Library", systemImage: cloudSyncStatus.state.systemImage)
                    }
                    .accessibilityIdentifier(AccessibilityID.cloudSyncStatus)
                } footer: {
                    Text(cloudSyncStatus.state.message)
                }

                Section {
                    Picker("Record button opens", selection: $selectedStartDestinationRawValue) {
                        ForEach(StartRecordingDestination.allCases) { destination in
                            Label(destination.title, systemImage: destination.systemImage)
                                .tag(destination.rawValue)
                        }
                    }
                    .accessibilityIdentifier(AccessibilityID.startRecordingDestinationPicker)

                    Toggle("Background GPS Recording", isOn: $isBackgroundGPSRecordingEnabled)
                        .accessibilityIdentifier(AccessibilityID.backgroundGPSRecordingToggle)
                } header: {
                    Text("Recording")
                } footer: {
                    Text("GPS Walk only. When enabled, GPS-only walks can continue while the app is backgrounded or the screen is locked. Always location permission is required. Video Walks stop when the app leaves the foreground.")
                }

                Section("Guide") {
                    Button("Show Onboarding Again", systemImage: "sparkles") {
                        hasCompletedOnboarding = false
                    }
                    .accessibilityIdentifier(AccessibilityID.showOnboardingButton)
                }

                Section("About") {
                    Button("About ASMR Walk", systemImage: "info.circle") {
                        isShowingAbout = true
                    }
                    .accessibilityIdentifier(AccessibilityID.aboutButton)

                    if let privacyPolicyURL {
                        Link(destination: privacyPolicyURL) {
                            Label("Privacy Policy", systemImage: "hand.raised")
                        }
                        .accessibilityIdentifier(AccessibilityID.privacyPolicyLink)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $isShowingAbout) {
                AboutView(info: .current)
            }
            .task {
                await cloudSyncStatus.refresh()

                for await _ in NotificationCenter.default.notifications(named: .CKAccountChanged) {
                    await cloudSyncStatus.refresh()
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.settingsScreen)
    }
}

struct AboutInfo: Equatable {
    let appName: String
    let version: String
    let build: String
    let contactEmail: String

    static var current: AboutInfo {
        let dictionary = Bundle.main.infoDictionary ?? [:]
        return AboutInfo(
            appName: dictionary["CFBundleDisplayName"] as? String
                ?? dictionary["CFBundleName"] as? String
                ?? "ASMR Walk",
            version: dictionary["CFBundleShortVersionString"] as? String ?? "Unknown",
            build: dictionary["CFBundleVersion"] as? String ?? "Unknown",
            contactEmail: "support@bald-traveler.com"
        )
    }
}

private struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    let info: AboutInfo

    var body: some View {
        NavigationStack {
            List {
                LabeledContent("App Name", value: info.appName)
                LabeledContent("Version", value: info.version)
                LabeledContent("Build", value: info.build)
                LabeledContent("Contact", value: info.contactEmail)
            }
            .navigationTitle("About")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .accessibilityIdentifier(AccessibilityID.aboutSheet)
    }
}

#Preview {
    SettingsView()
}
