//
//  ASMR_WalkApp.swift
//  ASMR Walk
//
//  Created by David Heath on 5/24/26.
//

import SwiftUI
import SwiftData

@main
struct ASMR_WalkApp: App {
    @UIApplicationDelegateAdaptor(AppOrientationDelegate.self) private var appOrientationDelegate

    init() {
        UITestLaunchConfiguration.apply()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [WalkRecording.self, LocationPoint.self])
    }
}

private enum UITestLaunchConfiguration {
    static func apply() {
        #if DEBUG
        switch ProcessInfo.processInfo.environment["ASMR_WALK_UI_TEST_ONBOARDING"] {
        case "completed":
            UserDefaults.standard.set(true, forKey: OnboardingCompletion.storageKey)
        case "firstLaunch":
            UserDefaults.standard.removeObject(forKey: OnboardingCompletion.storageKey)
        default:
            break
        }

        if let startDestination = ProcessInfo.processInfo.environment["ASMR_WALK_UI_TEST_START_DESTINATION"],
           StartRecordingDestination(rawValue: startDestination) != nil {
            UserDefaults.standard.set(startDestination, forKey: StartRecordingDestination.storageKey)
        }
        #endif
    }
}
