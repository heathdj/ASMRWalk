//
//  RoutePreview.swift
//  ASMR Walk Mac Importer
//

import Foundation

struct RoutePreview: Equatable, Identifiable {
    let id: UUID
    let title: String
    let sourceDescription: String
    let package: ASMRRoutePackage

    init(package: ASMRRoutePackage, sourceDescription: String) {
        self.id = package.manifest.packageIdentifier
        self.title = package.manifest.title
        self.sourceDescription = sourceDescription
        self.package = package
    }

    var routePointCount: Int {
        package.routePoints.count
    }

    var durationText: String {
        Self.durationFormatter.string(from: package.manifest.durationSeconds) ?? "0:00"
    }

    var distanceText: String {
        guard let distanceMeters = package.manifest.distanceMeters else {
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
