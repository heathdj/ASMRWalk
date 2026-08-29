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

    var deleteConfirmationMessage: String {
        if videoAssetIdentifier != nil, videoURL != nil {
            return "This permanently removes the recording, route, and app-managed video file. The saved Photos copy remains in Photos."
        }

        if videoAssetIdentifier != nil, videoURL == nil {
            return "This permanently removes the ASMR Walk recording and route. The video remains in Photos."
        }

        if videoURL != nil {
            return "This permanently removes the recording, route, and app-managed video file."
        }

        return "This permanently removes the recording and its route."
    }

    var localVideoFileExists: Bool {
        guard let videoURL else {
            return false
        }

        return FileManager.default.fileExists(atPath: videoURL.path)
    }

    var localThumbnailFileExists: Bool {
        guard let thumbnailURL else {
            return false
        }

        return FileManager.default.fileExists(atPath: thumbnailURL.path)
    }

    var videoStorage: WalkRecordingVideoStoragePolicy {
        WalkRecordingVideoStoragePolicy(rawValue: videoStoragePolicy) ?? .localOnly
    }

    var source: WalkRecordingSource {
        WalkRecordingSource(rawValue: recordingSource) ?? .iPhone
    }

    var sourceTitle: String {
        source.title
    }

    var isWatchRecording: Bool {
        source == .appleWatch
    }

    var routeTimingStart: Date {
        routeStartedAt ?? createdAt
    }

    var routeTimingEnd: Date {
        routeEndedAt ?? routeTimingStart.addingTimeInterval(duration)
    }

    var externalCameraTimingMessage: String {
        guard let externalVideoStartedAt else {
            return "No external camera timing has been attached."
        }

        let offset = externalVideoStartedAt.timeIntervalSince(routeTimingStart)
        if abs(offset) < 0.5 {
            return "External camera timing starts with the recorded route."
        }

        if offset > 0 {
            return "External camera timing starts \(offset.timerText) after the route."
        }

        return "External camera timing starts \(abs(offset).timerText) before the route."
    }

    var titleConflictTimestamp: Date? {
        guard isTitleUserEdited else {
            return nil
        }

        return titleEditedAt ?? createdAt
    }

    var descriptionConflictTimestamp: Date? {
        guard isDescriptionUserEdited else {
            return nil
        }

        return descriptionEditedAt ?? createdAt
    }

    var videoAvailabilityTitle: String {
        guard hasVideo else {
            return "No Video"
        }

        if localVideoFileExists {
            return "Video on This Device"
        }

        return "Video Not on This Device"
    }

    var videoAvailabilityMessage: String {
        guard hasVideo else {
            return "This recording has route data only."
        }

        if localVideoFileExists {
            return "The video file is stored locally on this device. Route data and recording details can sync through iCloud."
        }

        return "The route and recording details can sync through iCloud, but the video file stays on the device where it was recorded."
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

enum WalkRecordingLocalFiles {
    static func removableURLs(for recording: WalkRecording) -> [URL] {
        [recording.videoURL, recording.thumbnailURL].compactMap { $0 }
    }
}
