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
        app.launchArguments.append("--skip-startup-splash")
        app.launch()
    }

    @MainActor
    func testHistoryIsTheInitialDestination() {
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["No Walks Yet"].exists)
        XCTAssertTrue(app.staticTexts["Your recorded routes, stats, and videos will appear here."].exists)
        XCTAssertTrue(app.buttons["Record a Walk"].isEnabled)
        XCTAssertFalse(app.buttons["More"].isEnabled)
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
    func testSettingsTabShowsThemeAndAbout() {
        app.tabBars.buttons["Settings"].tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["settings.screen"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["settings.themePicker"].exists)

        app.buttons["settings.aboutButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings.aboutSheet"].waitForExistence(timeout: 2))
        let emailPredicate = NSPredicate(format: "label CONTAINS %@", "heathdj@me.com")
        XCTAssertTrue(app.descendants(matching: .any).matching(emailPredicate).firstMatch.exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments.append("--skip-startup-splash")
            app.launch()
        }
    }
}
