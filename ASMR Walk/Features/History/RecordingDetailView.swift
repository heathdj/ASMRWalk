//
//  RecordingDetailView.swift
//  ASMR Walk
//

import SwiftUI
import SwiftData
import UIKit

struct RecordingDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let recording: WalkRecording
    @State private var photoSaveStatus: PhotoSaveStatus?
    @State private var isSavingVideoToPhotos = false
    @State private var isShowingMetadataEditor = false
    @State private var isShowingExternalCameraEditor = false

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

                    Label(recording.sourceTitle, systemImage: recording.sourceSystemImage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(recording.createdAt, format: .dateTime.weekday(.wide).month(.wide).day().year())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if recording.isWatchRecording {
                        Label(recording.sourceSyncMessage, systemImage: "icloud")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                recordingMetadataCard

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

                if recording.isWatchRecording {
                    externalCameraTimingCard
                }

                if recording.hasVideo {
                    Label(recording.videoAvailabilityMessage, systemImage: recording.localVideoFileExists ? "video.fill" : "video.slash")
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
        .sheet(isPresented: $isShowingMetadataEditor) {
            RecordingMetadataEditView(recording: recording)
        }
        .sheet(isPresented: $isShowingExternalCameraEditor) {
            ExternalCameraTimingEditView(recording: recording)
        }
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

                    if let thumbnailImage {
                        ShareLink(
                            item: routeExport.gpxFile,
                            preview: SharePreview(recording.title, image: Image(uiImage: thumbnailImage))
                        ) {
                            Label("GPX Route File", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        }
                    } else {
                        ShareLink(
                            item: routeExport.gpxFile,
                            preview: SharePreview(recording.title, icon: Image(systemName: "map"))
                        ) {
                            Label("GPX Route File", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        }
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

    private var thumbnailImage: UIImage? {
        guard let thumbnailURL = recording.thumbnailURL else {
            return nil
        }

        return UIImage(contentsOfFile: thumbnailURL.path)
    }

    private var externalCameraTimingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("External Camera", systemImage: "video.fill")
                    .font(.headline)

                Spacer()

                Button(recording.externalVideoStartedAt == nil ? "Add" : "Edit", systemImage: "pencil") {
                    isShowingExternalCameraEditor = true
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier(AccessibilityID.editExternalCameraTimingButton)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(recording.externalCameraWorkflowMessage)
                    .font(.subheadline)

                Text(recording.externalCameraTimingMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("External footage stays outside ASMR Walk; GPX export includes only the clip label and timing metadata.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.quaternary, in: .rect(cornerRadius: 16))
    }

    private var recordingMetadataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Details")
                    .font(.headline)

                Spacer()

                Button("Edit", systemImage: "pencil") {
                    isShowingMetadataEditor = true
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier(AccessibilityID.editRecordingMetadataButton)
            }

            VStack(alignment: .leading, spacing: 6) {
                RouteThumbnailView(recording: recording, size: CGSize(width: 128, height: 88))

                Text(recording.title)
                    .font(.title3.weight(.semibold))

                if recording.walkDescription.isEmpty {
                    Text("No description added.")
                        .foregroundStyle(.secondary)
                } else {
                    Text(recording.walkDescription)
                        .foregroundStyle(.secondary)
                }

                if let generatedPlaceName = recording.generatedPlaceName {
                    Label(generatedPlaceName, systemImage: "location")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.quaternary, in: .rect(cornerRadius: 16))
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

private struct RecordingMetadataEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var recording: WalkRecording
    @State private var title: String
    @State private var walkDescription: String
    @State private var saveErrorMessage = ""
    @State private var isShowingSaveError = false

    init(recording: WalkRecording) {
        self.recording = recording
        _title = State(initialValue: recording.title)
        _walkDescription = State(initialValue: recording.walkDescription)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Walk title", text: $title)
                        .textInputAutocapitalization(.words)
                }

                Section {
                    TextEditor(text: $walkDescription)
                        .frame(minHeight: 140)
                } header: {
                    Text("Description")
                } footer: {
                    Text("Descriptions are included in GPX exports and future publishing workflows.")
                }
            }
            .navigationTitle("Edit Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(trimmedTitle.isEmpty)
                    .accessibilityIdentifier(AccessibilityID.saveRecordingMetadataButton)
                }
            }
            .alert("Unable to Save Details", isPresented: $isShowingSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveErrorMessage)
            }
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedDescription: String {
        walkDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        let editedAt = Date.now

        if trimmedTitle != recording.title {
            recording.title = trimmedTitle
            recording.isTitleUserEdited = true
            recording.titleEditedAt = editedAt
        }

        if trimmedDescription != recording.walkDescription {
            recording.walkDescription = trimmedDescription
            recording.isDescriptionUserEdited = true
            recording.descriptionEditedAt = editedAt
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            saveErrorMessage = error.localizedDescription
            isShowingSaveError = true
        }
    }
}

private struct ExternalCameraTimingEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var recording: WalkRecording
    @State private var externalVideoReference: String
    @State private var externalVideoStartedAt: Date
    @State private var saveErrorMessage = ""
    @State private var isShowingSaveError = false

    init(recording: WalkRecording) {
        self.recording = recording
        _externalVideoReference = State(initialValue: recording.externalVideoReference ?? "")
        _externalVideoStartedAt = State(initialValue: recording.externalVideoStartedAt ?? recording.routeTimingStart)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Clip label", text: $externalVideoReference)
                        .textInputAutocapitalization(.words)

                    DatePicker(
                        "Camera Start",
                        selection: $externalVideoStartedAt,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                } footer: {
                    Text("Use a clip name, camera filename, or slate note. ASMR Walk stores timing metadata only; it does not import the external video file.")
                }

                if recording.externalVideoStartedAt != nil || recording.externalVideoReference?.isEmpty == false {
                    Section {
                        Button("Clear External Camera Timing", role: .destructive) {
                            clear()
                        }
                    }
                }
            }
            .navigationTitle("External Camera")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .accessibilityIdentifier(AccessibilityID.saveExternalCameraTimingButton)
                }
            }
            .alert("Unable to Save Timing", isPresented: $isShowingSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveErrorMessage)
            }
        }
    }

    private var trimmedReference: String {
        externalVideoReference.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        recording.externalVideoReference = trimmedReference.isEmpty ? nil : trimmedReference
        recording.externalVideoStartedAt = externalVideoStartedAt
        saveAndDismiss()
    }

    private func clear() {
        recording.externalVideoReference = nil
        recording.externalVideoStartedAt = nil
        saveAndDismiss()
    }

    private func saveAndDismiss() {
        do {
            try modelContext.save()
            dismiss()
        } catch {
            saveErrorMessage = error.localizedDescription
            isShowingSaveError = true
        }
    }
}
