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
    var walkDescription: String = ""
    var generatedPlaceName: String?
    var metadataGeneratedAt: Date?
    var isTitleUserEdited: Bool = false
    var isDescriptionUserEdited: Bool = false
    var titleEditedAt: Date?
    var descriptionEditedAt: Date?
    var recordingSource: String = WalkRecordingSource.iPhone.rawValue
    var captureDeviceName: String?
    var routeStartedAt: Date?
    var routeEndedAt: Date?
    var externalVideoReference: String?
    var externalVideoStartedAt: Date?
    var videoURL: URL?
    var videoAssetIdentifier: String?
    var videoStoragePolicy: String = WalkRecordingVideoStoragePolicy.localOnly.rawValue
    var thumbnailURL: URL?
    var thumbnailStyleVersion: Int = 0

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
        walkDescription: String = "",
        generatedPlaceName: String? = nil,
        metadataGeneratedAt: Date? = nil,
        isTitleUserEdited: Bool = false,
        isDescriptionUserEdited: Bool = false,
        titleEditedAt: Date? = nil,
        descriptionEditedAt: Date? = nil,
        recordingSource: WalkRecordingSource = .iPhone,
        captureDeviceName: String? = nil,
        routeStartedAt: Date? = nil,
        routeEndedAt: Date? = nil,
        externalVideoReference: String? = nil,
        externalVideoStartedAt: Date? = nil,
        videoURL: URL? = nil,
        videoAssetIdentifier: String? = nil,
        videoStoragePolicy: WalkRecordingVideoStoragePolicy = .localOnly,
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
        self.titleEditedAt = titleEditedAt
        self.descriptionEditedAt = descriptionEditedAt
        self.recordingSource = recordingSource.rawValue
        self.captureDeviceName = captureDeviceName
        self.routeStartedAt = routeStartedAt
        self.routeEndedAt = routeEndedAt
        self.externalVideoReference = externalVideoReference
        self.externalVideoStartedAt = externalVideoStartedAt
        self.videoURL = videoURL
        self.videoAssetIdentifier = videoAssetIdentifier
        self.videoStoragePolicy = videoStoragePolicy.rawValue
        self.thumbnailURL = thumbnailURL
        self.thumbnailStyleVersion = thumbnailStyleVersion
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
