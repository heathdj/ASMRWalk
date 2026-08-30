//
//  RecordingCoordinatorTests.swift
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
