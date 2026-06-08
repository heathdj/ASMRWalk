//
//  ASMR_WalkTests.swift
//  ASMR WalkTests
//
//  Created by David Heath on 5/24/26.
//

import Testing
@testable import ASMR_Walk

struct ASMR_WalkTests {
    @Test("The app exposes its three primary destinations")
    func primaryDestinations() {
        #expect(AppTab.allCases.count == 3)
        #expect(AppTab.allCases == [.history, .walk, .videoWalk])
    }

    @Test(
        "Each destination has the expected presentation",
        arguments: [
            (AppTab.history, "History", "clock.arrow.circlepath"),
            (AppTab.walk, "Walk", "figure.walk"),
            (AppTab.videoWalk, "Video Walk", "video.fill")
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
}
