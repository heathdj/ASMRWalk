//
//  RecordingMode.swift
//  ASMR Walk
//

import Foundation

enum RecordingMode: String, Codable, CaseIterable {
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
