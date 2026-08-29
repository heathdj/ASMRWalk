//
//  CloudSyncStatus.swift
//  ASMR Walk
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
    case failed(String)

    var title: String {
        switch self {
        case .checking:
            "Checking iCloud"
        case .available:
            "iCloud Available"
        case .noAccount:
            "Sign In Required"
        case .restricted:
            "iCloud Restricted"
        case .temporarilyUnavailable:
            "iCloud Temporarily Unavailable"
        case .couldNotDetermine:
            "Unable to Check iCloud"
        case .failed:
            "Unable to Check iCloud"
        }
    }

    var message: String {
        switch self {
        case .checking:
            "ASMR Walk is checking whether this device can sync your walk library."
        case .available:
            "Recording metadata and routes sync with your private iCloud database. Video files stay on the device where they were recorded."
        case .noAccount:
            "Sign in to iCloud in Settings to sync recordings and routes across your devices."
        case .restricted:
            "This device or account is restricted from using iCloud sync."
        case .temporarilyUnavailable:
            "iCloud is not ready right now. ASMR Walk will keep local changes and sync when iCloud becomes available."
        case .couldNotDetermine:
            "ASMR Walk could not determine the current iCloud account status."
        case let .failed(message):
            message
        }
    }

    var systemImage: String {
        switch self {
        case .checking:
            "icloud"
        case .available:
            "icloud.fill"
        case .noAccount:
            "person.crop.circle.badge.exclamationmark"
        case .restricted:
            "lock.icloud"
        case .temporarilyUnavailable:
            "icloud.slash"
        case .couldNotDetermine, .failed:
            "exclamationmark.icloud"
        }
    }
}

protocol CloudSyncAccountStatusProviding: Sendable {
    func accountStatus() async throws -> CKAccountStatus
}

struct CloudKitAccountStatusProvider: CloudSyncAccountStatusProviding {
    private let container: CKContainer

    init(containerIdentifier: String = CloudSyncConfiguration.containerIdentifier) {
        container = CKContainer(identifier: containerIdentifier)
    }

    func accountStatus() async throws -> CKAccountStatus {
        try await container.accountStatus()
    }
}

@MainActor
@Observable
final class CloudSyncStatus {
    private let provider: any CloudSyncAccountStatusProviding

    private(set) var state: CloudSyncAccountState = .checking

    convenience init() {
        self.init(provider: CloudKitAccountStatusProvider())
    }

    init(provider: any CloudSyncAccountStatusProviding) {
        self.provider = provider
    }

    func refresh() async {
        state = .checking

        do {
            state = Self.state(for: try await provider.accountStatus())
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    static func state(for accountStatus: CKAccountStatus) -> CloudSyncAccountState {
        switch accountStatus {
        case .available:
            .available
        case .noAccount:
            .noAccount
        case .restricted:
            .restricted
        case .couldNotDetermine:
            .couldNotDetermine
        case .temporarilyUnavailable:
            .temporarilyUnavailable
        @unknown default:
            .couldNotDetermine
        }
    }
}
