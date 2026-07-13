//
//  ASMR_WalkUITests.swift
//  ASMR WalkUITests
//
//  Created by David Heath on 5/24/26.
//

import XCTest

final class ASMR_WalkUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    @MainActor
    func testHistoryIsTheInitialDestination() {
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["No Walks Yet"].exists)
        XCTAssertTrue(app.staticTexts["Your recorded routes, stats, and videos will appear here."].exists)
        XCTAssertTrue(app.buttons["Record a Walk"].isEnabled)
        XCTAssertFalse(app.tabBars.buttons["More"].exists)
    }

    @MainActor
    func testHistoryEmptyStateRecordButtonOpensDefaultWalkTab() {
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 2))

        app.buttons["Record a Walk"].tap()

        XCTAssertTrue(app.navigationBars["Walk"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["walk.status"].exists)
    }

    @MainActor
    func testWalkTabShowsReadyStateAndControls() {
        app.tabBars.buttons["Walk"].tap()

        XCTAssertTrue(app.navigationBars["Walk"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["walk.status"].exists)
        XCTAssertTrue(app.buttons["walk.startButton"].isEnabled)
    }

    @MainActor
    func testWalkPermissionDeniedShowsSettingsRecovery() {
        launchWithEnvironment(["ASMR_WALK_UI_TEST_DENIED_LOCATION": "1"])

        app.tabBars.buttons["Walk"].tap()

        XCTAssertTrue(app.navigationBars["Walk"].waitForExistence(timeout: 2))
        let status = app.descendants(matching: .any)["walk.status"]
        XCTAssertTrue(status.exists)
        XCTAssertTrue(status.label.contains("Location access needed"))
        XCTAssertTrue(app.buttons["permissions.openSettings"].exists)
        XCTAssertFalse(app.buttons["walk.startButton"].isEnabled)
    }

    @MainActor
    func testVideoWalkTabShowsReadyStateAndControls() {
        app.tabBars.buttons["Video Walk"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["videoWalk.screen"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["videoWalk.status"].exists)
        XCTAssertTrue(app.buttons["videoWalk.startButton"].exists)
    }

    @MainActor
    func testVideoWalkPermissionDeniedShowsSettingsRecovery() {
        launchWithEnvironment(["ASMR_WALK_UI_TEST_DENIED_VIDEO_PRIVACY": "1"])

        app.tabBars.buttons["Video Walk"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["videoWalk.screen"].waitForExistence(timeout: 2))
        let status = app.descendants(matching: .any)["videoWalk.status"]
        XCTAssertTrue(status.exists)
        XCTAssertTrue(status.label.contains("Privacy access needed"))
        XCTAssertTrue(app.buttons["permissions.openSettings"].exists)
        XCTAssertFalse(app.buttons["videoWalk.startButton"].isEnabled)
    }

    @MainActor
    func testVideoWalkStartRoutesToActiveGPSWalk() {
        launchWithActiveRecording(mode: "walk")

        app.tabBars.buttons["Video Walk"].tap()

        XCTAssertTrue(app.buttons["Go to Walk"].waitForExistence(timeout: 2))
        app.buttons["Go to Walk"].tap()
        XCTAssertTrue(app.navigationBars["Walk"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.buttons["walk.startButton"].label, "Start Walk")
    }

    @MainActor
    func testActiveGPSRecordingBannerStaysVisibleAcrossTabs() {
        launchWithActiveRecording(mode: "walk")

        XCTAssertTrue(app.descendants(matching: .any)["recording.activeBanner"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["recording.returnButton"].exists)
        XCTAssertTrue(app.buttons["recording.stopButton"].exists)

        app.tabBars.buttons["Settings"].tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["recording.activeBanner"].exists)
        XCTAssertTrue(app.buttons["recording.returnButton"].exists)
        XCTAssertTrue(app.buttons["recording.stopButton"].exists)
    }

    @MainActor
    func testActiveGPSRecordingBannerReturnsToWalk() {
        launchWithActiveRecording(mode: "walk")

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))

        app.buttons["recording.returnButton"].tap()

        XCTAssertTrue(app.navigationBars["Walk"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testActiveVideoRecordingBannerShowsStopVideoControl() {
        launchWithActiveRecording(mode: "videoWalk")

        XCTAssertTrue(app.descendants(matching: .any)["recording.activeBanner"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Stop Video"].exists)
        XCTAssertFalse(app.buttons["Video"].exists)
    }

    @MainActor
    func testVideoRecordingIndicatorIsExplicit() {
        launchWithActiveRecording(mode: "videoWalk", showsVideoRecordingIndicator: true)

        app.tabBars.buttons["Video Walk"].tap()

        let indicator = app.descendants(matching: .any)["videoWalk.recordingIndicator"]
        XCTAssertTrue(indicator.waitForExistence(timeout: 2))
        XCTAssertEqual(indicator.label, "Recording video")
    }

    @MainActor
    func testSettingsTabShowsThemeAndAbout() {
        app.tabBars.buttons["Settings"].tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["settings.screen"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["settings.themePicker"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["settings.startRecordingDestinationPicker"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["settings.backgroundGPSRecordingToggle"].exists)

        app.buttons["settings.aboutButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings.aboutSheet"].waitForExistence(timeout: 2))
        let emailPredicate = NSPredicate(format: "label CONTAINS %@", "heathdj@me.com")
        XCTAssertTrue(app.descendants(matching: .any).matching(emailPredicate).firstMatch.exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launch()
        }
    }

    private func launchWithActiveRecording(mode: String, showsVideoRecordingIndicator: Bool = false) {
        launchWithEnvironment([
            "ASMR_WALK_UI_TEST_ACTIVE_RECORDING_MODE": mode,
            "ASMR_WALK_UI_TEST_SHOW_VIDEO_RECORDING_INDICATOR": showsVideoRecordingIndicator ? "1" : "0"
        ])
    }

    private func launchWithEnvironment(_ environment: [String: String]) {
        app.terminate()
        app.launchEnvironment = [:]
        app.launchEnvironment["ASMR_WALK_UI_TEST_SKIP_ONBOARDING"] = "1"
        for (key, value) in environment {
            app.launchEnvironment[key] = value
        }
        app.launch()
    }
}
