//
//  HistoryView.swift
//  ASMR Walk
//

import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WalkRecording.createdAt, order: .reverse) private var recordings: [WalkRecording]
    let startRecording: () -> Void

    @State private var recordingPendingDeletion: WalkRecording?
    @State private var deletionErrorMessage = ""
    @State private var isShowingDeletionError = false
    @State private var thumbnailRefreshIDs: Set<UUID> = []

    init(startRecording: @escaping () -> Void = {}) {
        self.startRecording = startRecording
    }

    var body: some View {
        NavigationStack {
            Group {
                if recordings.isEmpty {
                    emptyState
                } else {
                    recordingList
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: WalkRecording.self) { recording in
                RecordingDetailView(recording: recording)
            }
            .task {
                await refreshRouteThumbnails()
            }
            .alert("Delete Walk?", isPresented: deleteConfirmation) {
                Button("Delete", role: .destructive) {
                    deletePendingRecording()
                }
                Button("Cancel", role: .cancel) {
                    recordingPendingDeletion = nil
                }
            } message: {
                Text(recordingPendingDeletion?.deleteConfirmationMessage ?? "This permanently removes the recording and its route.")
            }
            .alert("Unable to Delete Walk", isPresented: $isShowingDeletionError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(deletionErrorMessage)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Walks Yet", systemImage: "map")
        } description: {
            Text("Your recorded routes, stats, and videos will appear here.")
        } actions: {
            Button("Record a Walk", systemImage: "figure.walk") {
                startRecording()
            }
            .buttonStyle(.borderedProminent)
        }
        .accessibilityIdentifier(AccessibilityID.historyEmptyState)
    }

    private var recordingList: some View {
        List(recordings) { recording in
            NavigationLink(value: recording) {
                RecordingRow(recording: recording)
            }
            .swipeActions {
                Button("Delete", systemImage: "trash") {
                    recordingPendingDeletion = recording
                }
                .tint(.red)
            }
        }
        .accessibilityIdentifier(AccessibilityID.historyList)
    }

    private var deleteConfirmation: Binding<Bool> {
        Binding(
            get: { recordingPendingDeletion != nil },
            set: { isPresented in
                if isPresented == false {
                    recordingPendingDeletion = nil
                }
            }
        )
    }

    private func deletePendingRecording() {
        guard let recordingPendingDeletion else {
            return
        }

        let removableURLs = WalkRecordingLocalFiles.removableURLs(for: recordingPendingDeletion)
        do {
            modelContext.delete(recordingPendingDeletion)
            try modelContext.save()
            for url in removableURLs {
                try? FileManager.default.removeItem(at: url)
            }
            self.recordingPendingDeletion = nil
        } catch {
            deletionErrorMessage = error.localizedDescription
            isShowingDeletionError = true
        }
    }

    private func refreshRouteThumbnails() async {
        let modelContainer = modelContext.container
        let snapshots = recordings.compactMap { recording -> WalkRecordingSnapshot? in
            guard recording.needsRouteThumbnailRefresh,
                  thumbnailRefreshIDs.contains(recording.id) == false else {
                return nil
            }

            thumbnailRefreshIDs.insert(recording.id)
            return recording.snapshotForThumbnailGeneration
        }

        await withTaskGroup(of: Void.self) { group in
            for snapshot in snapshots {
                group.addTask {
                    await WalkRouteThumbnailGenerator.generate(for: snapshot, in: modelContainer)
                }
            }
        }
    }
}

private struct RecordingRow: View {
    let recording: WalkRecording

    var body: some View {
        HStack(spacing: 14) {
            RouteThumbnailView(recording: recording, size: CGSize(width: 64, height: 52))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(recording.title)
                        .font(.headline)

                    if recording.hasVideo {
                        Image(systemName: recording.localVideoFileExists ? "video.fill" : "video.slash")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .accessibilityLabel(recording.videoAvailabilityTitle)
                    }
                }

                Text(recording.createdAt, format: .dateTime.month(.abbreviated).day().year())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Label(recording.durationText, systemImage: "clock")
                    Label(recording.distanceText, systemImage: "figure.walk")
                    Label(recording.sourceTitle, systemImage: recording.sourceSystemImage)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

private extension WalkRecording {
    var snapshotForThumbnailGeneration: WalkRecordingSnapshot {
        WalkRecordingSnapshot(
            id: id,
            title: title,
            createdAt: createdAt,
            duration: duration,
            distanceMeters: distanceMeters,
            mode: mode,
            recordingSource: source,
            captureDeviceName: captureDeviceName,
            routeStartedAt: routeStartedAt,
            routeEndedAt: routeEndedAt,
            externalVideoReference: externalVideoReference,
            externalVideoStartedAt: externalVideoStartedAt,
            videoURL: videoURL,
            videoAssetIdentifier: videoAssetIdentifier,
            points: pointsInTimeOrder.map { point in
                LocationPointSnapshot(
                    timestamp: point.timestamp,
                    latitude: point.latitude,
                    longitude: point.longitude,
                    altitude: point.altitude,
                    horizontalAccuracy: point.horizontalAccuracy,
                    speed: point.speed
                )
            }
        )
    }
}
