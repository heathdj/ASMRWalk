//
//  ASMRWalkApp.swift
//  ASMRWalk Watch App
//
//  Created by David Heath on 8/29/26.
//

import SwiftUI
import SwiftData

@main
struct ASMRWalk_Watch_AppApp: App {
    private let modelContainer: ModelContainer

    init() {
        modelContainer = WatchModelContainerFactory.makeModelContainer(
            cloudSyncEnabled: false,
            isStoredInMemoryOnly: Self.isRunningUnitTests
        )
        if Self.isRunningUnitTests == false {
            let connectivity = WatchRouteConnectivity.shared
            connectivity.start()
            let persistence = WatchRecordingPersistence(modelContainer: modelContainer)
            let launchedAt = Date.now
            Task {
                do {
                    // Recover saved walks/checkpoints from previous launches, including
                    // pre-upgrade walks that never reached iCloud. Never queue a live take.
                    let receivedIDs = try WatchTransferFiles.standard.acknowledgedIDs()
                    let routes = try await persistence.routesSaved(before: launchedAt, excluding: receivedIDs)
                    connectivity.recover(routes)
                } catch {
                    connectivity.reportRecoveryError(error.localizedDescription)
                }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
        .backgroundTask(.watchConnectivity) {
            await WatchRouteConnectivity.shared.finishBackgroundDelivery()
        }
    }

    private static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
