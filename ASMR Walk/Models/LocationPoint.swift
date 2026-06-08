//
//  LocationPoint.swift
//  ASMR Walk
//

import Foundation
import SwiftData

@Model
final class LocationPoint {
    var timestamp: Date
    var latitude: Double
    var longitude: Double
    var altitude: Double?
    var horizontalAccuracy: Double
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
