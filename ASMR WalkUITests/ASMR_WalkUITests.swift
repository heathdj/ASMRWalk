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
        XCTAssertFalse(app.buttons["More"].isEnabled)
    }

    @MainActor
    func testWalkTabShowsReadyStateAndControls() {
        app.tabBars.buttons["Walk"].tap()

        XCTAssertTrue(app.navigationBars["Walk"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["walk.status"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["walk.metrics"].exists)
        XCTAssertTrue(app.buttons["walk.startButton"].isEnabled)
        XCTAssertEqual(
            app.descendants(matching: .any)["walk.metrics"].label,
            "Elapsed time 0 minutes. Distance 0 miles."
        )
    }

    @MainActor
    func testVideoWalkTabShowsReadyStateAndControls() {
        app.tabBars.buttons["Video Walk"].tap()

        XCTAssertTrue(app.navigationBars["Video Walk"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["videoWalk.status"].exists)
        XCTAssertTrue(app.staticTexts["Camera preview will appear here"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["videoWalk.metrics"].exists)
        XCTAssertTrue(app.buttons["videoWalk.startButton"].isEnabled)
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
