import Foundation
import SwiftData
import Testing
@testable import ASMR_Walk

@MainActor
struct WatchRouteTransferTests {
    @Test("Long routes round trip through the durable transfer queue")
    func durableQueue() throws {
        let files = temporaryFiles()
        defer { try? FileManager.default.removeItem(at: files.root) }
        let route = makeRoute(pointCount: 2_501)
        try files.enqueue(route)
        try files.enqueue(route)
        let restarted = WatchTransferFiles(root: files.root)
        let pending = try restarted.files(in: "Outbox")
        #expect(pending.count == 1)
        #expect(try restarted.decode(#require(pending.first)) == route)
        try restarted.acknowledge(route.id)
        try restarted.enqueue(route)
        #expect(try restarted.files(in: "Outbox").isEmpty)
        #expect(restarted.receiptExists(route.id))
    }

    @Test("A received file is retained before the transport removes its temporary URL")
    func receiveRetainsFile() throws {
        let files = temporaryFiles()
        defer { try? FileManager.default.removeItem(at: files.root) }
        try files.enqueue(makeRoute())
        let original = try #require(files.files(in: "Outbox").first)
        let inbox = try files.receive(original)
        #expect(FileManager.default.fileExists(atPath: original.path) == false)
        #expect(try files.decode(inbox).points.count == 3)
    }

    @Test("Failed imports remain queued and unacknowledged until a successful retry")
    func failureRetainsRoute() async throws {
        let files = temporaryFiles()
        defer { try? FileManager.default.removeItem(at: files.root) }
        let route = makeRoute()
        try files.enqueue(route)
        let inbox = try files.receive(#require(files.files(in: "Outbox").first))
        do {
            _ = try await WatchRouteDelivery.importFile(inbox, files: files) { _ in
                throw CocoaError(.fileWriteOutOfSpace)
            }
            Issue.record("Expected the injected save failure")
        } catch {}
        #expect(files.receiptExists(route.id) == false)
        #expect(FileManager.default.fileExists(atPath: inbox.path))
        let persistence = WalkRecordingPersistence(modelContainer: try makeContainer())
        let id = try await WatchRouteDelivery.importFile(inbox, files: files) { try await persistence.importWatchRoute($0) }
        #expect(id == route.id)
        #expect(files.receiptExists(route.id))
    }

    @Test("Replay does not undo an iPhone deletion after acknowledgment")
    func replayAfterDeletion() async throws {
        let container = try makeContainer()
        let persistence = WalkRecordingPersistence(modelContainer: container)
        let files = temporaryFiles()
        defer { try? FileManager.default.removeItem(at: files.root) }
        let route = makeRoute()
        try files.enqueue(route)
        let inbox = try files.receive(#require(files.files(in: "Outbox").first))
        _ = try await WatchRouteDelivery.importFile(inbox, files: files) { try await persistence.importWatchRoute($0) }
        try await persistence.deleteRecording(id: route.id)
        let restarted = WatchTransferFiles(root: files.root)
        _ = try await WatchRouteDelivery.importFile(inbox, files: restarted) { try await persistence.importWatchRoute($0) }
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<WalkRecording>()) == 0)
    }

    @Test("Import preserves UUID, Watch source, repeated timestamps and route values")
    func importsCompleteRoute() async throws {
        let container = try makeContainer()
        let persistence = WalkRecordingPersistence(modelContainer: container)
        let route = makeRoute(pointCount: 250)
        try await persistence.importWatchRoute(route)
        try await persistence.importWatchRoute(route)
        let context = ModelContext(container)
        let rows = try context.fetch(FetchDescriptor<WalkRecording>())
        let saved = try #require(rows.first)
        #expect(rows.count == 1)
        #expect(saved.id == route.id)
        #expect(saved.recordingSource == "appleWatch")
        #expect(saved.videoURL == nil)
        #expect(saved.duration == route.duration)
        #expect(saved.distanceMeters == route.distanceMeters)
        #expect(saved.points.count == route.points.count)
        #expect(try context.fetchCount(FetchDescriptor<LocationPoint>()) == route.points.count)
        #expect(saved.points.filter { $0.timestamp == route.points[0].timestamp }.count == 2)
    }

    @Test("A completed Watch transfer repairs a legacy checkpoint without losing user edits")
    func repairsCheckpoint() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let route = makeRoute()
        let recording = WalkRecording(id: route.id, title: "My edited title", mode: .walk,
            walkDescription: "My notes", isTitleUserEdited: true, isDescriptionUserEdited: true,
            recordingSource: .appleWatch, externalVideoReference: "camera.mov",
            externalVideoStartedAt: Date(timeIntervalSince1970: 1_005))
        context.insert(recording)
        try context.save()
        try await WalkRecordingPersistence(modelContainer: container).importWatchRoute(route)
        let saved = try #require(ModelContext(container).fetch(FetchDescriptor<WalkRecording>()).first)
        #expect(saved.points.count == 3)
        #expect(saved.title == "My edited title")
        #expect(saved.walkDescription == "My notes")
        #expect(saved.externalVideoReference == "camera.mov")
        #expect(saved.externalVideoStartedAt == Date(timeIntervalSince1970: 1_005))
    }

    @Test("Late legacy CloudKit duplicates keep the fullest route and edited metadata")
    func reconcilesLegacyDuplicates() async throws {
        let container = try makeContainer()
        let persistence = WalkRecordingPersistence(modelContainer: container)
        let route = makeRoute()
        try await persistence.importWatchRoute(route)
        let context = ModelContext(container)
        let duplicate = WalkRecording(id: route.id, title: "Edited in iCloud", mode: .walk,
            walkDescription: "Retained notes", isTitleUserEdited: true, isDescriptionUserEdited: true,
            titleEditedAt: .now, descriptionEditedAt: .now, recordingSource: .appleWatch,
            externalVideoReference: "external.mov")
        context.insert(duplicate)
        try context.save()
        try await persistence.reconcileWatchDuplicates()
        let rows = try ModelContext(container).fetch(FetchDescriptor<WalkRecording>())
        let saved = try #require(rows.first)
        #expect(rows.count == 1)
        #expect(saved.points.count == 3)
        #expect(saved.title == "Edited in iCloud")
        #expect(saved.walkDescription == "Retained notes")
        #expect(saved.externalVideoReference == "external.mov")
    }

    @Test("Watch transfer cannot replace an iPhone recording with a colliding UUID")
    func rejectsIdentityConflict() async throws {
        let container = try makeContainer()
        let route = makeRoute()
        container.mainContext.insert(WalkRecording(id: route.id, title: "iPhone", mode: .walk))
        try container.mainContext.save()
        let persistence = WalkRecordingPersistence(modelContainer: container)
        await #expect(throws: WatchRouteTransfer.TransferError.self) {
            try await persistence.importWatchRoute(route)
        }
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<LocationPoint>()) == 0)
    }

    @Test("Unsupported transfer versions are not saved or acknowledged")
    func rejectsInvalidVersion() async throws {
        let files = temporaryFiles()
        defer { try? FileManager.default.removeItem(at: files.root) }
        var route = makeRoute()
        route.version = 99
        let inbox = try files.directory("Inbox").appending(path: "invalid.json")
        try JSONEncoder().encode(route).write(to: inbox)
        let persistence = WalkRecordingPersistence(modelContainer: try makeContainer())
        await #expect(throws: WatchRouteTransfer.TransferError.self) {
            _ = try await WatchRouteDelivery.importFile(inbox, files: files) { try await persistence.importWatchRoute($0) }
        }
        #expect(files.receiptExists(route.id) == false)
    }

    private func temporaryFiles() -> WatchTransferFiles {
        WatchTransferFiles(root: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString))
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([WalkRecording.self, LocationPoint.self])
        return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
    }

    private func makeRoute(pointCount: Int = 3) -> WatchRouteTransfer {
        WatchRouteTransfer(id: UUID(), title: "Watch walk", createdAt: Date(timeIntervalSince1970: 1_000),
            duration: 3_000, distanceMeters: 200, captureDeviceName: "Apple Watch",
            routeStartedAt: Date(timeIntervalSince1970: 1_000), routeEndedAt: Date(timeIntervalSince1970: 4_000),
            points: (0..<pointCount).map {
                .init(timestamp: Date(timeIntervalSince1970: 1_000 + Double($0 / 2)),
                    latitude: 35 + Double($0) * 0.00001, longitude: -86,
                    altitude: 100, horizontalAccuracy: 5, speed: 1)
            })
    }
}
