//
//  WalkRecording+Playback.swift
//  ASMR Walk
//

import Foundation

extension WalkRecording {
    func playbackPoint(at elapsedTime: TimeInterval) -> LocationPoint? {
        let orderedPoints = pointsInTimeOrder
        guard let firstPoint = orderedPoints.first else {
            return nil
        }

        let targetDate = firstPoint.timestamp.addingTimeInterval(max(0, elapsedTime))
        return orderedPoints.last { $0.timestamp <= targetDate } ?? firstPoint
    }
}
