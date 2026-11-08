//
//  ASMR_WalkApp.swift
//  ASMR Walk
//
//  Created by David Heath on 5/24/26.
//

import SwiftUI
import SwiftData
import CoreData

@main
struct ASMR_WalkApp: App {
    @UIApplicationDelegateAdaptor(AppOrientationDelegate.self) private var appOrientationDelegate
    @Environment(\.scenePhase) private var scenePhase
    private let modelContainer: ModelContainer
    private let watchPersistence: WalkRecordingPersistence

    init() {
        UITestLaunchConfiguration.apply()
        modelContainer = Self.makeModelContainer()
        let persistence = WalkRecordingPersistence(modelContainer: modelContainer)
        watchPersistence = persistence
        if UITestLaunchConfiguration.usesInMemoryModelContainer == false {
            WatchRouteConnectivity.shared.start { route in
                try await persistence.importWatchRoute(route)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    guard UITestLaunchConfiguration.usesInMemoryModelContainer == false else { return }
                    WatchRouteConnectivity.shared.resume()
                    let persistence = watchPersistence
                    try? await persistence.reconcileWatchDuplicates()
                    // SwiftData exposes no CloudKit-import completion stream. This
                    // notification repairs late legacy Watch arrivals after import.
                    for await _ in NotificationCenter.default.notifications(named: NSPersistentCloudKitContainer.eventChangedNotification) {
                        try? await persistence.reconcileWatchDuplicates()
                        WatchRouteConnectivity.shared.resume()
                    }
                }
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, UITestLaunchConfiguration.usesInMemoryModelContainer == false {
                WatchRouteConnectivity.shared.resume()
            }
        }
    }

    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([WalkRecording.self, LocationPoint.self])

        #if DEBUG
        if UITestLaunchConfiguration.usesInMemoryModelContainer {
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )

            do {
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                fatalError("Unable to create UI test model container: \(error.localizedDescription)")
            }
        }
        #endif

        let configuration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private(CloudSyncConfiguration.containerIdentifier)
        )

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
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
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
