//
//  RecordingCoordinator.swift
//  ASMR Walk
//

import Observation
import SwiftData

@MainActor
@Observable
final class RecordingCoordinator {
    let recorder: WalkRecorder
    private(set) var activeMode: RecordingMode?

    init(activeMode: RecordingMode? = nil) {
        self.recorder = WalkRecorder()
        self.activeMode = activeMode
    }

    init(recorder: WalkRecorder, activeMode: RecordingMode? = nil) {
        self.recorder = recorder
        self.activeMode = activeMode
    }

    var hasActiveRecording: Bool {
        activeMode != nil
    }

    var activeTab: AppTab? {
        tab(for: activeMode)
    }

    func canStart(_ mode: RecordingMode) -> Bool {
        activeMode == nil || activeMode == mode
    }

    func blockingMode(for requestedMode: RecordingMode) -> RecordingMode? {
        guard let activeMode, activeMode != requestedMode else {
            return nil
        }

        return activeMode
    }

    func tab(for mode: RecordingMode?) -> AppTab? {
        switch mode {
        case .walk:
            return .walk
        case .videoWalk:
            return .videoWalk
        case nil:
            return nil
        }
    }

    @discardableResult
    func start(
        in modelContext: ModelContext,
        mode: RecordingMode,
        allowsBackgroundRecording: Bool = false
    ) async -> Bool {
        guard canStart(mode) else {
            return false
        }

        await recorder.start(
            in: modelContext,
            mode: mode,
            allowsBackgroundRecording: allowsBackgroundRecording
        )

        guard recorder.isRecording else {
            return false
        }

        activeMode = mode
        return true
    }

    @discardableResult
    func finishRecording() -> Bool {
        recorder.finishRecording()
    }

    func stopAndSave() async {
        await recorder.stopAndSave()
        clearInactiveRecording()
    }

    func saveFinishedRecording() async {
        await recorder.saveFinishedRecording()
        clearInactiveRecording()
    }

    func discard() async {
        await recorder.discard()
        clearInactiveRecording()
    }

    func clearInactiveRecording() {
        if recorder.phase == .ready {
            activeMode = nil
        }
    }
}
