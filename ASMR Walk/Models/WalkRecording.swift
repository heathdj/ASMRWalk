//
//  WalkRecording.swift
//  ASMR Walk
//

import Foundation
import SwiftData

@Model
final class WalkRecording {
    #Unique<WalkRecording>([\.id])
    #Index<WalkRecording>([\.createdAt])

    var id: UUID
    var title: String
    var createdAt: Date
    var duration: TimeInterval
    var distanceMeters: Double
    var mode: RecordingMode
    var videoURL: URL?

    @Relationship(deleteRule: .cascade, inverse: \LocationPoint.recording)
    var points: [LocationPoint]

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = .now,
        duration: TimeInterval = 0,
        distanceMeters: Double = 0,
        mode: RecordingMode,
        videoURL: URL? = nil,
        points: [LocationPoint] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.duration = duration
        self.distanceMeters = distanceMeters
        self.mode = mode
        self.videoURL = videoURL
        self.points = points
    }

    var hasVideo: Bool {
        videoURL != nil
    }

    var pointsInTimeOrder: [LocationPoint] {
        points.sorted { $0.timestamp < $1.timestamp }
    }

    func addPoint(_ point: LocationPoint) {
        points.append(point)
    }
}
