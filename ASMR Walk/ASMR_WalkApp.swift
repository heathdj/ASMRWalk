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
    private let modelContainer: ModelContainer

    init() {
        UITestLaunchConfiguration.apply()
        modelContainer = Self.makeModelContainer()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }

    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([WalkRecording.self, LocationPoint.self])
        #if DEBUG
        if UITestLaunchConfiguration.usesInMemoryModelContainer {
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )

            do {
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                fatalError("Unable to create UI test model container: \(error.localizedDescription)")
            }
        }
        #endif

        let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Unable to create ASMR Walk model container: \(error.localizedDescription)")
        }
    }
}

private enum UITestLaunchConfiguration {
    static var usesInMemoryModelContainer: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["ASMR_WALK_UI_TEST_IN_MEMORY_STORE"] == "1"
        #else
        false
        #endif
    }

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
