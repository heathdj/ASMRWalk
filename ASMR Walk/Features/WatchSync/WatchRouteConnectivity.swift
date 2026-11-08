import Foundation
import Observation
import WatchConnectivity

@MainActor
@Observable
final class WatchRouteConnectivity: NSObject {
    static let shared = WatchRouteConnectivity()
    #if os(watchOS)
    private(set) var status = "Open ASMR Walk on your paired iPhone to receive saved walks."
    #else
    private(set) var status = "Ready to receive saved walks from your paired Apple Watch."
    #endif
    private(set) var pendingCount = 0
    nonisolated private let files: WatchTransferFiles
    private var session: WCSession?
    private var importRoute: (@Sendable (WatchRouteTransfer) async throws -> Void)?
    private var isProcessingInbox = false
    private var inboxNeedsProcessing = false

    init(files: WatchTransferFiles = .standard) {
        self.files = files
        super.init()
    }

    func start(importRoute: (@Sendable (WatchRouteTransfer) async throws -> Void)? = nil) {
        self.importRoute = importRoute
        guard WCSession.isSupported() else {
            status = "Watch transfers are unavailable on this device."
            return
        }
        let session = WCSession.default
        self.session = session
        session.delegate = self
        session.activate()
    }

    func reportRecoveryError(_ message: String) {
        status = "Saved locally, but transfer preparation failed: \(message). Reopen the Watch app to retry."
    }

    func recover(_ routes: [WatchRouteTransfer]) {
        var failure: String?
        for route in routes {
            do { try files.enqueue(route) }
            catch { failure = error.localizedDescription }
        }
        resume()
        if let failure { reportRecoveryError(failure) }
    }

    func enqueue(_ route: WatchRouteTransfer) throws {
        try files.enqueue(route)
        resume()
    }

    func resume() {
        guard let session, session.activationState == .activated else { return }
        #if os(watchOS)
        do {
            let pending = try files.files(in: "Outbox")
            pendingCount = pending.count
            guard session.isCompanionAppInstalled else {
                status = "Install and open ASMR Walk on your paired iPhone. Saved walks remain on this Watch."
                return
            }
            let outstanding = Set(session.outstandingFileTransfers.compactMap {
                $0.file.metadata?["watchRecordingID"] as? String
            })
            for url in pending {
                guard let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent) else { continue }
                if files.receiptExists(id) {
                    try files.acknowledge(id)
                } else if outstanding.contains(id.uuidString) == false {
                    session.transferFile(url, metadata: ["watchRecordingID": id.uuidString])
                }
            }
            pendingCount = try files.files(in: "Outbox").count
            if pendingCount == 0, (try? files.acknowledgedIDs().isEmpty) == false {
                status = "Saved walks received by iPhone."
            } else if pendingCount > 0 {
                status = "\(pendingCount) saved walk(s) waiting for iPhone confirmation. Transfers may take time."
            }
        } catch {
            status = "Unable to queue Watch walks: \(error.localizedDescription)"
        }
        #else
        inboxNeedsProcessing = true
        Task { await processInbox() }
        #endif
    }

    func finishBackgroundDelivery() async {
        // SwiftUI completes the watchOS background task when this returns. Wait
        // for queued delegate deliveries; cancellation respects the system budget.
        while Task.isCancelled == false {
            guard let session else { return }
            if session.activationState != .notActivated && session.hasContentPending == false { return }
            do { try await Task.sleep(for: .milliseconds(100)) }
            catch { return }
        }
    }

    private func processInbox() async {
        guard isProcessingInbox == false, let importRoute,
              let session, session.activationState == .activated else { return }
        isProcessingInbox = true
        defer { isProcessingInbox = false }
        do {
            var attempted = Set<URL>()
            repeat {
                inboxNeedsProcessing = false
                for url in try files.files(in: "Inbox") where attempted.insert(url).inserted {
                    do {
                        let id = try await WatchRouteDelivery.importFile(url, files: files, importRoute: importRoute)
                        guard session.activationState == .activated else { return }
                        // Delivery is acknowledged only after a successful durable save.
                        // Replays get another acknowledgment without undoing edits/deletions.
                        session.transferUserInfo(["savedWatchRecordingID": id.uuidString])
                        try FileManager.default.removeItem(at: url)
                        status = "Watch walk received. iCloud sync to other devices may take time."
                    } catch {
                        status = "Unable to import Watch walk: \(error.localizedDescription). It remains queued for retry."
                    }
                }
            } while inboxNeedsProcessing
        } catch {
            status = "Unable to read incoming Watch walks: \(error.localizedDescription)"
        }
    }

    private func receivedAcknowledgment(_ id: UUID) {
        do {
            try files.acknowledge(id)
            pendingCount = try files.files(in: "Outbox").count
            status = pendingCount == 0 ? "Saved walks received by iPhone." : "\(pendingCount) walk(s) still waiting for iPhone."
        } catch {
            status = "Unable to store iPhone confirmation: \(error.localizedDescription)"
        }
    }
}

extension WatchRouteConnectivity: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        let message = error?.localizedDescription
        Task { @MainActor in
            if let message { status = "Watch connection unavailable: \(message)" }
            else { resume() }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in resume() }
    }

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        // WatchConnectivity deletes this URL when the delegate returns. Move it now,
        // before hopping to an actor or starting asynchronous persistence work.
        guard file.metadata?["watchRecordingID"] is String else { return }
        do {
            _ = try files.receive(file.fileURL)
            Task { @MainActor in resume() }
        } catch {
            let message = error.localizedDescription
            Task { @MainActor in status = "Unable to retain incoming Watch walk: \(message)" }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let value = userInfo["savedWatchRecordingID"] as? String,
              let id = UUID(uuidString: value) else { return }
        do {
            // The receipt is the durable acknowledgment. Outbox cleanup stays on
            // the main actor so it cannot race an outgoing enqueue operation.
            try files.recordReceipt(id)
            Task { @MainActor in receivedAcknowledgment(id) }
        } catch {
            let message = error.localizedDescription
            Task { @MainActor in status = "Unable to retain iPhone confirmation: \(message)" }
        }
    }

    nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: (any Error)?) {
        guard let message = error?.localizedDescription else { return }
        if let value = fileTransfer.file.metadata?["watchRecordingID"] as? String,
           let id = UUID(uuidString: value), files.receiptExists(id) { return }
        Task { @MainActor in
            status = "Transfer paused: \(message). Saved walks remain on this Watch; tap Retry Transfer."
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
