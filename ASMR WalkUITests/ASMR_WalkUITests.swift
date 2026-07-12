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
        XCTAssertTrue(app.descendants(matching: .any)["walk.metrics"].exists)
        XCTAssertTrue(app.buttons["walk.startButton"].isEnabled)
        let metricsLabel = app.descendants(matching: .any)["walk.metrics"].label
        XCTAssertTrue(metricsLabel.contains("Elapsed time 0:00"))
        XCTAssertTrue(metricsLabel.contains("Distance"))
    }

    @MainActor
    func testVideoWalkTabShowsReadyStateAndControls() {
        app.tabBars.buttons["Video Walk"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["videoWalk.screen"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["videoWalk.status"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["videoWalk.metrics"].exists)
        XCTAssertTrue(app.buttons["videoWalk.startButton"].exists)
    }

    @MainActor
    func testVideoWalkStartRoutesToActiveGPSWalk() {
        app.terminate()
        app.launchEnvironment["ASMR_WALK_UI_TEST_SKIP_ONBOARDING"] = "1"
        app.launchEnvironment["ASMR_WALK_UI_TEST_ACTIVE_RECORDING_MODE"] = "walk"
        app.launch()

        app.tabBars.buttons["Video Walk"].tap()

        XCTAssertTrue(app.buttons["Go to Walk"].waitForExistence(timeout: 2))
        app.buttons["Go to Walk"].tap()
        XCTAssertTrue(app.navigationBars["Walk"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.buttons["walk.startButton"].label, "Start Walk")
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
}
