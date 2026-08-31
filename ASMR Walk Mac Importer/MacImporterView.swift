//
//  MacImporterView.swift
//  ASMR Walk Mac Importer
//

import SwiftUI
import SwiftData
import Photos
import PhotosUI
import UniformTypeIdentifiers

struct MacImporterView: View {
    @Query(sort: \WalkRecording.createdAt, order: .reverse)
    private var syncedRecordings: [WalkRecording]

    @State private var viewModel = MacImporterViewModel()
    @State private var cloudSyncStatus = CloudSyncStatus()
    @State private var isImportingGPX = false
    @State private var selectedPhotosVideo: PhotosPickerItem?

    var body: some View {
        HSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    cloudSyncPanel
                    syncedRecordingList
                    photosVideoPanel
                    statusPanel
                    actionBar
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: 360, idealWidth: 430)

            routePreviewPanel
                .frame(minWidth: 460)
        }
        .frame(width: 980, height: 680)
        .fileImporter(
            isPresented: $isImportingGPX,
            allowedContentTypes: [.gpx, .xml],
            allowsMultipleSelection: false
        ) { result in
            Task {
                await viewModel.handleGPXImportResult(result)
            }
        }
        .onChange(of: selectedPhotosVideo) {
            guard let selectedPhotosVideo else {
                return
            }

            Task {
                await viewModel.pairPhotosVideo(
                    itemIdentifier: selectedPhotosVideo.itemIdentifier,
                    supportedContentTypes: selectedPhotosVideo.supportedContentTypes
                )
            }
        }
        .task {
            await cloudSyncStatus.refresh()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ASMR Walk Importer")
                .font(.title.bold())

            Text("Create route packages from synced walks or ASMR Walk GPX exports.")
                .foregroundStyle(.secondary)
        }
    }

    private var cloudSyncPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(cloudSyncStatus.accountState.title, systemImage: cloudSyncStatusSystemImage)
                .font(.headline)

            Text(cloudSyncStatus.accountState.message)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var syncedRecordingList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Synced Recordings")
                .font(.headline)

            if cloudSyncStatus.accountState == .available, syncedRecordings.isEmpty {
                ContentUnavailableView(
                    "Waiting for Synced Walks",
                    systemImage: "icloud.and.arrow.down",
                    description: Text("Recordings appear here after iPhone or Apple Watch finishes syncing through iCloud.")
                )
                .frame(minHeight: 160)
            } else if syncedRecordings.isEmpty {
                ContentUnavailableView(
                    "No Synced Walks Loaded",
                    systemImage: "point.topleft.down.curvedto.point.bottomright.up",
                    description: Text("Use GPX import below while iCloud recordings are unavailable.")
                )
                .frame(minHeight: 160)
            } else {
                VStack(spacing: 0) {
                    ForEach(syncedRecordings) { recording in
                        SyncedRecordingRow(
                            recording: recording,
                            isSelected: viewModel.routePreview?.id == recording.id
                        ) {
                            viewModel.loadSyncedRecording(recording)
                        }

                        if recording.id != syncedRecordings.last?.id {
                            Divider()
                        }
                    }
                }
                .background(.regularMaterial, in: .rect(cornerRadius: 8))
            }
        }
    }

    private var photosVideoPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photos Video")
                .font(.headline)

            Text(viewModel.photosVideoPairingMessage)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            HStack {
                PhotosPicker(
                    selection: $selectedPhotosVideo,
                    matching: .videos,
                    preferredItemEncoding: .current,
                    photoLibrary: .shared()
                ) {
                    Label("Choose Photos Video", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.bordered)

                Button("Clear", systemImage: "xmark.circle") {
                    selectedPhotosVideo = nil
                    viewModel.clearPhotosVideoPairing()
                }
                .disabled(viewModel.selectedPhotosVideoReference == nil)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var routePreviewPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.routePreview?.title ?? "Route Preview")
                        .font(.title2.bold())
                        .lineLimit(1)

                    if let routePreview = viewModel.routePreview {
                        Text(routePreview.sourceDescription)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("Load a GPX file or synced recording.")
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let routePreview = viewModel.routePreview {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(routePreview.routePointCount) pts")
                            .font(.callout.monospacedDigit())
                        Text(routePreview.durationText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            RoutePreviewMapView(
                route: viewModel.routePreview,
                selectedPointID: viewModel.selectedRoutePointID,
                selectPoint: viewModel.selectRoutePoint
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(.rect(cornerRadius: 8))

            if let routePreview = viewModel.routePreview {
                routeSummary(routePreview)
                routePointCleanupPanel(routePreview)
            }
        }
        .padding(24)
    }

    private func routeSummary(_ routePreview: RoutePreview) -> some View {
        HStack(spacing: 12) {
            Label(routePreview.distanceText, systemImage: "point.topleft.down.curvedto.point.bottomright.up")
            Label(routePreview.recordingSource.title, systemImage: "record.circle")
            Label(routePreview.recordingMode.title, systemImage: routePreview.recordingMode.systemImage)

            if routePreview.hasPointEdits {
                Label("\(routePreview.removedPointCount) removed", systemImage: "scissors")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func routePointCleanupPanel(_ routePreview: RoutePreview) -> some View {
        HStack(alignment: .center, spacing: 12) {
            if let selectedPoint = routePreview.point(id: viewModel.selectedRoutePointID) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Point \(selectedPoint.sourceIndex + 1)")
                        .font(.headline)
                    Text(selectedPoint.coordinateSummary)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(selectedPoint.timestamp, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("No Point Selected")
                        .font(.headline)
                    Text("Select a point marker on the map to remove it from the pending export.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button("Delete Point", systemImage: "trash", role: .destructive) {
                viewModel.deleteSelectedRoutePoint()
            }
            .disabled(viewModel.selectedRoutePointID == nil || routePreview.canDeletePoint == false)

            Button("Reset Route", systemImage: "arrow.counterclockwise") {
                viewModel.resetRoutePointEdits()
            }
            .disabled(routePreview.hasPointEdits == false)
        }
        .padding(12)
        .background(.regularMaterial, in: .rect(cornerRadius: 8))
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(viewModel.statusTitle, systemImage: viewModel.statusSystemImage)
                .font(.headline)

            if let message = viewModel.statusMessage {
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if let packageURL = viewModel.packageURL {
                Text(packageURL.path(percentEncoded: false))
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial, in: .rect(cornerRadius: 8))
    }

    private var actionBar: some View {
        HStack {
            Button("Import GPX", systemImage: "doc.badge.plus") {
                isImportingGPX = true
            }
            .buttonStyle(.borderedProminent)

            Button("Create Package", systemImage: "shippingbox") {
                do {
                    try viewModel.exportLoadedRoute()
                } catch {
                    viewModel.showFailure(error)
                }
            }
            .disabled(viewModel.routePreview?.routePointCount ?? 0 < 1)

            Button("Reveal Package", systemImage: "arrow.up.forward.app") {
                viewModel.revealPackageInFinder()
            }
            .disabled(viewModel.packageURL == nil)

            Spacer()
        }
    }

    private var cloudSyncStatusSystemImage: String {
        switch cloudSyncStatus.accountState {
        case .checking:
            "icloud"
        case .available:
            "checkmark.icloud.fill"
        case .noAccount:
            "person.crop.circle.badge.exclamationmark"
        case .restricted:
            "lock.icloud"
        case .temporarilyUnavailable:
            "exclamationmark.icloud"
        case .couldNotDetermine:
            "questionmark.app"
        }
    }
}

private struct SyncedRecordingRow: View {
    let recording: WalkRecording
    let isSelected: Bool
    let preview: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: recording.mode.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(recording.displayTitle)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(recording.createdAt, style: .date)
                    Text(recording.durationText)
                    Text(recording.distanceText)
                    Text(recording.source.title)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(recording.points.count) pts")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Button("Preview", systemImage: isSelected ? "checkmark.circle.fill" : "map") {
                preview()
            }
            .disabled(recording.points.isEmpty)
        }
        .padding(12)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
    }
}

private extension RoutePreview.RoutePoint {
    var coordinateSummary: String {
        "\(latitude.formatted(.number.precision(.fractionLength(5)))), \(longitude.formatted(.number.precision(.fractionLength(5))))"
    }
}

#Preview {
    MacImporterView()
        .modelContainer(try! MacModelContainerFactory.makeModelContainer(inMemory: true))
}
