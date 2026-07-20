//
//  RecordingDetailView.swift
//  ASMR Walk
//

import SwiftUI
import SwiftData

struct RecordingDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let recording: WalkRecording
    @State private var photoSaveStatus: PhotoSaveStatus?
    @State private var isSavingVideoToPhotos = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if recording.hasVideo {
                    VideoWalkPlaybackView(recording: recording)
                        .frame(height: 300)
                        .clipShape(.rect(cornerRadius: 24))
                } else {
                    RouteMapView(recording: recording)
                        .frame(height: 300)
                        .clipShape(.rect(cornerRadius: 24))
                }

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

                    if recording.localVideoFileExists {
                        saveVideoToPhotosButton
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Route Review")
                            .font(.headline)

                        RouteMapView(recording: recording)
                            .frame(height: 220)
                            .clipShape(.rect(cornerRadius: 20))
                    }
                }
            }
            .padding()
        }
        .navigationTitle(recording.title)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Video Export", isPresented: isShowingPhotoSaveStatus) {
            Button("OK", role: .cancel) {
                photoSaveStatus = nil
            }
        } message: {
            Text(photoSaveStatus?.message ?? "")
        }
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

    private var isShowingPhotoSaveStatus: Binding<Bool> {
        Binding {
            photoSaveStatus != nil
        } set: { isPresented in
            if isPresented == false {
                photoSaveStatus = nil
            }
        }
    }

    private var saveVideoToPhotosButton: some View {
        Button {
            saveVideoToPhotos()
        } label: {
            Label(saveVideoToPhotosTitle, systemImage: recording.videoAssetIdentifier == nil ? "photo.badge.plus" : "checkmark.circle")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .disabled(isSavingVideoToPhotos || recording.videoAssetIdentifier != nil)
        .accessibilityIdentifier(AccessibilityID.saveVideoToPhotosButton)
    }

    private var saveVideoToPhotosTitle: String {
        if isSavingVideoToPhotos {
            return "Saving Video to Photos"
        }

        if recording.videoAssetIdentifier != nil {
            return "Video Saved to Photos"
        }

        return "Save Video to Photos"
    }

    private func saveVideoToPhotos() {
        guard let videoURL = recording.videoURL, FileManager.default.fileExists(atPath: videoURL.path) else {
            photoSaveStatus = .failure("The local video file could not be found.")
            return
        }

        isSavingVideoToPhotos = true
        Task {
            do {
                let assetIdentifier = try await PhotoLibraryVideoStore.saveVideoToPhotoLibrary(from: videoURL)
                recording.videoAssetIdentifier = assetIdentifier
                try modelContext.save()
                photoSaveStatus = .success
            } catch {
                photoSaveStatus = .failure(error.localizedDescription)
            }
            isSavingVideoToPhotos = false
        }
    }
}

private enum PhotoSaveStatus: Equatable {
    case success
    case failure(String)

    var message: String {
        switch self {
        case .success:
            "A copy of this video walk was saved to Photos. ASMR Walk will continue playing the local copy."
        case let .failure(message):
            message
        }
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
