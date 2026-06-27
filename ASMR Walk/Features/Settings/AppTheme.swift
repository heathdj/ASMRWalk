//
//  AppTheme.swift
//  ASMR Walk
//

import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "appTheme"

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .system:
            "System"
        case .light:
            "Light"
        case .dark:
            "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}

enum StartRecordingDestination: String, CaseIterable, Identifiable {
    case walk
    case videoWalk

    static let storageKey = "startRecordingDestination"

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .walk:
            "GPS Walk"
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

    var tab: AppTab {
        switch self {
        case .walk:
            .walk
        case .videoWalk:
            .videoWalk
        }
    }
}

enum BackgroundGPSRecording {
    static let storageKey = "backgroundGPSRecordingEnabled"
    static let defaultValue = false
}
