//
//  RoutePreview.swift
//  ASMR Walk Mac Importer
//

import CoreLocation
import Foundation

struct RoutePreview: Equatable, Identifiable {
    let id: UUID
    let title: String
    let sourceDescription: String
    private let originalPackage: ASMRRoutePackage
    private let originalPoints: [RoutePoint]
    private(set) var routePoints: [RoutePoint]

    init(package: ASMRRoutePackage, sourceDescription: String) {
        self.id = package.manifest.packageIdentifier
        self.title = package.manifest.title
        self.sourceDescription = sourceDescription
        self.originalPackage = package
        self.originalPoints = package.routePoints.enumerated().map { offset, point in
            RoutePoint(sourceIndex: offset, point: point)
        }
        self.routePoints = originalPoints
    }

    var routePointCount: Int {
        routePoints.count
    }

    var removedPointCount: Int {
        originalPoints.count - routePoints.count
    }

    var canDeletePoint: Bool {
        routePoints.count > 1
    }

    var hasPointEdits: Bool {
        removedPointCount > 0
    }

    var exportPackage: ASMRRoutePackage {
        exportPackage(videoReference: nil, mapBackground: nil)
    }

    func exportPackage(
        videoReference: ASMRRoutePackage.VideoReference?,
        mapBackground: PreparedMapBackground? = nil,
        mapBackgrounds: [PreparedMapBackground] = []
    ) -> ASMRRoutePackage {
        var manifest = originalPackage.manifest
        manifest.schemaVersion = ASMRRoutePackage.schemaVersion
        manifest.routePointCount = routePoints.count
        manifest.routeStartedAt = routePoints.first?.timestamp ?? manifest.routeStartedAt
        manifest.routeEndedAt = routePoints.last?.timestamp ?? manifest.routeEndedAt
        manifest.durationSeconds = max(0, manifest.routeEndedAt.timeIntervalSince(manifest.routeStartedAt))
        manifest.distanceMeters = editedDistanceMeters

        if let videoReference {
            manifest.videoReferences.removeAll { $0.kind == .photosAsset || $0.kind == .localVideo }
            manifest.videoReferences.append(videoReference)
        }
        manifest.mapBackground = mapBackground?.metadata
        manifest.mapBackgrounds = mapBackgrounds.isEmpty ? nil : mapBackgrounds.map(\.metadata)

        return ASMRRoutePackage(
            manifest: manifest,
            routePoints: routePoints.map(\.packagePoint),
            sourceGPX: originalPackage.sourceGPX,
            mapBackgroundData: mapBackground?.imageData,
            mapBackgroundDataByFilename: Dictionary(
                uniqueKeysWithValues: mapBackgrounds.map { ($0.metadata.filename, $0.imageData) }
            )
        )
    }

    var durationText: String {
        Self.durationFormatter.string(from: originalPackage.manifest.durationSeconds) ?? "0:00"
    }

    var distanceText: String {
        guard let distanceMeters = originalPackage.manifest.distanceMeters else {
            return "Distance unavailable"
        }

        let measurement = Measurement(value: distanceMeters, unit: UnitLength.meters)
        return Self.distanceFormatter.string(from: measurement)
    }

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }()

    private static let distanceFormatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.numberFormatter.maximumFractionDigits = 2
        return formatter
    }()
}

extension RoutePreview {
    struct RoutePoint: Equatable, Identifiable {
        let id: UUID
        let sourceIndex: Int
        let packagePoint: ASMRRoutePackage.RoutePoint

        init(sourceIndex: Int, point: ASMRRoutePackage.RoutePoint) {
            self.id = UUID()
            self.sourceIndex = sourceIndex
            self.packagePoint = point
        }

        var timestamp: Date {
            packagePoint.timestamp
        }

        var latitude: Double {
            packagePoint.latitude
        }

        var longitude: Double {
            packagePoint.longitude
        }

        var horizontalAccuracy: Double {
            packagePoint.horizontalAccuracy
        }
    }

    var recordingSource: WalkRecordingSource {
        originalPackage.manifest.recordingSource
    }

    var recordingMode: RecordingMode {
        originalPackage.manifest.mode
    }

    var routeStartedAt: Date {
        exportPackage.manifest.routeStartedAt
    }

    mutating func deletePoint(id pointID: RoutePoint.ID) -> RoutePoint? {
        guard canDeletePoint,
              let pointIndex = routePoints.firstIndex(where: { $0.id == pointID }) else {
            return nil
        }

        return routePoints.remove(at: pointIndex)
    }

    mutating func resetEdits() {
        routePoints = originalPoints
    }

    func point(id pointID: RoutePoint.ID?) -> RoutePoint? {
        guard let pointID else {
            return nil
        }

        return routePoints.first { $0.id == pointID }
    }

    private var editedDistanceMeters: Double {
        guard routePoints.count > 1 else {
            return 0
        }

        return zip(routePoints, routePoints.dropFirst()).reduce(0) { partialResult, pair in
            let start = CLLocation(latitude: pair.0.latitude, longitude: pair.0.longitude)
            let end = CLLocation(latitude: pair.1.latitude, longitude: pair.1.longitude)
            return partialResult + end.distance(from: start)
        }
    }
}
