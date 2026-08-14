//
//  SampleData.swift
//  ASMR Walk
//

import Foundation
import SwiftData

enum SampleData {
    static var recordings: [WalkRecording] {
        [
            WalkRecording(
                title: "Morning Canal Walk",
                createdAt: Date(timeIntervalSince1970: 1_769_947_200),
                duration: 2_145,
                distanceMeters: 3_420,
                mode: .walk,
                walkDescription: "A calm morning route near the downtown canal.",
                generatedPlaceName: "Downtown Phoenix",
                metadataGeneratedAt: Date(timeIntervalSince1970: 1_769_947_260),
                points: canalRoute
            ),
            WalkRecording(
                title: "Sunset Video Walk",
                createdAt: Date(timeIntervalSince1970: 1_769_886_000),
                duration: 1_320,
                distanceMeters: 1_980,
                mode: .videoWalk,
                walkDescription: "A sunset video walk through the neighborhood.",
                generatedPlaceName: "Phoenix",
                metadataGeneratedAt: Date(timeIntervalSince1970: 1_769_886_060),
                videoURL: URL(filePath: "/sample/sunset-walk.mov"),
                points: sunsetRoute
            )
        ]
    }

    @MainActor
    static let previewContainer: ModelContainer = {
        do {
            return try makePreviewContainer()
        } catch {
            fatalError("Failed to create preview container: \(error)")
        }
    }()

    @MainActor
    static func makePreviewContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: WalkRecording.self,
            LocationPoint.self,
            configurations: configuration
        )

        for recording in recordings {
            container.mainContext.insert(recording)
        }
        try container.mainContext.save()

        return container
    }

    private static var canalRoute: [LocationPoint] {
        [
            LocationPoint(
                timestamp: Date(timeIntervalSince1970: 1_769_947_200),
                latitude: 33.4484,
                longitude: -112.0740,
                altitude: 331,
                horizontalAccuracy: 4.2,
                speed: 1.3
            ),
            LocationPoint(
                timestamp: Date(timeIntervalSince1970: 1_769_947_260),
                latitude: 33.4490,
                longitude: -112.0728,
                altitude: 332,
                horizontalAccuracy: 3.8,
                speed: 1.4
            )
        ]
    }

    private static var sunsetRoute: [LocationPoint] {
        [
            LocationPoint(
                timestamp: Date(timeIntervalSince1970: 1_769_886_000),
                latitude: 33.4562,
                longitude: -112.0667,
                altitude: 337,
                horizontalAccuracy: 5.1,
                speed: 1.1
            ),
            LocationPoint(
                timestamp: Date(timeIntervalSince1970: 1_769_886_060),
                latitude: 33.4570,
                longitude: -112.0659,
                altitude: 338,
                horizontalAccuracy: 4.6,
                speed: 1.2
            )
        ]
    }
}
