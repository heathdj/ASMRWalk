//
//  WalkRecordingSource.swift
//  ASMR Walk
//

import Foundation

enum WalkRecordingSource: String, Codable, CaseIterable, Sendable {
    case iPhone
    case appleWatch

    var title: String {
        switch self {
        case .iPhone:
            "iPhone"
        case .appleWatch:
            "Apple Watch"
        }
    }
}

enum WalkRecordingVideoStoragePolicy: String, Codable, CaseIterable, Sendable {
    case localOnly

    var title: String {
        switch self {
        case .localOnly:
            "Local Only"
        }
    }
}
