//
//  WalkRecording.swift
//  ASMR Walk
//

import Foundation
import SwiftData

@Model
final class WalkRecording {
    static let shortRecordingThreshold: TimeInterval = 10

    #Index<WalkRecording>([\.createdAt])

    var id: UUID = UUID()
    var title: String = ""
    var createdAt: Date = Date.now
    var duration: TimeInterval = 0
    var distanceMeters: Double = 0
    var mode: RecordingMode = RecordingMode.walk
    var videoURL: URL?
    var videoAssetIdentifier: String?

    @Relationship(deleteRule: .cascade, originalName: "points", inverse: \LocationPoint.recording)
    private var storedPoints: [LocationPoint]?

    var points: [LocationPoint] {
        get {
            storedPoints ?? []
        }
        set {
            storedPoints = newValue
        }
    }

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = .now,
        duration: TimeInterval = 0,
        distanceMeters: Double = 0,
        mode: RecordingMode,
        videoURL: URL? = nil,
        videoAssetIdentifier: String? = nil,
        points: [LocationPoint] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.duration = duration
        self.distanceMeters = distanceMeters
        self.mode = mode
        self.videoURL = videoURL
        self.videoAssetIdentifier = videoAssetIdentifier
        self.storedPoints = points
    }

    var hasVideo: Bool {
        videoAssetIdentifier != nil || videoURL != nil
    }

    var isShortRecording: Bool {
        duration < Self.shortRecordingThreshold
    }

    var pointsInTimeOrder: [LocationPoint] {
        points.sorted { $0.timestamp < $1.timestamp }
    }

    func addPoint(_ point: LocationPoint) {
        storedPoints = points + [point]
    }
}
