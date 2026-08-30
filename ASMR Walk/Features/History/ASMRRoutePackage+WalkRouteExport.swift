//
//  ASMRRoutePackage+WalkRouteExport.swift
//  ASMR Walk
//

import Foundation

extension ASMRRoutePackage {
    init(
        export: WalkRouteExport,
        sourceGPX: String? = nil,
        videoReferences: [VideoReference] = []
    ) {
        let points = export.points.map { point in
            RoutePoint(
                timestamp: point.timestamp,
                latitude: point.latitude,
                longitude: point.longitude,
                altitude: point.altitude,
                horizontalAccuracy: point.horizontalAccuracy,
                speed: point.speed
            )
        }
        let resolvedVideoReferences: [VideoReference]
        if videoReferences.isEmpty, export.hasVideo {
            resolvedVideoReferences = [
                VideoReference(
                    kind: .localVideo,
                    displayName: "In-app video on source device",
                    sourceIdentifier: nil,
                    startsAt: nil,
                    offsetSeconds: nil,
                    isEmbedded: false
                )
            ]
        } else {
            resolvedVideoReferences = videoReferences
        }

        let externalVideoReference: VideoReference? = if let reference = export.externalVideoReference,
                                                         reference.isEmpty == false {
            VideoReference(
                kind: .externalCamera,
                displayName: reference,
                sourceIdentifier: reference,
                startsAt: export.externalVideoStartedAt,
                offsetSeconds: export.externalVideoStartedAt?.timeIntervalSince(export.routeStartedAt),
                isEmbedded: false
            )
        } else {
            nil
        }

        manifest = Manifest(
            packageIdentifier: export.recordingID,
            title: export.title,
            walkDescription: export.walkDescription.isEmpty ? nil : export.walkDescription,
            createdAt: export.createdAt,
            durationSeconds: export.duration,
            distanceMeters: export.distanceMeters,
            mode: export.mode,
            recordingSource: export.recordingSource,
            captureDeviceName: export.captureDeviceName,
            routeStartedAt: export.routeStartedAt,
            routeEndedAt: export.routeEndedAt,
            routePointCount: points.count,
            routePointsFile: Self.routePointsFilename,
            sourceGPXFile: sourceGPX == nil ? nil : Self.sourceGPXFilename,
            videoReferences: externalVideoReference.map { resolvedVideoReferences + [$0] } ?? resolvedVideoReferences
        )
        routePoints = points.sorted { $0.timestamp < $1.timestamp }
        self.sourceGPX = sourceGPX
    }
}
