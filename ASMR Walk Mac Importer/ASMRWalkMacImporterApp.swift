//
//  ASMRWalkMacImporterApp.swift
//  ASMR Walk Mac Importer
//

import SwiftUI
import SwiftData

@main
struct ASMRWalkMacImporterApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try MacModelContainerFactory.makeModelContainer()
        } catch {
            fatalError("Failed to create ASMR Walk Mac Importer model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MacImporterView()
                .modelContainer(modelContainer)
        }
        .windowResizability(.contentSize)
    }
}
