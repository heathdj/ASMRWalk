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
            cloudSyncEnabled: Self.isRunningUnitTests == false,
            isStoredInMemoryOnly: Self.isRunningUnitTests
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }

    private static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
