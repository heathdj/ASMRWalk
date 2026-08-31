//
//  RoutePreviewMapView.swift
//  ASMR Walk Mac Importer
//

import MapKit
import SwiftUI

struct RoutePreviewMapView: View {
    let route: RoutePreview?

    @State private var position = MapCameraPosition.automatic

    var body: some View {
        Group {
            if let route {
                Map(position: $position, interactionModes: [.pan, .zoom]) {
                    if route.coordinates.count > 1 {
                        MapPolyline(coordinates: route.coordinates)
                            .stroke(.green, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    }

                    if let start = route.coordinates.first {
                        Marker("Start", systemImage: "figure.walk", coordinate: start)
                            .tint(.green)
                    }

                    if route.coordinates.count > 1, let end = route.coordinates.last {
                        Marker("Finish", systemImage: "flag.checkered", coordinate: end)
                            .tint(.red)
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .mapControls {
                    MapCompass()
                    MapScaleView()
                    MapZoomStepper()
                }
                .onAppear {
                    position = route.cameraPosition
                }
                .onChange(of: route.id) {
                    position = route.cameraPosition
                }
                .accessibilityLabel("Map showing the loaded walking route")
            } else {
                ContentUnavailableView(
                    "No Route Loaded",
                    systemImage: "map",
                    description: Text("Select a synced recording or import a GPX file to preview its route.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.quaternary)
            }
        }
    }
}

private extension RoutePreview {
    var coordinates: [CLLocationCoordinate2D] {
        package.routePoints.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
    }

    var cameraPosition: MapCameraPosition {
        guard coordinates.isEmpty == false else {
            return .automatic
        }

        return .rect(mapRect)
    }

    private var mapRect: MKMapRect {
        let points = coordinates.map(MKMapPoint.init)
        let routeRect = points.reduce(MKMapRect.null) { partialResult, point in
            let pointRect = MKMapRect(x: point.x, y: point.y, width: 1, height: 1)
            return partialResult.union(pointRect)
        }

        let minimumDimension: Double = 1_000
        let width = max(routeRect.width * 1.25, minimumDimension)
        let height = max(routeRect.height * 1.25, minimumDimension)
        let insetX = (width - routeRect.width) / 2
        let insetY = (height - routeRect.height) / 2

        return MKMapRect(
            x: routeRect.origin.x - insetX,
            y: routeRect.origin.y - insetY,
            width: width,
            height: height
        )
    }
}
