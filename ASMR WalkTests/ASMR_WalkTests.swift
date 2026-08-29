//
//  ASMR_WalkTests.swift
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
        #expect(info.contactEmail == "support@bald-traveler.com")
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
}
