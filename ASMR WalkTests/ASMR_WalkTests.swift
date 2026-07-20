//
//  ASMR_WalkTests.swift
//  ASMR WalkTests
//
//  Created by David Heath on 5/24/26.
//

import Foundation
import CoreLocation
import AVFoundation
import SwiftUI
import SwiftData
import Testing
@testable import ASMR_Walk

@MainActor
struct ASMR_WalkTests {
    @Test("The app exposes its primary destinations")
    func primaryDestinations() {
        #expect(AppTab.allCases.count == 4)
        #expect(AppTab.allCases == [.history, .walk, .videoWalk, .settings])
    }

    @Test(
        "Each destination has the expected presentation",
        arguments: [
            (AppTab.history, "History", "clock.arrow.circlepath"),
            (AppTab.walk, "Walk", "figure.walk"),
            (AppTab.videoWalk, "Video Walk", "video.fill"),
            (AppTab.settings, "Settings", "gearshape.fill")
        ]
    )
    func destinationPresentation(tab: AppTab, title: String, systemImage: String) {
        #expect(tab.title == title)
        #expect(tab.systemImage == systemImage)
    }

    @Test("Destination titles and symbols are unique")
    func destinationPresentationIsUnique() {
        let titles = AppTab.allCases.map(\.title)
        let systemImages = AppTab.allCases.map(\.systemImage)

        #expect(Set(titles).count == titles.count)
        #expect(Set(systemImages).count == systemImages.count)
    }

    @Test("Theme choices map to the expected app color scheme")
    func appThemePresentation() {
        #expect(AppTheme.system.title == "System")
        #expect(AppTheme.system.colorScheme == nil)
        #expect(AppTheme.light.colorScheme == .light)
        #expect(AppTheme.dark.colorScheme == .dark)
    }

    @Test("Start recording destination defaults to GPS walk and maps to the expected tab")
    func startRecordingDestinationPresentation() {
        #expect(StartRecordingDestination.walk.title == "GPS Walk")
        #expect(StartRecordingDestination.walk.tab == .walk)
        #expect(StartRecordingDestination.videoWalk.title == "Video Walk")
        #expect(StartRecordingDestination.videoWalk.tab == .videoWalk)
        #expect(StartRecordingDestination(rawValue: StartRecordingDestination.walk.rawValue) == .walk)
    }

    @Test("Background GPS recording is opt-in")
    func backgroundGPSRecordingDefault() {
        #expect(BackgroundGPSRecording.defaultValue == false)
        #expect(BackgroundGPSRecording.storageKey == "backgroundGPSRecordingEnabled")
    }

    @Test("Background GPS recording is only enabled for GPS walks")
    func backgroundGPSRecordingPolicyScopesToGPSWalks() {
        #expect(BackgroundRecordingPolicy.isEnabledForRecording(mode: .walk, userEnabled: true))
        #expect(BackgroundRecordingPolicy.isEnabledForRecording(mode: .walk, userEnabled: false) == false)
        #expect(BackgroundRecordingPolicy.isEnabledForRecording(mode: .videoWalk, userEnabled: true) == false)
        #expect(BackgroundRecordingPolicy.isEnabledForRecording(mode: .videoWalk, userEnabled: false) == false)
    }

    @Test("Background GPS recording requires Always authorization")
    func backgroundGPSRecordingPolicyRequiresAlwaysAuthorization() {
        #expect(BackgroundRecordingPolicy.canContinueInBackground(
            isRecording: true,
            isBackgroundRecordingEnabled: true,
            authorizationStatus: .authorizedAlways
        ))
        #expect(BackgroundRecordingPolicy.canContinueInBackground(
            isRecording: true,
            isBackgroundRecordingEnabled: true,
            authorizationStatus: .authorizedWhenInUse
        ) == false)
        #expect(BackgroundRecordingPolicy.canContinueInBackground(
            isRecording: true,
            isBackgroundRecordingEnabled: false,
            authorizationStatus: .authorizedAlways
        ) == false)
        #expect(BackgroundRecordingPolicy.canContinueInBackground(
            isRecording: false,
            isBackgroundRecordingEnabled: true,
            authorizationStatus: .authorizedAlways
        ) == false)
    }

    @Test("About info exposes app metadata and support contact")
    func aboutInfo() {
        let info = AboutInfo.current

        #expect(info.appName.isEmpty == false)
        #expect(info.version.isEmpty == false)
        #expect(info.build.isEmpty == false)
        #expect(info.contactEmail == "heathdj@me.com")
    }

    @Test("Photos permission explanations describe app intent")
    func photoLibraryPermissionExplanations() {
        #expect(PhotoLibraryVideoStore.saveAccessExplanation.contains("when you choose Save Video to Photos"))
        #expect(PhotoLibraryVideoStore.legacyReadAccessExplanation.contains("older Photos-backed video walks"))
        #expect(PhotoLibraryVideoStore.legacyReadAccessExplanation.contains("replay them with your route"))
    }

    @Test("Video preview prepares automatically only after camera and microphone are authorized")
    func videoPreviewPolicyPreparesForAuthorizedPrivacy() {
        let snapshot = VideoCaptureAuthorizationSnapshot(camera: .authorized, microphone: .authorized)

        #expect(VideoCapturePreviewPolicy.decision(for: snapshot) == .prepare)
    }

    @Test("Video preview waits for user intent while camera or microphone permission is undetermined")
    func videoPreviewPolicyWaitsForUserIntentBeforePrompting() {
        #expect(VideoCapturePreviewPolicy.decision(
            for: VideoCaptureAuthorizationSnapshot(camera: .notDetermined, microphone: .authorized)
        ) == .waitForUserIntent)
        #expect(VideoCapturePreviewPolicy.decision(
            for: VideoCaptureAuthorizationSnapshot(camera: .authorized, microphone: .notDetermined)
        ) == .waitForUserIntent)
    }

    @Test("Video preview blocks when camera or microphone permission is denied")
    func videoPreviewPolicyBlocksDeniedPrivacy() {
        #expect(VideoCapturePreviewPolicy.decision(
            for: VideoCaptureAuthorizationSnapshot(camera: .denied, microphone: .authorized)
        ) == .blocked)
        #expect(VideoCapturePreviewPolicy.decision(
            for: VideoCaptureAuthorizationSnapshot(camera: .authorized, microphone: .restricted)
        ) == .blocked)
    }

    @Test("Video stop outcome records local video")
    func videoStopOutcomeLocalVideo() throws {
        let videoURL = URL(fileURLWithPath: "/tmp/video.mov")
        let outcome = VideoWalkStopOutcome.keptLocalVideo(videoURL: videoURL)

        #expect(outcome == .keptLocalVideo(videoURL: videoURL))
    }

    @Test("Video stop outcome records stop failure discard")
    func videoStopOutcomeStopFailure() throws {
        let error = NSError(
            domain: "VideoStop",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Video file missing"]
        )
        let outcome = VideoWalkStopOutcome.stopFailed(error: error)

        #expect(outcome == .discarded(message: "Video file missing"))
    }

    @Test("GPS lifecycle stops foreground-only walks when the scene deactivates", .bug("https://github.com/heathdj/ASMRWalk/issues/34"))
    func gpsLifecycleStopsForegroundOnlyWalks() {
        #expect(RecordingLifecyclePolicy.shouldStopGPSWalkWhenSceneDeactivates(
            isRecordingWalk: true,
            canContinueInBackground: false
        ))
        #expect(RecordingLifecyclePolicy.shouldStopGPSWalkWhenSceneDeactivates(
            isRecordingWalk: true,
            canContinueInBackground: true
        ) == false)
        #expect(RecordingLifecyclePolicy.shouldStopGPSWalkWhenSceneDeactivates(
            isRecordingWalk: false,
            canContinueInBackground: false
        ) == false)
    }

    @Test("Video lifecycle stops when the scene deactivates", .bug("https://github.com/heathdj/ASMRWalk/issues/34"))
    func videoLifecycleStopsOnSceneDeactivation() {
        #expect(RecordingLifecyclePolicy.shouldStopVideoWalkWhenSceneDeactivates(isRecordingVideoWalk: true))
        #expect(RecordingLifecyclePolicy.shouldStopVideoWalkWhenSceneDeactivates(isRecordingVideoWalk: false) == false)
    }

    @Test("Privacy usage descriptions are specific")
    func privacyUsageDescriptionsAreSpecific() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let infoPlistURL = projectRoot.appending(path: "ASMR-Walk-Info.plist")
        let infoPlistData = try Data(contentsOf: infoPlistURL)
        let infoPlist = try #require(PropertyListSerialization.propertyList(
            from: infoPlistData,
            format: nil
        ) as? [String: Any])

        #expect(infoPlist["NSLocationWhenInUseUsageDescription"] as? String == "ASMR Walk uses your location while recording to draw and save your walking route.")
        #expect(infoPlist["NSLocationAlwaysAndWhenInUseUsageDescription"] as? String == "ASMR Walk uses background location only when you enable background GPS recording for walks.")
        #expect(infoPlist["NSCameraUsageDescription"] as? String == "ASMR Walk uses the camera to record video walks.")
        #expect(infoPlist["NSMicrophoneUsageDescription"] as? String == "ASMR Walk uses the microphone to record video walks.")
        #expect(infoPlist["NSPhotoLibraryAddUsageDescription"] as? String == "ASMR Walk saves a copy of a video walk to Photos when you choose Save Video to Photos.")
        #expect(infoPlist["NSPhotoLibraryUsageDescription"] as? String == "ASMR Walk reads older Photos-backed video walks so you can replay them with your route.")
    }

    @Test("Delete confirmation explains Photos video ownership")
    func deleteConfirmationForPhotosVideo() {
        let recording = WalkRecording(
            title: "Video Walk",
            mode: .videoWalk,
            videoAssetIdentifier: "photos-asset-id"
        )

        #expect(recording.deleteConfirmationMessage.contains("video remains in Photos"))
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
}

@MainActor
struct WalkRecordingSessionTests {
    @Test("The first accurate location starts the route")
    func acceptsFirstAccurateLocation() {
        let now = Date(timeIntervalSince1970: 1_000)
        let session = WalkRecordingSession(startedAt: now)
        let location = makeLocation(latitude: 33, longitude: -112, accuracy: 5, timestamp: now)

        #expect(session.accept(location, now: now))
        #expect(session.snapshot.points.count == 1)
        #expect(session.snapshot.distanceMeters == 0)
    }

    @Test("Inaccurate and stale locations are rejected")
    func rejectsLowQualityLocations() {
        let now = Date(timeIntervalSince1970: 1_000)
        let session = WalkRecordingSession(startedAt: now)
        let inaccurate = makeLocation(latitude: 33, longitude: -112, accuracy: 75, timestamp: now)
        let stale = makeLocation(
            latitude: 33,
            longitude: -112,
            accuracy: 5,
            timestamp: now.addingTimeInterval(-30)
        )

        #expect(session.accept(inaccurate, now: now) == false)
        #expect(session.accept(stale, now: now) == false)
        #expect(session.snapshot.points.isEmpty)
    }

    @Test("Noise below the movement threshold is rejected")
    func rejectsNoise() {
        let now = Date(timeIntervalSince1970: 1_000)
        let session = WalkRecordingSession(startedAt: now)
        let first = makeLocation(latitude: 33, longitude: -112, accuracy: 5, timestamp: now)
        let nearby = makeLocation(
            latitude: 33.000001,
            longitude: -112,
            accuracy: 5,
            timestamp: now.addingTimeInterval(2)
        )

        #expect(session.accept(first, now: now))
        #expect(session.accept(nearby, now: now.addingTimeInterval(2)) == false)
        #expect(session.snapshot.points.count == 1)
    }

    @Test("Accepted movement increases the route distance")
    func accumulatesDistance() {
        let now = Date(timeIntervalSince1970: 1_000)
        let session = WalkRecordingSession(startedAt: now)
        let first = makeLocation(latitude: 33, longitude: -112, accuracy: 5, timestamp: now)
        let second = makeLocation(
            latitude: 33.001,
            longitude: -112,
            accuracy: 5,
            timestamp: now.addingTimeInterval(10)
        )

        #expect(session.accept(first, now: now))
        #expect(session.accept(second, now: now.addingTimeInterval(10)))
        #expect(session.snapshot.points.count == 2)
        #expect(session.snapshot.distanceMeters > 100)
    }

    @Test("Duration is measured from the session start")
    func updatesDuration() {
        let start = Date(timeIntervalSince1970: 1_000)
        let session = WalkRecordingSession(startedAt: start)

        session.updateDuration(at: start.addingTimeInterval(125))

        #expect(session.snapshot.duration == 125)
        #expect(session.snapshot.duration.timerText == "2:05")
    }

    @Test("A video walk session creates video walk metadata")
    func createsVideoWalkSession() {
        let start = Date(timeIntervalSince1970: 1_000)
        let session = WalkRecordingSession(startedAt: start, mode: .videoWalk)

        #expect(session.snapshot.mode == .videoWalk)
        #expect(session.snapshot.title.hasPrefix("Video Walk"))
        #expect(session.snapshot.hasVideo == false)
    }

    private func makeLocation(
        latitude: CLLocationDegrees,
        longitude: CLLocationDegrees,
        accuracy: CLLocationAccuracy,
        timestamp: Date
    ) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: 300,
            horizontalAccuracy: accuracy,
            verticalAccuracy: 5,
            course: -1,
            speed: 1.2,
            timestamp: timestamp
        )
    }
}

@MainActor
struct RecordingCoordinatorTests {
    @Test("A GPS walk blocks a second video walk from starting")
    func gpsWalkBlocksVideoWalk() {
        let coordinator = RecordingCoordinator(activeMode: .walk)

        #expect(coordinator.hasActiveRecording)
        #expect(coordinator.canStart(.walk))
        #expect(coordinator.canStart(.videoWalk) == false)
        #expect(coordinator.blockingMode(for: .videoWalk) == .walk)
        #expect(coordinator.activeTab == .walk)
    }

    @Test("A video walk blocks a second GPS walk from starting")
    func videoWalkBlocksGPSWalk() {
        let coordinator = RecordingCoordinator(activeMode: .videoWalk)

        #expect(coordinator.hasActiveRecording)
        #expect(coordinator.canStart(.videoWalk))
        #expect(coordinator.canStart(.walk) == false)
        #expect(coordinator.blockingMode(for: .walk) == .videoWalk)
        #expect(coordinator.activeTab == .videoWalk)
    }

    @Test("An idle coordinator allows either recording mode")
    func idleCoordinatorAllowsAnyMode() {
        let coordinator = RecordingCoordinator()

        #expect(coordinator.hasActiveRecording == false)
        #expect(coordinator.canStart(.walk))
        #expect(coordinator.canStart(.videoWalk))
        #expect(coordinator.blockingMode(for: .walk) == nil)
        #expect(coordinator.blockingMode(for: .videoWalk) == nil)
        #expect(coordinator.activeTab == nil)
    }

    @Test("Denied location can recover after Settings grants access", .bug("https://github.com/heathdj/ASMRWalk/issues/34"))
    func deniedLocationCanRecoverAfterSettingsGrant() {
        let locationClient = FakeWalkLocationClient(authorizationStatus: .denied)
        let recorder = WalkRecorder(locationClient: locationClient)

        recorder.startPreviewingLocation()

        #expect(recorder.isLocationAccessDenied)
        #expect(recorder.isPreviewingLocation == false)
        #expect(recorder.errorMessage == "Location access is unavailable.")

        locationClient.authorizationStatus = .authorizedWhenInUse
        recorder.refreshAuthorizationStatus()
        recorder.startPreviewingLocation(requestAuthorization: false)

        #expect(recorder.isLocationAccessDenied == false)
        #expect(recorder.isPreviewingLocation)
        #expect(recorder.errorMessage == nil)
        #expect(locationClient.didStartHeadingUpdates)
    }

    @Test("Background GPS requests Always when only When In Use is granted", .bug("https://github.com/heathdj/ASMRWalk/issues/34"))
    func backgroundGPSRequestsAlwaysUpgrade() {
        let locationClient = FakeWalkLocationClient(authorizationStatus: .authorizedWhenInUse)
        let recorder = WalkRecorder(locationClient: locationClient)

        recorder.setBackgroundRecordingEnabled(true)

        #expect(locationClient.requestAlwaysAuthorizationCount == 1)
        #expect(locationClient.requestWhenInUseAuthorizationCount == 0)
        #expect(recorder.canContinueInBackground == false)
        #expect(locationClient.allowsBackgroundLocationUpdates == false)
        #expect(recorder.needsAlwaysLocationForBackgroundRecording)
    }

    @Test("Background GPS enables updates only for Always-authorized GPS walks", .bug("https://github.com/heathdj/ASMRWalk/issues/34"))
    func backgroundGPSEnablesUpdatesForAlwaysAuthorizedWalks() async throws {
        let container = try makeTestContainer()
        let locationClient = FakeWalkLocationClient(authorizationStatus: .authorizedAlways)
        let recorder = WalkRecorder(locationClient: locationClient)
        let coordinator = RecordingCoordinator(recorder: recorder)

        let didStart = await coordinator.start(
            in: container.mainContext,
            mode: .walk,
            allowsBackgroundRecording: true
        )

        #expect(didStart)
        #expect(recorder.canContinueInBackground)
        #expect(locationClient.allowsBackgroundLocationUpdates)
        #expect(locationClient.pausesLocationUpdatesAutomatically == false)
        #expect(locationClient.backgroundActivityCount == 1)
        let backgroundActivity = try #require(locationClient.backgroundActivities.first)

        await coordinator.discard()

        #expect(coordinator.hasActiveRecording == false)
        #expect(recorder.phase == .ready)
        #expect(locationClient.allowsBackgroundLocationUpdates == false)
        #expect(locationClient.pausesLocationUpdatesAutomatically)
        #expect(backgroundActivity.didInvalidate)
        #expect(locationClient.backgroundActivityCount == 1)
    }

    @Test("Saving an Always-authorized background GPS walk invalidates background activity without replacing it", .bug("https://github.com/heathdj/ASMRWalk/issues/29"))
    func savingBackgroundGPSWalkInvalidatesBackgroundActivityWithoutReplacement() async throws {
        let container = try makeTestContainer()
        let locationClient = FakeWalkLocationClient(authorizationStatus: .authorizedAlways)
        let recorder = WalkRecorder(locationClient: locationClient)
        let coordinator = RecordingCoordinator(recorder: recorder)

        let didStart = await coordinator.start(
            in: container.mainContext,
            mode: .walk,
            allowsBackgroundRecording: true
        )

        try #require(didStart)
        #expect(locationClient.allowsBackgroundLocationUpdates)
        #expect(locationClient.backgroundActivityCount == 1)
        let backgroundActivity = try #require(locationClient.backgroundActivities.first)

        await coordinator.stopAndSave()

        #expect(coordinator.hasActiveRecording == false)
        #expect(recorder.phase == .ready)
        #expect(locationClient.allowsBackgroundLocationUpdates == false)
        #expect(locationClient.pausesLocationUpdatesAutomatically)
        #expect(backgroundActivity.didInvalidate)
        #expect(locationClient.backgroundActivityCount == 1)
    }

    @Test("Video walks stay foreground-only even when background GPS is enabled", .bug("https://github.com/heathdj/ASMRWalk/issues/34"))
    func videoWalksStayForegroundOnlyWhenBackgroundGPSIsEnabled() async throws {
        let container = try makeTestContainer()
        let locationClient = FakeWalkLocationClient(authorizationStatus: .authorizedAlways)
        let recorder = WalkRecorder(locationClient: locationClient)
        let coordinator = RecordingCoordinator(recorder: recorder)

        let didStart = await coordinator.start(
            in: container.mainContext,
            mode: .videoWalk,
            allowsBackgroundRecording: true
        )

        #expect(didStart)
        #expect(recorder.canContinueInBackground == false)
        #expect(locationClient.allowsBackgroundLocationUpdates == false)
        #expect(locationClient.backgroundActivityCount == 0)

        await coordinator.discard()
    }

    @Test("Video stop saves the local video URL through the coordinator flow", .bug("https://github.com/heathdj/ASMRWalk/issues/34"))
    func videoStopSavesLocalVideoThroughCoordinatorFlow() async throws {
        let container = try makeTestContainer()
        let locationClient = FakeWalkLocationClient(authorizationStatus: .authorizedWhenInUse)
        let recorder = WalkRecorder(locationClient: locationClient)
        let coordinator = RecordingCoordinator(recorder: recorder)
        let videoURL = URL(fileURLWithPath: "/tmp/local-video.mov")
        let camera = FakeVideoRecordingController(stopResult: .success(videoURL))

        let didStart = await coordinator.start(in: container.mainContext, mode: .videoWalk)
        try #require(didStart)

        let result = await VideoWalkStopFlow(
            coordinator: coordinator,
            camera: camera
        ).stop(confirmShortRecording: false)

        #expect(result == .saved)
        #expect(coordinator.hasActiveRecording == false)
        #expect(camera.messages.contains("Video walk saved in ASMR Walk."))

        let recording = try #require(try fetchOnlyRecording(in: container))
        #expect(recording.videoURL == videoURL)
        #expect(recording.videoAssetIdentifier == nil)
    }

    @Test("Camera stop failure discards the draft recording through the coordinator flow", .bug("https://github.com/heathdj/ASMRWalk/issues/34"))
    func cameraStopFailureDiscardsDraftRecordingThroughCoordinatorFlow() async throws {
        let container = try makeTestContainer()
        let locationClient = FakeWalkLocationClient(authorizationStatus: .authorizedWhenInUse)
        let recorder = WalkRecorder(locationClient: locationClient)
        let coordinator = RecordingCoordinator(recorder: recorder)
        let camera = FakeVideoRecordingController(stopResult: .failure(TestError(message: "Video stop failed")))

        let didStart = await coordinator.start(in: container.mainContext, mode: .videoWalk)
        try #require(didStart)

        let result = await VideoWalkStopFlow(
            coordinator: coordinator,
            camera: camera
        ).stop(stopSessionWhenFinished: true, confirmShortRecording: false)

        #expect(result == .failed)
        #expect(coordinator.hasActiveRecording == false)
        #expect(recorder.phase == .ready)
        #expect(camera.messages.contains("Video stop failed"))
        #expect(camera.didStopSession)
        #expect(try fetchOnlyRecording(in: container) == nil)
    }
}

@MainActor
struct WalkRecordingTests {
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

    @Test("Short recordings use a 10 second save confirmation threshold")
    func shortRecordingThreshold() {
        let shortWalk = WalkRecording(title: "Short Walk", duration: 9.9, mode: .walk)
        let tenSecondWalk = WalkRecording(title: "Ten Second Walk", duration: 10, mode: .walk)

        #expect(WalkRecording.shortRecordingThreshold == 10)
        #expect(shortWalk.isShortRecording)
        #expect(tenSecondWalk.isShortRecording == false)
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

    @Test("Recordings can be inserted, fetched, updated, and deleted")
    func recordingLifecycle() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let recording = WalkRecording(
            title: "Original Title",
            duration: 120,
            distanceMeters: 400,
            mode: .walk,
            points: [makePoint(timestamp: 100)]
        )

        context.insert(recording)
        try context.save()

        var fetched = try context.fetch(FetchDescriptor<WalkRecording>())
        let savedRecording = try #require(fetched.first)
        #expect(fetched.count == 1)
        #expect(savedRecording.points.count == 1)

        savedRecording.title = "Updated Title"
        try context.save()

        fetched = try context.fetch(FetchDescriptor<WalkRecording>())
        #expect(fetched.first?.title == "Updated Title")

        context.delete(savedRecording)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<WalkRecording>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<LocationPoint>()) == 0)
    }

    @Test("Persistence checkpoints append only new route points")
    func persistenceCheckpointsAppendOnlyNewPoints() async throws {
        let recordingID = try #require(UUID(uuidString: "E94C5F79-B21C-4687-9345-D640978534E1"))
        let container = try makeContainer()
        let persistence = WalkRecordingPersistence(modelContainer: container)
        let firstCheckpoint = makeSnapshot(
            id: recordingID,
            duration: 30,
            distanceMeters: 90,
            pointCount: 10
        )
        let secondCheckpoint = makeSnapshot(
            id: recordingID,
            duration: 60,
            distanceMeters: 180,
            pointCount: 15
        )

        try await persistence.save(firstCheckpoint)
        try await persistence.save(secondCheckpoint)

        let recording = try #require(try fetchRecording(id: recordingID, in: container))
        #expect(recording.points.count == 15)
        #expect(recording.duration == 60)
        #expect(recording.distanceMeters == 180)
        #expect(recording.pointsInTimeOrder.map(\.timestamp) == secondCheckpoint.points.map(\.timestamp))
    }

    @Test("Repeated persistence checkpoints do not duplicate points")
    func repeatedPersistenceCheckpointsDoNotDuplicatePoints() async throws {
        let recordingID = try #require(UUID(uuidString: "5E19B546-9E52-4C93-9086-4C263FB8384D"))
        let container = try makeContainer()
        let persistence = WalkRecordingPersistence(modelContainer: container)
        let checkpoint = makeSnapshot(
            id: recordingID,
            duration: 45,
            distanceMeters: 135,
            pointCount: 12
        )

        try await persistence.save(checkpoint)
        try await persistence.save(checkpoint)
        try await persistence.save(checkpoint)

        let recording = try #require(try fetchRecording(id: recordingID, in: container))
        #expect(recording.points.count == 12)
        #expect(Set(recording.points.map(\.timestamp)).count == 12)
    }

    @Test("Final persistence save retains all points after partial checkpoints")
    func finalPersistenceSaveRetainsAllPointsAfterPartialCheckpoints() async throws {
        let recordingID = try #require(UUID(uuidString: "8F23B3D8-6911-4193-A558-D52704386507"))
        let container = try makeContainer()
        let persistence = WalkRecordingPersistence(modelContainer: container)
        let firstCheckpoint = makeSnapshot(
            id: recordingID,
            duration: 120,
            distanceMeters: 360,
            pointCount: 40
        )
        let finalSnapshot = makeSnapshot(
            id: recordingID,
            title: "Finished Walk",
            duration: 180,
            distanceMeters: 540,
            pointCount: 75
        )

        try await persistence.save(firstCheckpoint)
        try await persistence.save(finalSnapshot)

        let recording = try #require(try fetchRecording(id: recordingID, in: container))
        #expect(recording.title == "Finished Walk")
        #expect(recording.points.count == 75)
        #expect(recording.pointsInTimeOrder.map(\.timestamp) == finalSnapshot.points.map(\.timestamp))
    }

    @Test("Final persistence save recovers points after a missed checkpoint")
    func finalPersistenceSaveRecoversPointsAfterMissedCheckpoint() async throws {
        let recordingID = try #require(UUID(uuidString: "9EB7066D-6430-4F2D-9639-A91E0505D294"))
        let container = try makeContainer()
        let persistence = WalkRecordingPersistence(modelContainer: container)
        let firstCheckpoint = makeSnapshot(
            id: recordingID,
            duration: 120,
            distanceMeters: 360,
            pointCount: 40
        )
        _ = makeSnapshot(
            id: recordingID,
            duration: 150,
            distanceMeters: 450,
            pointCount: 60
        )
        let finalSnapshot = makeSnapshot(
            id: recordingID,
            duration: 210,
            distanceMeters: 630,
            pointCount: 90
        )

        try await persistence.save(firstCheckpoint)
        try await persistence.save(finalSnapshot)

        let recording = try #require(try fetchRecording(id: recordingID, in: container))
        #expect(recording.points.count == 90)
        #expect(recording.pointsInTimeOrder.map(\.timestamp) == finalSnapshot.points.map(\.timestamp))
        #expect(recording.duration == 210)
        #expect(recording.distanceMeters == 630)
    }

    @Test("Persistence updates metadata without rewriting existing points")
    func persistenceUpdatesMetadataWithoutRewritingExistingPoints() async throws {
        let recordingID = try #require(UUID(uuidString: "2823E0B3-0866-43EA-A1D9-9404C28A0201"))
        let container = try makeContainer()
        let persistence = WalkRecordingPersistence(modelContainer: container)
        let firstCheckpoint = makeSnapshot(
            id: recordingID,
            duration: 30,
            distanceMeters: 90,
            pointCount: 8
        )
        let metadataOnlyCheckpoint = makeSnapshot(
            id: recordingID,
            title: "Updated Metadata",
            duration: 75,
            distanceMeters: 90,
            pointCount: 8
        )

        try await persistence.save(firstCheckpoint)
        try await persistence.save(metadataOnlyCheckpoint)

        let recording = try #require(try fetchRecording(id: recordingID, in: container))
        #expect(recording.title == "Updated Metadata")
        #expect(recording.duration == 75)
        #expect(recording.points.count == 8)
        #expect(recording.pointsInTimeOrder.map(\.timestamp) == metadataOnlyCheckpoint.points.map(\.timestamp))
    }

    @Test("Sample data contains both recording modes")
    func sampleData() {
        #expect(SampleData.recordings.count == 2)
        #expect(Set(SampleData.recordings.map(\.mode)) == Set(RecordingMode.allCases))
        #expect(SampleData.recordings.allSatisfy { $0.points.isEmpty == false })
    }

    @Test("Google Maps export includes the route endpoints and walking mode")
    func googleMapsExport() throws {
        let recording = WalkRecording(
            title: "Export Walk",
            mode: .walk,
            points: [
                makePoint(timestamp: 100, latitude: 33.4484, longitude: -112.0740),
                makePoint(timestamp: 200, latitude: 33.4490, longitude: -112.0728),
                makePoint(timestamp: 300, latitude: 33.4500, longitude: -112.0710)
            ]
        )

        let url = try #require(WalkRouteExport(recording: recording).googleMapsURL)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })

        #expect(query["origin"] == "33.448400,-112.074000")
        #expect(query["destination"] == "33.450000,-112.071000")
        #expect(query["travelmode"] == "walking")
        #expect(query["waypoints"] == "33.449000,-112.072800")
    }

    @Test("GPX export preserves every point in time order and escapes its title")
    func gpxExport() throws {
        let recording = WalkRecording(
            title: "Creek & Canal",
            createdAt: Date(timeIntervalSince1970: 300),
            mode: .walk,
            points: [
                makePoint(timestamp: 200, latitude: 33.4490, longitude: -112.0728),
                makePoint(timestamp: 100, latitude: 33.4484, longitude: -112.0740)
            ]
        )

        let export = WalkRouteExport(recording: recording)
        let firstPoint = try #require(export.gpxText.range(of: "lat=\"33.448400\""))
        let secondPoint = try #require(export.gpxText.range(of: "lat=\"33.449000\""))

        #expect(export.gpxText.contains("<name>Creek &amp; Canal</name>"))
        #expect(export.gpxText.components(separatedBy: "<trkpt ").count - 1 == 2)
        #expect(firstPoint.lowerBound < secondPoint.lowerBound)
        #expect(export.gpxFile.filename == "Creek-Canal.gpx")
    }

    @Test("GPX export includes ASMR Walk extensions for importer sync and diagnostics")
    func gpxExportExtensions() throws {
        let recordingID = try #require(UUID(uuidString: "3B278DC8-F7C6-4A01-8B55-C627DD6F00E1"))
        let recording = WalkRecording(
            id: recordingID,
            title: "Video Export",
            createdAt: Date(timeIntervalSince1970: 300),
            duration: 142.75,
            mode: .videoWalk,
            videoURL: URL(filePath: "/private/var/mobile/Containers/Data/Application/video.mov"),
            points: [
                makePoint(timestamp: 100, horizontalAccuracy: 4.25, speed: 1.5),
                makePoint(timestamp: 120, latitude: 33.4490, longitude: -112.0728, horizontalAccuracy: 8)
            ]
        )

        let gpxText = WalkRouteExport(recording: recording).gpxText

        #expect(gpxText.contains("xmlns:asmrwalk=\"https://asmrwalk.app/gpx/1\""))
        #expect(gpxText.contains("<asmrwalk:recordingID>\(recordingID.uuidString)</asmrwalk:recordingID>"))
        #expect(gpxText.contains("<asmrwalk:durationSeconds>142.75</asmrwalk:durationSeconds>"))
        #expect(gpxText.contains("<asmrwalk:recordingMode>videoWalk</asmrwalk:recordingMode>"))
        #expect(gpxText.contains("<asmrwalk:hasVideo>true</asmrwalk:hasVideo>"))
        #expect(gpxText.contains("<asmrwalk:horizontalAccuracyMeters>4.25</asmrwalk:horizontalAccuracyMeters>"))
        #expect(gpxText.contains("<asmrwalk:horizontalAccuracyMeters>8</asmrwalk:horizontalAccuracyMeters>"))
        #expect(gpxText.contains("<asmrwalk:speedMetersPerSecond>1.5</asmrwalk:speedMetersPerSecond>"))
        #expect(gpxText.components(separatedBy: "<asmrwalk:speedMetersPerSecond>").count - 1 == 1)
        #expect(gpxText.contains("video.mov") == false)
        #expect(gpxText.contains("/private/var/mobile") == false)
    }

    @Test("GPX export uses POSIX-safe number formatting for elevation")
    func gpxExportElevationFormatting() {
        let recording = WalkRecording(
            title: "Elevation Export",
            mode: .walk,
            points: [
                makePoint(timestamp: 100, altitude: 331.25)
            ]
        )

        #expect(WalkRouteExport(recording: recording).gpxText.contains("<ele>331.25</ele>"))
    }

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: WalkRecording.self,
            LocationPoint.self,
            configurations: configuration
        )
    }

    private func makePoint(
        timestamp: TimeInterval,
        latitude: Double = 33.4484,
        longitude: Double = -112.0740,
        altitude: Double? = nil,
        horizontalAccuracy: Double = 5,
        speed: Double? = nil
    ) -> LocationPoint {
        LocationPoint(
            timestamp: Date(timeIntervalSince1970: timestamp),
            latitude: latitude,
            longitude: longitude,
            altitude: altitude,
            horizontalAccuracy: horizontalAccuracy,
            speed: speed
        )
    }

    private func makeSnapshot(
        id: UUID,
        title: String = "Checkpoint Walk",
        createdAt: Date = Date(timeIntervalSince1970: 1_000),
        duration: TimeInterval,
        distanceMeters: Double,
        pointCount: Int
    ) -> WalkRecordingSnapshot {
        WalkRecordingSnapshot(
            id: id,
            title: title,
            createdAt: createdAt,
            duration: duration,
            distanceMeters: distanceMeters,
            mode: .walk,
            points: (0..<pointCount).map { index in
                LocationPointSnapshot(
                    timestamp: createdAt.addingTimeInterval(TimeInterval(index)),
                    latitude: 33.4484 + (Double(index) * 0.0001),
                    longitude: -112.0740 + (Double(index) * 0.0001),
                    altitude: nil,
                    horizontalAccuracy: 5,
                    speed: 1.2
                )
            }
        )
    }

    private func fetchRecording(id: UUID, in container: ModelContainer) throws -> WalkRecording? {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<WalkRecording>(
            predicate: #Predicate { recording in
                recording.id == id
            }
        )
        return try context.fetch(descriptor).first
    }
}

private func makeTestContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: WalkRecording.self,
        LocationPoint.self,
        configurations: configuration
    )
}

private func fetchOnlyRecording(in container: ModelContainer) throws -> WalkRecording? {
    let context = ModelContext(container)
    let recordings = try context.fetch(FetchDescriptor<WalkRecording>())
    return recordings.first
}

private struct TestError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}

@MainActor
private final class FakeBackgroundActivity: WalkBackgroundActivity {
    private(set) var didInvalidate = false

    func invalidate() {
        didInvalidate = true
    }
}

@MainActor
private final class FakeWalkLocationClient: WalkLocationClient {
    var authorizationStatus: CLAuthorizationStatus
    var allowsBackgroundLocationUpdates = false
    var pausesLocationUpdatesAutomatically = true
    var headingUpdatesAvailable = true
    private(set) var requestWhenInUseAuthorizationCount = 0
    private(set) var requestAlwaysAuthorizationCount = 0
    private(set) var didStartHeadingUpdates = false
    private(set) var didStopHeadingUpdates = false
    private(set) var backgroundActivityCount = 0
    private(set) var backgroundActivities: [FakeBackgroundActivity] = []
    private weak var delegate: CLLocationManagerDelegate?

    init(authorizationStatus: CLAuthorizationStatus) {
        self.authorizationStatus = authorizationStatus
    }

    func setDelegate(_ delegate: CLLocationManagerDelegate?) {
        self.delegate = delegate
    }

    func requestWhenInUseAuthorization() {
        requestWhenInUseAuthorizationCount += 1
    }

    func requestAlwaysAuthorization() {
        requestAlwaysAuthorizationCount += 1
    }

    func startUpdatingHeading() {
        didStartHeadingUpdates = true
    }

    func stopUpdatingHeading() {
        didStopHeadingUpdates = true
    }

    func liveUpdates() -> AsyncThrowingStream<WalkLocationUpdateSnapshot, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func makeBackgroundActivity() -> any WalkBackgroundActivity {
        backgroundActivityCount += 1
        let activity = FakeBackgroundActivity()
        backgroundActivities.append(activity)
        return activity
    }
}

@MainActor
private final class FakeVideoRecordingController: VideoRecordingControlling {
    let stopURL: URL?
    let stopError: (any Error)?
    private(set) var messages: [String] = []
    private(set) var errors: [String] = []
    private(set) var didStopSession = false

    init(stopResult: Result<URL, TestError>) {
        switch stopResult {
        case let .success(url):
            stopURL = url
            stopError = nil
        case let .failure(error):
            stopURL = nil
            stopError = error
        }
    }

    func stopRecording() async throws -> URL {
        if let stopURL {
            return stopURL
        }

        throw stopError ?? TestError(message: "Video stop failed")
    }

    func report(_ error: Error) {
        errors.append(error.localizedDescription)
    }

    func reportMessage(_ message: String) {
        messages.append(message)
    }

    func stopSession() {
        didStopSession = true
    }
}
