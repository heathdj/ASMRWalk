import Foundation
import SwiftData

extension WalkRecordingPersistence {
    func importWatchRoute(_ route: WatchRouteTransfer) throws {
        do {
            try saveWatchRoute(route)
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private func saveWatchRoute(_ route: WatchRouteTransfer) throws {
        try route.validate()
        let id = route.id
        let matches = try modelContext.fetch(FetchDescriptor<WalkRecording>(predicate: #Predicate { $0.id == id }))
        guard matches.allSatisfy({ $0.recordingSource == WalkRecordingSource.appleWatch.rawValue && $0.mode == .walk }) else {
            throw WatchRouteTransfer.TransferError.conflictingRecording
        }
        let recording: WalkRecording
        if let existing = matches.first {
            recording = existing
        } else {
            recording = WalkRecording(id: id, title: route.title, createdAt: route.createdAt,
                duration: route.duration, distanceMeters: route.distanceMeters, mode: .walk,
                recordingSource: .appleWatch, captureDeviceName: route.captureDeviceName,
                routeStartedAt: route.routeStartedAt, routeEndedAt: route.routeEndedAt)
            modelContext.insert(recording)
        }
        // A legacy CloudKit import may contain only a checkpoint. A complete direct
        // transfer repairs its geometry without overwriting titles or timing edits.
        if route.points.count >= recording.points.count {
            for point in recording.points { modelContext.delete(point) }
            recording.points = route.points.map {
                LocationPoint(timestamp: $0.timestamp, latitude: $0.latitude, longitude: $0.longitude,
                    altitude: $0.altitude, horizontalAccuracy: $0.horizontalAccuracy, speed: $0.speed)
            }
            recording.duration = route.duration
            recording.distanceMeters = route.distanceMeters
            recording.routeStartedAt = route.routeStartedAt
            recording.routeEndedAt = route.routeEndedAt
        }
        try modelContext.save()
        try reconcileWatchDuplicates()
    }

    /// Old Watch versions wrote directly to CloudKit. Late arrivals from those
    /// versions can share a logical UUID with a direct import but have different
    /// SwiftData identities. Preserve edited metadata and the fullest route.
    func reconcileWatchDuplicates() throws {
        do {
            try mergeWatchDuplicates()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private func mergeWatchDuplicates() throws {
        let source = WalkRecordingSource.appleWatch.rawValue
        let rows = try modelContext.fetch(FetchDescriptor<WalkRecording>(predicate: #Predicate { $0.recordingSource == source }))
        for group in Dictionary(grouping: rows, by: \.id).values where group.count > 1 {
            let ordered = group.sorted { $0.points.count > $1.points.count }
            guard let keeper = ordered.first else { continue }
            if let title = group.filter(\.isTitleUserEdited).max(by: {
                ($0.titleEditedAt ?? .distantPast) < ($1.titleEditedAt ?? .distantPast)
            }) {
                keeper.title = title.title
                keeper.isTitleUserEdited = true
                keeper.titleEditedAt = title.titleEditedAt
            }
            if let description = group.filter(\.isDescriptionUserEdited).max(by: {
                ($0.descriptionEditedAt ?? .distantPast) < ($1.descriptionEditedAt ?? .distantPast)
            }) {
                keeper.walkDescription = description.walkDescription
                keeper.isDescriptionUserEdited = true
                keeper.descriptionEditedAt = description.descriptionEditedAt
            }
            for duplicate in ordered.dropFirst() {
                if keeper.externalVideoReference == nil { keeper.externalVideoReference = duplicate.externalVideoReference }
                if keeper.externalVideoStartedAt == nil { keeper.externalVideoStartedAt = duplicate.externalVideoStartedAt }
                if keeper.thumbnailURL == nil {
                    keeper.thumbnailURL = duplicate.thumbnailURL
                    keeper.thumbnailStyleVersion = duplicate.thumbnailStyleVersion
                }
                if keeper.generatedPlaceName == nil {
                    keeper.generatedPlaceName = duplicate.generatedPlaceName
                    keeper.metadataGeneratedAt = duplicate.metadataGeneratedAt
                }
                // Do not delete local media files: another row may reference them.
                modelContext.delete(duplicate)
            }
        }
        if modelContext.hasChanges { try modelContext.save() }
    }
}
