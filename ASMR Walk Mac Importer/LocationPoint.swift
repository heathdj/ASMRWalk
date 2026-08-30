//
//  LocationPoint.swift
//  ASMR Walk Mac Importer
//

import Foundation
import SwiftData

@Model
final class LocationPoint {
    var timestamp: Date = Date.now
    var latitude: Double = 0
    var longitude: Double = 0
    var altitude: Double?
    var horizontalAccuracy: Double = 0
    var speed: Double?
    var recording: WalkRecording?

    init(
        timestamp: Date,
        latitude: Double,
        longitude: Double,
        altitude: Double? = nil,
        horizontalAccuracy: Double,
        speed: Double? = nil
    ) {
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
        self.speed = speed
    }
}
