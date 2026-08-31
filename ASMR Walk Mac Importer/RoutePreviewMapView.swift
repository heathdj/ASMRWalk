//
//  RoutePreviewMapView.swift
//  ASMR Walk Mac Importer
//

import MapKit
import SwiftUI

struct RoutePreviewMapView: View {
    let route: RoutePreview?
    let selectedPointID: RoutePreview.RoutePoint.ID?
    let selectPoint: (RoutePreview.RoutePoint.ID) -> Void

    @State private var position = MapCameraPosition.automatic

    init(
        route: RoutePreview?,
        selectedPointID: RoutePreview.RoutePoint.ID? = nil,
        selectPoint: @escaping (RoutePreview.RoutePoint.ID) -> Void = { _ in }
    ) {
        self.route = route
        self.selectedPointID = selectedPointID
        self.selectPoint = selectPoint
    }

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

                    ForEach(route.routePoints) { point in
                        Annotation("Route point", coordinate: point.coordinate) {
                            Button {
                                selectPoint(point.id)
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(point.id == selectedPointID ? Color.red : Color.white)
                                    Circle()
                                        .strokeBorder(point.id == selectedPointID ? Color.white : Color.green, lineWidth: 2)
                                }
                                .frame(width: point.id == selectedPointID ? 14 : 10, height: point.id == selectedPointID ? 14 : 10)
                                .shadow(radius: 1)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Route point \(point.sourceIndex + 1)")
                        }
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
                .onChange(of: route.routePointCount) {
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
        routePoints.map(\.coordinate)
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

private extension RoutePreview.RoutePoint {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
