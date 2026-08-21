//
//  WalkRecording.swift
//  ASMR Walk
//

import Foundation
import SwiftData

@Model
final class WalkRecording {
    static let shortRecordingThreshold: TimeInterval = 10

    #Unique<WalkRecording>([\.id])
    #Index<WalkRecording>([\.createdAt])

    var id: UUID
    var title: String
    var createdAt: Date
    var duration: TimeInterval
    var distanceMeters: Double
    var mode: RecordingMode
    var walkDescription: String
    var generatedPlaceName: String?
    var metadataGeneratedAt: Date?
    var isTitleUserEdited: Bool
    var isDescriptionUserEdited: Bool
    var videoURL: URL?
    var videoAssetIdentifier: String?
    var thumbnailURL: URL?
    var thumbnailStyleVersion: Int

    @Relationship(deleteRule: .cascade, inverse: \LocationPoint.recording)
    var points: [LocationPoint]

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = .now,
        duration: TimeInterval = 0,
        distanceMeters: Double = 0,
        mode: RecordingMode,
        walkDescription: String = "",
        generatedPlaceName: String? = nil,
        metadataGeneratedAt: Date? = nil,
        isTitleUserEdited: Bool = false,
        isDescriptionUserEdited: Bool = false,
        videoURL: URL? = nil,
        videoAssetIdentifier: String? = nil,
        thumbnailURL: URL? = nil,
        thumbnailStyleVersion: Int = 0,
        points: [LocationPoint] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.duration = duration
        self.distanceMeters = distanceMeters
        self.mode = mode
        self.walkDescription = walkDescription
        self.generatedPlaceName = generatedPlaceName
        self.metadataGeneratedAt = metadataGeneratedAt
        self.isTitleUserEdited = isTitleUserEdited
        self.isDescriptionUserEdited = isDescriptionUserEdited
        self.videoURL = videoURL
        self.videoAssetIdentifier = videoAssetIdentifier
        self.thumbnailURL = thumbnailURL
        self.thumbnailStyleVersion = thumbnailStyleVersion
        self.points = points
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
        points.append(point)
    }
}
