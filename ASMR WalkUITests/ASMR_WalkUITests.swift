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
    }

    @MainActor
    func testFirstLaunchShowsOnboardingAndCanCompleteTour() {
        launchFirstRun()

        XCTAssertTrue(element("onboarding.screen").waitForExistence(timeout: 2))
        XCTAssertTrue(element("onboarding.page.walk").waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Next"].exists)
        XCTAssertTrue(app.buttons["Skip Tour"].exists)

        app.buttons["Next"].tap()
        XCTAssertTrue(element("onboarding.page.videoWalk").waitForExistence(timeout: 2))

        app.buttons["Next"].tap()
        XCTAssertTrue(element("onboarding.page.history").waitForExistence(timeout: 2))

        app.buttons["Start Using ASMR Walk"].tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testHistoryIsTheInitialDestination() {
        launchReturningUser()

        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["No Walks Yet"].exists)
        XCTAssertTrue(app.staticTexts["Your recorded routes, stats, and videos will appear here."].exists)
        XCTAssertTrue(app.buttons["Record a Walk"].isEnabled)
        XCTAssertFalse(app.tabBars.buttons["More"].exists)
    }

    @MainActor
    func testHistoryEmptyStateRecordButtonOpensDefaultWalkTab() {
        launchReturningUser()

        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 2))

        app.buttons["Record a Walk"].tap()

        XCTAssertTrue(element("walk.screen").waitForExistence(timeout: 2))
        XCTAssertTrue(element("walk.status").exists)
    }

    @MainActor
    func testWalkTabShowsReadyStateAndControls() {
        launchReturningUser()

        openTab("Walk")

        XCTAssertTrue(element("walk.screen").waitForExistence(timeout: 2))
        XCTAssertTrue(element("walk.status").exists)
        XCTAssertTrue(element("walk.startButton").isEnabled)
    }

    @MainActor
    func testWalkPermissionDeniedShowsSettingsRecovery() {
        launchWithEnvironment(["ASMR_WALK_UI_TEST_DENIED_LOCATION": "1"])

        openTab("Walk")

        XCTAssertTrue(element("walk.screen").waitForExistence(timeout: 2))
        let status = element("walk.status")
        XCTAssertTrue(status.waitForExistence(timeout: 2))
        XCTAssertTrue(status.label.contains("Location access needed"))
        XCTAssertTrue(element("permissions.openSettings").exists)
        XCTAssertFalse(element("walk.startButton").isEnabled)
    }

    @MainActor
    func testVideoWalkTabShowsReadyStateAndControls() {
        launchReturningUser()

        openTab("Video Walk")

        XCTAssertTrue(element("videoWalk.screen").waitForExistence(timeout: 2))
        XCTAssertTrue(element("videoWalk.status").waitForExistence(timeout: 2))
        XCTAssertTrue(element("videoWalk.startButton").exists)
    }

    @MainActor
    func testVideoWalkPermissionDeniedShowsSettingsRecovery() {
        launchWithEnvironment(["ASMR_WALK_UI_TEST_DENIED_VIDEO_PRIVACY": "1"])

        openTab("Video Walk")

        XCTAssertTrue(element("videoWalk.screen").waitForExistence(timeout: 2))
        let status = element("videoWalk.status")
        XCTAssertTrue(status.waitForExistence(timeout: 2))
        XCTAssertTrue(status.label.contains("Privacy access needed"))
        XCTAssertTrue(element("permissions.openSettings").exists)
        XCTAssertFalse(element("videoWalk.startButton").isEnabled)
    }

    @MainActor
    func testVideoWalkStartRoutesToActiveGPSWalk() {
        launchWithActiveRecording(mode: "walk")

        openTab("Video Walk")

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

        openTab("Settings")

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["recording.activeBanner"].exists)
        XCTAssertTrue(app.buttons["recording.returnButton"].exists)
        XCTAssertTrue(app.buttons["recording.stopButton"].exists)
    }

    @MainActor
    func testActiveGPSRecordingBannerReturnsToWalk() {
        launchWithActiveRecording(mode: "walk")

        openTab("Settings")
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

        openTab("Video Walk")

        XCTAssertTrue(element("videoWalk.screen").waitForExistence(timeout: 2))
        let indicator = element("videoWalk.recordingIndicator")
        XCTAssertTrue(indicator.waitForExistence(timeout: 2))
        XCTAssertEqual(indicator.label, "Recording video")
    }

    @MainActor
    func testSettingsTabShowsThemeAndAbout() {
        launchReturningUser()

        openTab("Settings")

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
            app.launchEnvironment["ASMR_WALK_UI_TEST_ONBOARDING"] = "completed"
            app.launch()
        }
    }

    private func launchWithActiveRecording(mode: String, showsVideoRecordingIndicator: Bool = false) {
        launchWithEnvironment([
            "ASMR_WALK_UI_TEST_ACTIVE_RECORDING_MODE": mode,
            "ASMR_WALK_UI_TEST_SHOW_VIDEO_RECORDING_INDICATOR": showsVideoRecordingIndicator ? "1" : "0"
        ])
    }

    private func launchReturningUser(environment: [String: String] = [:]) {
        launchWithEnvironment(environment, onboardingState: "completed")
    }

    private func launchFirstRun(environment: [String: String] = [:]) {
        launchWithEnvironment(environment, onboardingState: "firstLaunch")
    }

    private func launchWithEnvironment(_ environment: [String: String]) {
        launchWithEnvironment(environment, onboardingState: "completed")
    }

    private func launchWithEnvironment(_ environment: [String: String], onboardingState: String) {
        app.terminate()
        app.launchEnvironment = [:]
        app.launchEnvironment["ASMR_WALK_UI_TEST_ONBOARDING"] = onboardingState
        app.launchEnvironment["ASMR_WALK_UI_TEST_START_DESTINATION"] = "walk"
        for (key, value) in environment {
            app.launchEnvironment[key] = value
        }
        app.launch()
    }

    private func openTab(_ title: String) {
        let tab = app.tabBars.buttons[title]
        XCTAssertTrue(tab.waitForExistence(timeout: 2))
        tab.tap()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
