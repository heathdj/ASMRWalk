//
//  RouteExportTests.swift
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
struct RouteExportTests {
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
        #expect(gpxText.contains("<asmrwalk:recordingSource>iPhone</asmrwalk:recordingSource>"))
        #expect(gpxText.contains("<asmrwalk:routeStartedAt>1970-01-01T00:05:00Z</asmrwalk:routeStartedAt>"))
        #expect(gpxText.contains("<asmrwalk:routeEndedAt>1970-01-01T00:07:22Z</asmrwalk:routeEndedAt>"))
        #expect(gpxText.contains("<asmrwalk:hasVideo>true</asmrwalk:hasVideo>"))
        #expect(gpxText.contains("<asmrwalk:horizontalAccuracyMeters>4.25</asmrwalk:horizontalAccuracyMeters>"))
        #expect(gpxText.contains("<asmrwalk:horizontalAccuracyMeters>8</asmrwalk:horizontalAccuracyMeters>"))
        #expect(gpxText.contains("<asmrwalk:speedMetersPerSecond>1.5</asmrwalk:speedMetersPerSecond>"))
        #expect(gpxText.components(separatedBy: "<asmrwalk:speedMetersPerSecond>").count - 1 == 1)
        #expect(gpxText.contains("video.mov") == false)
        #expect(gpxText.contains("/private/var/mobile") == false)
    }

    @Test("GPX export includes Watch and external camera timing metadata")
    func gpxExportIncludesWatchAndExternalCameraMetadata() {
        let routeStartedAt = Date(timeIntervalSince1970: 1_000)
        let routeEndedAt = Date(timeIntervalSince1970: 1_240)
        let externalVideoStartedAt = Date(timeIntervalSince1970: 995)
        let recording = WalkRecording(
            title: "Watch Export",
            createdAt: routeStartedAt,
            duration: 240,
            mode: .walk,
            recordingSource: .appleWatch,
            captureDeviceName: "David's Apple Watch & Camera",
            routeStartedAt: routeStartedAt,
            routeEndedAt: routeEndedAt,
            externalVideoReference: "A-cam <clip 12>",
            externalVideoStartedAt: externalVideoStartedAt,
            points: [
                makePoint(timestamp: 1_000)
            ]
        )

        let gpxText = WalkRouteExport(recording: recording).gpxText

        #expect(gpxText.contains("<asmrwalk:recordingSource>appleWatch</asmrwalk:recordingSource>"))
        #expect(gpxText.contains("<asmrwalk:captureDeviceName>David&apos;s Apple Watch &amp; Camera</asmrwalk:captureDeviceName>"))
        #expect(gpxText.contains("<asmrwalk:routeStartedAt>1970-01-01T00:16:40Z</asmrwalk:routeStartedAt>"))
        #expect(gpxText.contains("<asmrwalk:routeEndedAt>1970-01-01T00:20:40Z</asmrwalk:routeEndedAt>"))
        #expect(gpxText.contains("<asmrwalk:hasVideo>false</asmrwalk:hasVideo>"))
        #expect(gpxText.contains("<asmrwalk:externalVideoReference>A-cam &lt;clip 12&gt;</asmrwalk:externalVideoReference>"))
        #expect(gpxText.contains("<asmrwalk:externalVideoStartedAt>1970-01-01T00:16:35Z</asmrwalk:externalVideoStartedAt>"))
        #expect(gpxText.contains("<asmrwalk:externalVideoOffsetSeconds>-5</asmrwalk:externalVideoOffsetSeconds>"))
        #expect(gpxText.contains("clip 12.mov") == false)
    }

    @Test("GPX export includes recording descriptions")
    func gpxExportIncludesDescription() {
        let recording = WalkRecording(
            title: "Described Walk",
            mode: .walk,
            walkDescription: "A quiet canal walk near Phoenix & Tempe.",
            points: [
                makePoint(timestamp: 100)
            ]
        )

        let gpxText = WalkRouteExport(recording: recording).gpxText

        #expect(gpxText.contains("<desc>A quiet canal walk near Phoenix &amp; Tempe.</desc>"))
        #expect(gpxText.contains("<asmrwalk:description>A quiet canal walk near Phoenix &amp; Tempe.</asmrwalk:description>"))
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
}
