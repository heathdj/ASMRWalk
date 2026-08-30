//
//  ASMRRoutePackage+WalkRecording.swift
//  ASMR Walk Mac Importer
//

import Foundation

extension ASMRRoutePackage {
    init(recording: WalkRecording) {
        let sortedPoints = recording.pointsInTimeOrder
        let routePoints = sortedPoints.map { point in
            RoutePoint(
                timestamp: point.timestamp,
                latitude: point.latitude,
                longitude: point.longitude,
                altitude: point.altitude,
                horizontalAccuracy: point.horizontalAccuracy,
                speed: point.speed
            )
        }

        let localVideoReference: VideoReference? = if recording.hasVideo {
            VideoReference(
                kind: .localVideo,
                displayName: "In-app video on source device",
                sourceIdentifier: nil,
                startsAt: nil,
                offsetSeconds: nil,
                isEmbedded: false
            )
        } else {
            nil
        }

        let externalVideoReference: VideoReference? = if let reference = recording.externalVideoReference,
                                                         reference.isEmpty == false {
            VideoReference(
                kind: .externalCamera,
                displayName: reference,
                sourceIdentifier: reference,
                startsAt: recording.externalVideoStartedAt,
                offsetSeconds: recording.externalVideoStartedAt?.timeIntervalSince(recording.routeTimingStart),
                isEmbedded: false
            )
        } else {
            nil
        }

        manifest = Manifest(
            packageIdentifier: recording.id,
            title: recording.displayTitle,
            walkDescription: recording.walkDescription.isEmpty ? nil : recording.walkDescription,
            createdAt: recording.createdAt,
            durationSeconds: recording.duration,
            distanceMeters: recording.distanceMeters,
            mode: recording.mode,
            recordingSource: recording.source,
            captureDeviceName: recording.captureDeviceName,
            routeStartedAt: recording.routeTimingStart,
            routeEndedAt: recording.routeTimingEnd,
            routePointCount: routePoints.count,
            routePointsFile: Self.routePointsFilename,
            sourceGPXFile: nil,
            videoReferences: [localVideoReference, externalVideoReference].compactMap { $0 }
        )
        self.routePoints = routePoints
        sourceGPX = nil
    }
}
