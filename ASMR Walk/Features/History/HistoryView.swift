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
            .alert("Delete Walk?", isPresented: deleteConfirmation) {
                Button("Delete", role: .destructive) {
                    deletePendingRecording()
                }
                Button("Cancel", role: .cancel) {
                    recordingPendingDeletion = nil
                }
            } message: {
                Text("This permanently removes the recording and its route.")
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

        let videoURL = recordingPendingDeletion.videoURL
        modelContext.delete(recordingPendingDeletion)

        do {
            try modelContext.save()
            if let videoURL {
                try? FileManager.default.removeItem(at: videoURL)
            }
            self.recordingPendingDeletion = nil
        } catch {
            modelContext.rollback()
            deletionErrorMessage = error.localizedDescription
            isShowingDeletionError = true
        }
    }
}

private struct RecordingRow: View {
    let recording: WalkRecording

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: recording.mode.systemImage)
                .font(.title2)
                .foregroundStyle(recording.hasVideo ? .red : .green)
                .frame(width: 44, height: 44)
                .background(.quaternary, in: .rect(cornerRadius: 12))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(recording.title)
                        .font(.headline)

                    if recording.hasVideo {
                        Image(systemName: "video.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .accessibilityLabel("Includes video")
                    }
                }

                Text(recording.createdAt, format: .dateTime.month(.abbreviated).day().year())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Label(recording.durationText, systemImage: "clock")
                    Label(recording.distanceText, systemImage: "figure.walk")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
