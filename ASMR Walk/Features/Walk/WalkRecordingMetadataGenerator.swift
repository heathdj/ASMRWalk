//
//  WalkRecordingMetadataGenerator.swift
//  ASMR Walk
//

import CoreLocation
import Foundation
import MapKit
import SwiftData

nonisolated struct WalkRouteMetadataCoordinate: Equatable, Hashable, Sendable {
    let latitude: Double
    let longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(point: LocationPointSnapshot) {
        latitude = point.latitude
        longitude = point.longitude
    }

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
}

nonisolated struct WalkPlaceMetadata: Equatable, Sendable {
    var areasOfInterest: [String] = []
    var name: String?
    var subLocality: String?
    var locality: String?
    var administrativeArea: String?
    var country: String?
}

nonisolated struct WalkGeneratedRecordingMetadata: Equatable, Sendable {
    let title: String
    let walkDescription: String
    let placeName: String
    let generatedAt: Date
}

nonisolated protocol WalkPlaceGeocoding: Sendable {
    func place(for coordinate: WalkRouteMetadataCoordinate) async throws -> WalkPlaceMetadata
}

nonisolated struct SystemWalkPlaceGeocoder: WalkPlaceGeocoding {
    func place(for coordinate: WalkRouteMetadataCoordinate) async throws -> WalkPlaceMetadata {
        guard let request = MKReverseGeocodingRequest(location: coordinate.location) else {
            throw MKError(.placemarkNotFound)
        }

        return try await withCheckedThrowingContinuation { continuation in
            request.getMapItems { mapItems, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let mapItem = mapItems?.first else {
                    continuation.resume(throwing: MKError(.placemarkNotFound))
                    return
                }

                let addressRepresentations = mapItem.addressRepresentations
                let address = mapItem.address
                continuation.resume(returning: WalkPlaceMetadata(
                    name: mapItem.name ?? address?.shortAddress,
                    subLocality: nil,
                    locality: addressRepresentations?.cityWithContext(.short),
                    administrativeArea: addressRepresentations?.cityWithContext(.full),
                    country: addressRepresentations?.fullAddress(includingRegion: true, singleLine: true)
                ))
            }
        }
    }
}

actor WalkPlaceMetadataCache {
    static let shared = WalkPlaceMetadataCache()

    private var cachedPlaces: [WalkRouteMetadataCacheKey: WalkPlaceMetadata] = [:]

    func place(
        for coordinate: WalkRouteMetadataCoordinate,
        geocoder: any WalkPlaceGeocoding
    ) async throws -> WalkPlaceMetadata {
        let key = WalkRouteMetadataCacheKey(coordinate: coordinate)
        if let cachedPlace = cachedPlaces[key] {
            return cachedPlace
        }

        let place = try await geocoder.place(for: coordinate)
        cachedPlaces[key] = place
        return place
    }
}

nonisolated private struct WalkRouteMetadataCacheKey: Hashable {
    let latitudeBucket: Int
    let longitudeBucket: Int

    init(coordinate: WalkRouteMetadataCoordinate) {
        latitudeBucket = Int((coordinate.latitude * 10_000).rounded())
        longitudeBucket = Int((coordinate.longitude * 10_000).rounded())
    }
}

nonisolated enum WalkRecordingMetadataGenerator {
    static func generate(
        for snapshot: WalkRecordingSnapshot,
        in modelContainer: ModelContainer,
        geocoder: any WalkPlaceGeocoding = SystemWalkPlaceGeocoder(),
        date: Date = .now
    ) async {
        guard let coordinate = representativeCoordinate(from: snapshot.points) else {
            return
        }

        do {
            let place = try await WalkPlaceMetadataCache.shared.place(for: coordinate, geocoder: geocoder)
            guard let metadata = WalkRecordingMetadataBuilder.metadata(
                for: place,
                mode: snapshot.mode,
                createdAt: snapshot.createdAt,
                duration: snapshot.duration,
                distanceMeters: snapshot.distanceMeters,
                generatedAt: date
            ) else {
                return
            }

            let persistence = WalkRecordingPersistence(modelContainer: modelContainer)
            try await persistence.updateGeneratedMetadata(recordingID: snapshot.id, metadata: metadata)
        } catch {
            // Metadata generation is best-effort and must never block or undo a saved recording.
        }
    }

    static func representativeCoordinate(from points: [LocationPointSnapshot]) -> WalkRouteMetadataCoordinate? {
        guard points.isEmpty == false else {
            return nil
        }

        return WalkRouteMetadataCoordinate(point: points[points.count / 2])
    }
}

nonisolated enum WalkRecordingMetadataBuilder {
    static func metadata(
        for place: WalkPlaceMetadata,
        mode: RecordingMode,
        createdAt: Date,
        duration: TimeInterval,
        distanceMeters: Double,
        generatedAt: Date = .now
    ) -> WalkGeneratedRecordingMetadata? {
        guard let placeName = place.displayName else {
            return nil
        }

        let title = "\(placeName) \(mode.title)"
        let dateText = createdAt.formatted(date: .abbreviated, time: .omitted)
        let description = "\(mode.title) near \(placeName), recorded \(dateText) for \(timerText(for: duration)) over \(distanceText(for: distanceMeters))."

        return WalkGeneratedRecordingMetadata(
            title: title,
            walkDescription: description,
            placeName: placeName,
            generatedAt: generatedAt
        )
    }

    private static func timerText(for duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded()))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%d:%02d", minutes, seconds)
    }

    private static func distanceText(for distanceMeters: Double) -> String {
        Measurement(value: max(0, distanceMeters), unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }
}

nonisolated private extension WalkPlaceMetadata {
    var displayName: String? {
        let candidates = areasOfInterest + [
            name,
            subLocality,
            locality,
            administrativeArea,
            country
        ].compactMap { $0 }

        return candidates
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { $0.isEmpty == false }
    }
}
