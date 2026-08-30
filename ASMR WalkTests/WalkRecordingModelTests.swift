//
//  WalkRecordingModelTests.swift
//  ASMR WalkTests
//

import Foundation
import CoreLocation
import AVFoundation
import CloudKit
import SwiftUI
import SwiftData
import Testing
@testable import ASMR_Walk

@MainActor
struct WalkRecordingModelTests {
    @Test("Delete confirmation explains Photos video ownership")
    func deleteConfirmationForPhotosVideo() {
        let recording = WalkRecording(
            title: "Video Walk",
            mode: .videoWalk,
            videoAssetIdentifier: "photos-asset-id"
        )

        #expect(recording.deleteConfirmationMessage.contains("video remains in Photos"))
    }

    @Test("Local-only video messaging explains cross-device availability")
    func localOnlyVideoMessaging() {
        let recording = WalkRecording(
            title: "Video Walk",
            mode: .videoWalk,
            videoURL: URL(filePath: "/tmp/missing-local-video.mov")
        )

        #expect(recording.videoStorage == .localOnly)
        #expect(recording.videoAvailabilityTitle == "Video Not on This Device")
        #expect(recording.videoAvailabilityMessage.contains("video file stays on the device where it was recorded"))
        #expect(recording.photosExportAvailability.title == "Photos Export Unavailable")
        #expect(recording.photosExportAvailability.message.contains("not on this device"))
    }

    @Test("Photos export availability distinguishes saved and route-only recordings")
    func photosExportAvailabilityStates() {
        let routeOnlyRecording = WalkRecording(title: "Walk", mode: .walk)
        let savedPhotosRecording = WalkRecording(
            title: "Video Walk",
            mode: .videoWalk,
            videoAssetIdentifier: "photos-asset-id"
        )

        #expect(routeOnlyRecording.photosExportAvailability.title == "Photos Export Unavailable")
        #expect(routeOnlyRecording.photosExportAvailability.summaryTitle == "Photos Export Unavailable")
        #expect(routeOnlyRecording.photosExportAvailability.message.contains("no video"))
        #expect(routeOnlyRecording.photosExportAvailability.isActionable == false)
        #expect(savedPhotosRecording.photosExportAvailability.title == "Video Saved to Photos")
        #expect(savedPhotosRecording.photosExportAvailability.summaryTitle == "Video Saved to Photos")
        #expect(savedPhotosRecording.photosExportAvailability.isActionable == false)
    }

    @Test("Photos export is actionable for an in-app video file")
    func photosExportAvailabilityForLocalVideoFile() throws {
        let videoURL = FileManager.default.temporaryDirectory
            .appending(path: "ASMRWalk-\(UUID().uuidString).mov")
        FileManager.default.createFile(atPath: videoURL.path, contents: Data("video".utf8))
        defer {
            try? FileManager.default.removeItem(at: videoURL)
        }

        let recording = WalkRecording(
            title: "Video Walk",
            mode: .videoWalk,
            videoURL: videoURL
        )

        #expect(recording.photosExportAvailability.title == "Save In-App Video to Photos")
        #expect(recording.photosExportAvailability.summaryTitle == "Photos Export Available")
        #expect(recording.photosExportAvailability.fileURL == videoURL)
        #expect(recording.photosExportAvailability.isActionable)
    }

    @Test("Missing local thumbnails are detectable after sync")
    func missingLocalThumbnailDetection() {
        let recording = WalkRecording(
            title: "Synced Walk",
            mode: .walk,
            thumbnailURL: URL(filePath: "/tmp/missing-route-thumbnail.jpg"),
            thumbnailStyleVersion: WalkRouteThumbnailGenerator.styleVersion
        )

        #expect(recording.localThumbnailFileExists == false)
    }

    @Test("Conflict timestamps fall back for existing user-edited recordings")
    func conflictTimestampFallback() {
        let createdAt = Date(timeIntervalSince1970: 1_000)
        let recording = WalkRecording(
            title: "Edited Walk",
            createdAt: createdAt,
            mode: .walk,
            isTitleUserEdited: true,
            isDescriptionUserEdited: true
        )

        #expect(recording.titleConflictTimestamp == createdAt)
        #expect(recording.descriptionConflictTimestamp == createdAt)

        let editedAt = Date(timeIntervalSince1970: 2_000)
        recording.titleEditedAt = editedAt
        recording.descriptionEditedAt = editedAt

        #expect(recording.titleConflictTimestamp == editedAt)
        #expect(recording.descriptionConflictTimestamp == editedAt)
    }

    @Test("Delete confirmation explains local fallback video cleanup")
    func deleteConfirmationForLocalVideoFallback() {
        let recording = WalkRecording(
            title: "Video Walk",
            mode: .videoWalk,
            videoURL: URL(fileURLWithPath: "/tmp/video.mov")
        )

        #expect(recording.deleteConfirmationMessage.contains("app-managed video file"))
    }

    @Test("Delete confirmation explains local video cleanup without removing Photos copies")
    func deleteConfirmationForLocalVideoWithPhotosCopy() {
        let recording = WalkRecording(
            title: "Video Walk",
            mode: .videoWalk,
            videoURL: URL(fileURLWithPath: "/tmp/video.mov"),
            videoAssetIdentifier: "photos-asset-id"
        )

        #expect(recording.deleteConfirmationMessage.contains("app-managed video file"))
        #expect(recording.deleteConfirmationMessage.contains("Photos copy remains"))
    }

    @Test("Delete confirmation explains route-only cleanup")
    func deleteConfirmationForRouteOnlyWalk() {
        let recording = WalkRecording(title: "Walk", mode: .walk)

        #expect(recording.deleteConfirmationMessage == "This permanently removes the recording and its route.")
    }
    @Test("A new walk stores its metadata and defaults")
    func recordingMetadata() {
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let recording = WalkRecording(
            title: "Test Walk",
            createdAt: createdAt,
            duration: 300,
            distanceMeters: 800,
            mode: .walk
        )

        #expect(recording.title == "Test Walk")
        #expect(recording.createdAt == createdAt)
        #expect(recording.duration == 300)
        #expect(recording.distanceMeters == 800)
        #expect(recording.mode == .walk)
        #expect(recording.walkDescription == "")
        #expect(recording.generatedPlaceName == nil)
        #expect(recording.metadataGeneratedAt == nil)
        #expect(recording.isTitleUserEdited == false)
        #expect(recording.isDescriptionUserEdited == false)
        #expect(recording.source == .iPhone)
        #expect(recording.sourceTitle == "iPhone")
        #expect(recording.captureDeviceName == nil)
        #expect(recording.routeTimingStart == createdAt)
        #expect(recording.routeTimingEnd == createdAt.addingTimeInterval(300))
        #expect(recording.externalVideoReference == nil)
        #expect(recording.externalVideoStartedAt == nil)
        #expect(recording.thumbnailURL == nil)
        #expect(recording.thumbnailStyleVersion == 0)
        #expect(recording.points.isEmpty)
        #expect(recording.hasVideo == false)
    }

    @Test("Adding a point includes it in time-ordered route data")
    func addingPoints() {
        let recording = WalkRecording(title: "Test Walk", mode: .walk)
        let laterPoint = makePoint(timestamp: 200)
        let earlierPoint = makePoint(timestamp: 100)

        recording.addPoint(laterPoint)
        recording.addPoint(earlierPoint)

        #expect(recording.points.count == 2)
        #expect(recording.pointsInTimeOrder.map(\.timestamp) == [
            earlierPoint.timestamp,
            laterPoint.timestamp
        ])
    }

    @Test("Video presence is derived from its file URL")
    func videoPresence() {
        let walk = WalkRecording(title: "Walk", mode: .walk)
        let videoWalk = WalkRecording(
            title: "Video Walk",
            mode: .videoWalk,
            videoURL: URL(filePath: "/test/video.mov")
        )

        #expect(walk.hasVideo == false)
        #expect(videoWalk.hasVideo)
    }

    @Test("Local file cleanup includes video and thumbnail assets")
    func localFileCleanupIncludesVideoAndThumbnailAssets() {
        let videoURL = URL(filePath: "/tmp/video.mov")
        let thumbnailURL = URL(filePath: "/tmp/thumbnail.jpg")
        let recording = WalkRecording(
            title: "Video Walk",
            mode: .videoWalk,
            videoURL: videoURL,
            thumbnailURL: thumbnailURL
        )

        #expect(WalkRecordingLocalFiles.removableURLs(for: recording) == [videoURL, thumbnailURL])
    }

    @Test("Short recordings use a 10 second save confirmation threshold")
    func shortRecordingThreshold() {
        let shortWalk = WalkRecording(title: "Short Walk", duration: 9.9, mode: .walk)
        let tenSecondWalk = WalkRecording(title: "Ten Second Walk", duration: 10, mode: .walk)

        #expect(WalkRecording.shortRecordingThreshold == 10)
        #expect(shortWalk.isShortRecording)
        #expect(tenSecondWalk.isShortRecording == false)
    }

    @Test("Watch recording metadata has safe presentation defaults")
    func watchRecordingMetadataPresentation() {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let endedAt = Date(timeIntervalSince1970: 1_300)
        let recording = WalkRecording(
            title: "Watch Walk",
            createdAt: startedAt,
            duration: 300,
            mode: .walk,
            recordingSource: .appleWatch,
            captureDeviceName: "David's Apple Watch",
            routeStartedAt: startedAt,
            routeEndedAt: endedAt
        )

        #expect(recording.source == .appleWatch)
        #expect(recording.sourceTitle == "Apple Watch")
        #expect(recording.sourceSystemImage == "applewatch")
        #expect(recording.sourceSyncMessage == "Recorded on Apple Watch. Route data syncs through iCloud.")
        #expect(recording.isWatchRecording)
        #expect(recording.routeTimingStart == startedAt)
        #expect(recording.routeTimingEnd == endedAt)
        #expect(recording.externalCameraTimingMessage == "No external camera timing has been attached.")
        #expect(recording.externalCameraWorkflowMessage == "Attach a clip label and start time for footage recorded outside ASMR Walk.")
        #expect(recording.videoAvailabilityTitle == "No Video")
        #expect(recording.videoAvailabilityMessage == "This recording has route data only.")
    }

    @Test("Synced Watch recordings without local thumbnails request iPhone thumbnail refresh")
    func syncedWatchRecordingRequestsLocalThumbnailRefresh() {
        let recording = WalkRecording(
            title: "Synced Watch Walk",
            mode: .walk,
            recordingSource: .appleWatch,
            thumbnailURL: nil,
            thumbnailStyleVersion: 0,
            points: [
                makePoint(timestamp: 100),
                makePoint(timestamp: 120, latitude: 33.4490, longitude: -112.0730)
            ]
        )

        #expect(recording.needsRouteThumbnailRefresh)
    }

    @Test("Synced Watch recordings keep current local thumbnails")
    func syncedWatchRecordingKeepsCurrentLocalThumbnail() throws {
        let thumbnailURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appendingPathExtension("jpg")
        try Data([0xFF, 0xD8, 0xFF, 0xD9]).write(to: thumbnailURL)
        defer {
            try? FileManager.default.removeItem(at: thumbnailURL)
        }

        let recording = WalkRecording(
            title: "Synced Watch Walk",
            mode: .walk,
            recordingSource: .appleWatch,
            thumbnailURL: thumbnailURL,
            thumbnailStyleVersion: WalkRouteThumbnailGenerator.styleVersion,
            points: [
                makePoint(timestamp: 100),
                makePoint(timestamp: 120, latitude: 33.4490, longitude: -112.0730)
            ]
        )

        #expect(recording.needsRouteThumbnailRefresh == false)
    }

    @Test("External camera timing describes its route offset")
    func externalCameraTimingPresentation() {
        let routeStart = Date(timeIntervalSince1970: 1_000)
        let recording = WalkRecording(
            title: "External Camera Walk",
            createdAt: routeStart,
            duration: 300,
            mode: .walk,
            recordingSource: .appleWatch,
            routeStartedAt: routeStart,
            externalVideoReference: "A-cam clip 012",
            externalVideoStartedAt: routeStart.addingTimeInterval(-5)
        )

        #expect(recording.externalVideoReference == "A-cam clip 012")
        #expect(recording.externalCameraWorkflowMessage == "External clip: A-cam clip 012")
        #expect(recording.externalCameraTimingMessage == "External camera timing starts 0:05 before the route.")
    }

    @Test("Video playback route progress follows recorded point timing")
    func videoPlaybackRouteProgress() throws {
        let recording = WalkRecording(
            title: "Video Walk",
            mode: .videoWalk,
            points: [
                makePoint(timestamp: 220, latitude: 33.4500, longitude: -112.0710),
                makePoint(timestamp: 100, latitude: 33.4484, longitude: -112.0740),
                makePoint(timestamp: 160, latitude: 33.4490, longitude: -112.0728)
            ]
        )

        #expect(try #require(recording.playbackPoint(at: 0)).latitude == 33.4484)
        #expect(try #require(recording.playbackPoint(at: 65)).latitude == 33.4490)
        #expect(try #require(recording.playbackPoint(at: 500)).latitude == 33.4500)
    }

    @Test("Duration presentation handles minutes and hours")
    func durationPresentation() {
        let shortWalk = WalkRecording(title: "Short", duration: 125, mode: .walk)
        let longWalk = WalkRecording(title: "Long", duration: 3_725, mode: .walk)

        #expect(shortWalk.durationText == "2:05")
        #expect(longWalk.durationText == "1:02:05")
    }

    @Test("Location points expose their map coordinate")
    func locationCoordinate() {
        let point = makePoint(timestamp: 100)

        #expect(point.coordinate.latitude == point.latitude)
        #expect(point.coordinate.longitude == point.longitude)
    }

    @Test("Sample data contains both recording modes")
    func sampleData() {
        #expect(SampleData.recordings.count == 2)
        #expect(Set(SampleData.recordings.map(\.mode)) == Set(RecordingMode.allCases))
        #expect(SampleData.recordings.allSatisfy { $0.points.isEmpty == false })
    }
}
