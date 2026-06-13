//
//  WalkRecording+Presentation.swift
//  ASMR Walk
//

import Foundation

extension WalkRecording {
    var durationText: String {
        duration.timerText
    }

    var distanceText: String {
        distanceMeters.distanceText
    }
}

extension TimeInterval {
    var timerText: String {
        let totalSeconds = max(0, Int(rounded()))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%d:%02d", minutes, seconds)
    }
}

extension Double {
    var distanceText: String {
        Measurement(value: max(0, self), unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }
}
