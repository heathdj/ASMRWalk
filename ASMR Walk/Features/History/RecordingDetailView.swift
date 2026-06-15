//
//  RecordingDetailView.swift
//  ASMR Walk
//

import SwiftUI

struct RecordingDetailView: View {
    let recording: WalkRecording

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                RouteMapView(recording: recording)
                    .frame(height: 300)
                    .clipShape(.rect(cornerRadius: 24))

                VStack(alignment: .leading, spacing: 6) {
                    Label(recording.mode.title, systemImage: recording.mode.systemImage)
                        .font(.headline)
                        .foregroundStyle(recording.hasVideo ? .red : .green)

                    Text(recording.createdAt, format: .dateTime.weekday(.wide).month(.wide).day().year())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    DetailMetric(
                        value: recording.durationText,
                        label: "Duration",
                        systemImage: "clock"
                    )
                    DetailMetric(
                        value: recording.distanceText,
                        label: "Distance",
                        systemImage: "figure.walk"
                    )
                    DetailMetric(
                        value: "\(recording.points.count)",
                        label: "Route Points",
                        systemImage: "mappin.and.ellipse"
                    )
                }

                if recording.hasVideo {
                    Label("This walk includes a video recording.", systemImage: "video.fill")
                        .font(.subheadline)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.red.opacity(0.1), in: .rect(cornerRadius: 16))
                }
            }
            .padding()
        }
        .navigationTitle(recording.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("Export", systemImage: "square.and.arrow.up") {
                    if let googleMapsURL = routeExport.googleMapsURL {
                        ShareLink(
                            item: googleMapsURL,
                            subject: Text(recording.title),
                            message: Text("Walking route from ASMR Walk")
                        ) {
                            Label("Google Maps Route", systemImage: "map")
                        }
                    }

                    ShareLink(
                        item: routeExport.gpxFile,
                        preview: SharePreview(recording.title, icon: Image(systemName: "map"))
                    ) {
                        Label("GPX Route File", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    }
                }
                .disabled(recording.points.isEmpty)
                .accessibilityIdentifier(AccessibilityID.exportRecordingButton)
            }
        }
        .accessibilityIdentifier(AccessibilityID.recordingDetail)
    }

    private var routeExport: WalkRouteExport {
        WalkRouteExport(recording: recording)
    }
}

private struct DetailMetric: View {
    let value: String
    let label: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.green)
                .accessibilityHidden(true)

            Text(value)
                .font(.headline)
                .monospacedDigit()

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}
