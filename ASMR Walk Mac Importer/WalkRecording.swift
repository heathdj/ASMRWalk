//
//  WalkRecording.swift
//  ASMR Walk Mac Importer
//

import Foundation
import SwiftData

@Model
final class WalkRecording {
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

    var source: WalkRecordingSource {
        WalkRecordingSource(rawValue: recordingSource) ?? .iPhone
    }

    var hasVideo: Bool {
        videoAssetIdentifier != nil || videoURL != nil
    }

    var pointsInTimeOrder: [LocationPoint] {
        points.sorted { $0.timestamp < $1.timestamp }
    }

    var routeTimingStart: Date {
        routeStartedAt ?? pointsInTimeOrder.first?.timestamp ?? createdAt
    }

    var routeTimingEnd: Date {
        routeEndedAt ?? pointsInTimeOrder.last?.timestamp ?? createdAt.addingTimeInterval(duration)
    }

    var displayTitle: String {
        title.isEmpty ? "Untitled Walk" : title
    }

    var durationText: String {
        Self.durationFormatter.string(from: duration) ?? "0:00"
    }

    var distanceText: String {
        let measurement = Measurement(value: distanceMeters, unit: UnitLength.meters)
        return Self.distanceFormatter.string(from: measurement)
    }

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }()

    private static let distanceFormatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.numberFormatter.maximumFractionDigits = 2
        return formatter
    }()
}
