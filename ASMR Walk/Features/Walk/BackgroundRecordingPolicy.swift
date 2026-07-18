//
//  BackgroundRecordingPolicy.swift
//  ASMR Walk
//

import CoreLocation

enum BackgroundRecordingPolicy {
    static func isEnabledForRecording(mode: RecordingMode, userEnabled: Bool) -> Bool {
        userEnabled && mode == .walk
    }

    static func canContinueInBackground(
        isRecording: Bool,
        isBackgroundRecordingEnabled: Bool,
        authorizationStatus: CLAuthorizationStatus
    ) -> Bool {
        isRecording && isBackgroundRecordingEnabled && authorizationStatus == .authorizedAlways
    }
}

enum RecordingLifecyclePolicy {
    static func shouldStopGPSWalkWhenSceneDeactivates(
        isRecordingWalk: Bool,
        canContinueInBackground: Bool
    ) -> Bool {
        isRecordingWalk && canContinueInBackground == false
    }

    static func shouldStopVideoWalkWhenSceneDeactivates(isRecordingVideoWalk: Bool) -> Bool {
        isRecordingVideoWalk
    }
}
