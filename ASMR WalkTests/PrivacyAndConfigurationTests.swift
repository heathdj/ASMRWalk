//
//  PrivacyAndConfigurationTests.swift
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
struct PrivacyAndConfigurationTests {
    @Test("Privacy usage descriptions are specific")
    func privacyUsageDescriptionsAreSpecific() throws {
        let projectRoot = try #require(repositoryRoot())
        let projectSettingsURL = projectRoot.appending(path: "ASMR Walk.xcodeproj/project.pbxproj")
        let projectSettingsText = try String(contentsOf: projectSettingsURL, encoding: .utf8)

        #expect(projectSettingsText.contains("INFOPLIST_KEY_NSLocationWhenInUseUsageDescription = \"ASMR Walk uses your location while recording to draw and save your walking route.\";"))
        #expect(projectSettingsText.contains("INFOPLIST_KEY_NSLocationAlwaysAndWhenInUseUsageDescription = \"ASMR Walk uses background location only when you enable background GPS recording for walks.\";"))
        #expect(projectSettingsText.contains("INFOPLIST_KEY_NSCameraUsageDescription = \"ASMR Walk uses the camera to record video walks.\";"))
        #expect(projectSettingsText.contains("INFOPLIST_KEY_NSMicrophoneUsageDescription = \"ASMR Walk uses the microphone to record video walks.\";"))
        #expect(projectSettingsText.contains("INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription = \"ASMR Walk saves a copy of a video walk to Photos when you choose Save Video to Photos.\";"))
        #expect(projectSettingsText.contains("INFOPLIST_KEY_NSPhotoLibraryUsageDescription = \"ASMR Walk reads older Photos-backed video walks so you can replay them with your route.\";"))
        #expect(projectSettingsText.contains("INFOPLIST_FILE = \"ASMR-Walk-Info.plist\";"))
        #expect(projectSettingsText.contains("CODE_SIGN_ENTITLEMENTS = \"ASMR Walk/ASMR Walk.entitlements\";"))

        let entitlementsURL = projectRoot.appending(path: "ASMR Walk/ASMR Walk.entitlements")
        let entitlementsData = try Data(contentsOf: entitlementsURL)
        let entitlements = try #require(
            PropertyListSerialization.propertyList(from: entitlementsData, format: nil) as? [String: Any]
        )
        #expect(entitlements["com.apple.developer.icloud-services"] as? [String] == ["CloudKit"])
        #expect(entitlements["com.apple.developer.icloud-container-identifiers"] as? [String] == [CloudSyncConfiguration.containerIdentifier])

        if let infoPlist = try staticInfoPlist(in: projectRoot) {
            #expect(infoPlist["UIBackgroundModes"] as? [String] == ["location", "remote-notification"])
        }
    }

    private func repositoryRoot() -> URL? {
        let environment = ProcessInfo.processInfo.environment
        let candidates = [
            URL(fileURLWithPath: #filePath),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
            Bundle.main.bundleURL,
            environment["SRCROOT"].map(URL.init(fileURLWithPath:)),
            environment["SOURCE_ROOT"].map(URL.init(fileURLWithPath:)),
            environment["PROJECT_DIR"].map(URL.init(fileURLWithPath:)),
            environment["CI_WORKSPACE"].map { URL(fileURLWithPath: $0).appending(path: "repository") }
        ].compactMap { $0 }

        for candidate in candidates {
            if let root = repositoryRoot(startingAt: candidate) {
                return root
            }
        }

        return nil
    }

    private func repositoryRoot(startingAt url: URL) -> URL? {
        var candidate = url.hasDirectoryPath ? url : url.deletingLastPathComponent()

        while candidate.path != candidate.deletingLastPathComponent().path {
            let projectSettingsURL = candidate.appending(path: "ASMR Walk.xcodeproj/project.pbxproj")
            if FileManager.default.fileExists(atPath: projectSettingsURL.path) {
                return candidate
            }

            candidate.deleteLastPathComponent()
        }

        return nil
    }

    private func staticInfoPlist(in projectRoot: URL) throws -> [String: Any]? {
        let candidates = [
            projectRoot.appending(path: "ASMR-Walk-Info.plist"),
            projectRoot.appending(path: "ASMR Walk/ASMR-Walk-Info.plist"),
            projectRoot.appending(path: "ASMR Walk/ASMR Walk/ASMR-Walk-Info.plist")
        ]

        guard let infoPlistURL = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            return nil
        }

        let infoPlistData = try Data(contentsOf: infoPlistURL)
        return try PropertyListSerialization.propertyList(
            from: infoPlistData,
            format: nil
        ) as? [String: Any]
    }

    @Test("Cloud sync uses the configured private container")
    func cloudSyncConfiguration() {
        #expect(CloudSyncConfiguration.containerIdentifier == "iCloud.com.bald-traveler.ASMRWalk")
    }

    @Test("Cloud sync maps iCloud account states to user-visible states")
    func cloudSyncAccountStateMapping() {
        #expect(CloudSyncStatus.state(for: .available) == .available)
        #expect(CloudSyncStatus.state(for: .noAccount) == .noAccount)
        #expect(CloudSyncStatus.state(for: .restricted) == .restricted)
        #expect(CloudSyncStatus.state(for: .temporarilyUnavailable) == .temporarilyUnavailable)
        #expect(CloudSyncStatus.state(for: .couldNotDetermine) == .couldNotDetermine)
        #expect(CloudSyncAccountState.available.message.contains("Video files stay on the device"))
    }
}
