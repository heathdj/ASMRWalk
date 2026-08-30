//
//  CloudSyncStatus.swift
//  ASMR Walk Mac Importer
//

import CloudKit
import Foundation
import Observation

enum CloudSyncConfiguration {
    static let containerIdentifier = "iCloud.com.bald-traveler.ASMRWalk"
}

enum CloudSyncAccountState: Equatable {
    case checking
    case available
    case noAccount
    case restricted
    case temporarilyUnavailable
    case couldNotDetermine

    init(accountStatus: CKAccountStatus) {
        switch accountStatus {
        case .available:
            self = .available
        case .noAccount:
            self = .noAccount
        case .restricted:
            self = .restricted
        case .temporarilyUnavailable:
            self = .temporarilyUnavailable
        case .couldNotDetermine:
            self = .couldNotDetermine
        @unknown default:
            self = .couldNotDetermine
        }
    }

    var title: String {
        switch self {
        case .checking:
            "Checking iCloud"
        case .available:
            "iCloud Library Available"
        case .noAccount:
            "iCloud Sign-In Needed"
        case .restricted:
            "iCloud Sync Restricted"
        case .temporarilyUnavailable:
            "iCloud Temporarily Unavailable"
        case .couldNotDetermine:
            "iCloud Status Unknown"
        }
    }

    var message: String {
        switch self {
        case .checking:
            "Checking whether this Mac can read synced ASMR Walk recordings."
        case .available:
            "Synced recordings from iPhone and Apple Watch can appear here after iCloud finishes syncing."
        case .noAccount:
            "Sign in to iCloud on this Mac to load synced ASMR Walk recordings. GPX import remains available."
        case .restricted:
            "This iCloud account is restricted, so synced recordings cannot load here. GPX import remains available."
        case .temporarilyUnavailable:
            "iCloud is temporarily unavailable. Try again later, or use GPX import."
        case .couldNotDetermine:
            "The Mac could not determine iCloud availability. Check iCloud settings, or use GPX import."
        }
    }
}

protocol CloudSyncAccountStatusProviding {
    func accountStatus() async -> CloudSyncAccountState
}

struct CloudKitAccountStatusProvider: CloudSyncAccountStatusProviding {
    nonisolated init() {}

    func accountStatus() async -> CloudSyncAccountState {
        await withCheckedContinuation { continuation in
            CKContainer(identifier: CloudSyncConfiguration.containerIdentifier).accountStatus { status, error in
                if error != nil {
                    continuation.resume(returning: .couldNotDetermine)
                } else {
                    continuation.resume(returning: CloudSyncAccountState(accountStatus: status))
                }
            }
        }
    }
}

@MainActor
@Observable
final class CloudSyncStatus {
    private(set) var accountState = CloudSyncAccountState.checking

    private let provider: any CloudSyncAccountStatusProviding

    init(provider: any CloudSyncAccountStatusProviding = CloudKitAccountStatusProvider()) {
        self.provider = provider
    }

    func refresh() async {
        accountState = .checking
        accountState = await provider.accountStatus()
    }
}
