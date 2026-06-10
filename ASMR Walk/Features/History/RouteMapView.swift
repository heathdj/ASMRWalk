//
//  RouteMapView.swift
//  ASMR Walk
//

import MapKit
import SwiftUI

struct RouteMapView: View {
    let recording: WalkRecording

    private var coordinates: [CLLocationCoordinate2D] {
        recording.pointsInTimeOrder.map(\.coordinate)
    }

    var body: some View {
        if coordinates.isEmpty {
            ContentUnavailableView(
                "No Route Data",
                systemImage: "map",
                description: Text("This recording does not contain any location points.")
            )
            .background(.quaternary)
        } else {
            Map(initialPosition: .automatic, interactionModes: [.pan, .zoom]) {
                if coordinates.count > 1 {
                    MapPolyline(coordinates: coordinates)
                        .stroke(.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                }

                if let start = coordinates.first {
                    Marker("Start", systemImage: "figure.walk", coordinate: start)
                        .tint(.green)
                }

                if coordinates.count > 1, let end = coordinates.last {
                    Marker("Finish", systemImage: "flag.checkered", coordinate: end)
                        .tint(.red)
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .accessibilityLabel("Map showing the recorded walking route")
        }
    }
}
