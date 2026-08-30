//
//  MacImporterView.swift
//  ASMR Walk Mac Importer
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct MacImporterView: View {
    @Query(sort: \WalkRecording.createdAt, order: .reverse)
    private var syncedRecordings: [WalkRecording]

    @State private var viewModel = MacImporterViewModel()
    @State private var cloudSyncStatus = CloudSyncStatus()
    @State private var isImportingGPX = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                cloudSyncPanel
                syncedRecordingList
                statusPanel
                actionBar
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 680, height: 620)
        .fileImporter(
            isPresented: $isImportingGPX,
            allowedContentTypes: [.gpx, .xml],
            allowsMultipleSelection: false
        ) { result in
            Task {
                await viewModel.handleGPXImportResult(result)
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
                        SyncedRecordingRow(recording: recording) {
                            do {
                                try viewModel.exportSyncedRecording(recording)
                            } catch {
                                viewModel.showFailure(error)
                            }
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
    let export: () -> Void

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

            Button("Create Package", systemImage: "shippingbox") {
                export()
            }
            .disabled(recording.points.isEmpty)
        }
        .padding(12)
    }
}

#Preview {
    MacImporterView()
        .modelContainer(try! MacModelContainerFactory.makeModelContainer(inMemory: true))
}
