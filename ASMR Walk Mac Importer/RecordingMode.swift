//
//  RecordingMode.swift
//  ASMR Walk
//

import Foundation

nonisolated enum RecordingMode: String, Codable, CaseIterable, Sendable {
    case walk
    case videoWalk

    var title: String {
        switch self {
        case .walk:
            "Walk"
        case .videoWalk:
            "Video Walk"
        }
    }

    var systemImage: String {
        switch self {
        case .walk:
            "figure.walk"
        case .videoWalk:
            "video.fill"
        }
    }
}
