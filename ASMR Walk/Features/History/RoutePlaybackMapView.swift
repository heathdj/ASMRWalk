//
//  RoutePlaybackMapView.swift
//  ASMR Walk
//

import MapKit
import SwiftUI

struct RoutePlaybackMapView: View {
    let recording: WalkRecording
    let elapsedTime: TimeInterval

    private var coordinates: [CLLocationCoordinate2D] {
        recording.pointsInTimeOrder.map(\.coordinate)
    }

    private var currentCoordinate: CLLocationCoordinate2D? {
        recording.playbackPoint(at: elapsedTime)?.coordinate
    }

    var body: some View {
        if coordinates.isEmpty {
            ContentUnavailableView(
                "No Route Data",
                systemImage: "map",
                description: Text("This recording does not contain any location points.")
            )
            .background(.regularMaterial)
        } else {
            Map(initialPosition: .automatic, interactionModes: []) {
                if coordinates.count > 1 {
                    MapPolyline(coordinates: coordinates)
                        .stroke(.green, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                }

                if let start = coordinates.first {
                    Marker("Start", systemImage: "figure.walk", coordinate: start)
                        .tint(.green)
                }

                if let currentCoordinate {
                    Marker("Playback Position", systemImage: "location.fill", coordinate: currentCoordinate)
                        .tint(.blue)
                }

                if coordinates.count > 1, let end = coordinates.last {
                    Marker("Finish", systemImage: "flag.checkered", coordinate: end)
                        .tint(.red)
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .accessibilityLabel("Map showing route progress at \(elapsedTime.timerText)")
        }
    }
}
