//
//  MacModelContainerFactory.swift
//  ASMR Walk Mac Importer
//

import Foundation
import SwiftData

enum MacModelContainerFactory {
    static func makeModelContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([
            WalkRecording.self,
            LocationPoint.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: inMemory ? .none : .private(CloudSyncConfiguration.containerIdentifier)
        )

        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
