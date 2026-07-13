# ASMR Walk Project Memory

## Overview

ASMR Walk is an iPhone walking journal. It will record GPS routes, optionally pair a route with a walk video, keep recordings locally, and export routes for use outside the app.

## Architecture Decisions

- SwiftUI owns the interface and top-level tab navigation.
- SwiftData will persist walk metadata and route points locally.
- `WalkRecording` is the SwiftData root model and owns `LocationPoint` children with a cascade delete rule.
- Sample recordings are created through `SampleData` and only inserted into in-memory preview/test containers.
- History UI lives under `Features/History`; it reads with `@Query`, sends destructive writes through `WalkRecordingPersistence`, and renders routes with native MapKit SwiftUI content.
- Foreground GPS recording lives under `Features/Walk`; `WalkRecordingSession` owns filtering and distance calculations as value snapshots, while `WalkRecorder` owns Core Location streaming and delegates SwiftData checkpoints to `WalkRecordingPersistence`.
- `RecordingCoordinator` is owned at the app tab shell and shares one `WalkRecorder` between GPS Walk and Video Walk so the app never runs two route recordings at once.
- `WalkRecordingPersistence` is a SwiftData `@ModelActor`; recording checkpoints, final saves, and deletes should stay there instead of using the SwiftUI `modelContext` on the main actor.
- Route checkpoints should append only newly accepted points while updating recording metadata; do not rewrite unchanged `LocationPoint` rows on every checkpoint.
- Core Location will be isolated behind a recording service so views do not manage location callbacks directly.
- AVFoundation video capture will remain separate from GPS tracking; both outputs will be linked by one walk recording.
- `VideoCaptureService` owns AVFoundation camera and microphone capture while `WalkRecorder` owns GPS persistence; `VideoWalkView` coordinates them.
- `DockKitAccessoryService` owns DockKit accessory state and event streams for Video Walk; camera shutter toggles recording, camera zoom adjusts `VideoCaptureService`, and other accessory events intentionally no-op for now.
- Video Walk locks the app-supported orientation mask to landscape-right while the tab is visible, and uses that same explicit capture orientation for both `AVCaptureVideoPreviewLayer` and movie output rotation.
- New video walks should save finished `.mov` files into Photos and store the resulting `PHAsset.localIdentifier`; legacy sandbox `videoURL` remains as fallback.
- Deleting a recording removes app metadata and routes; Photos-backed videos remain in Photos, while legacy/app-managed fallback `videoURL` files are deleted.
- `WalkRecorder` also owns live heading updates for map-facing indicators while recording or previewing location.
- Version 1 will render map overlays in the app instead of burning them into exported video.
- App appearance is controlled by `AppTheme` in `@AppStorage`, defaulting to system appearance.
- Startup should go directly from the native static launch screen to `ContentView`; do not reintroduce an artificial SwiftUI splash delay.
- The History empty-state recording button routes to the user's `StartRecordingDestination` setting, defaulting to GPS Walk.
- Background GPS recording is opt-in, GPS-only, and requires Always location authorization plus the `location` background mode; all enablement decisions should flow through `BackgroundRecordingPolicy`.
- Active recordings are surfaced by the app shell with a persistent bottom banner so live metrics and stop controls remain visible when the user switches tabs.
- Version 1 is intentionally iPhone-only; do not re-enable iPad as a targeted device family without a full adaptive-layout and App Store asset pass.
- Version 1 is local-first with no developer-operated backend, accounts, analytics, advertising, or sync; App Privacy answers should be based on actual off-device collection, not protected APIs used only on device.

## Conventions

- Prefer Swift concurrency and async sequences over completion-handler APIs.
- Inject services into features so location, camera, and export behavior can be tested.
- Keep recording state in dedicated observable types, not inside large SwiftUI views.
- Use standard SwiftUI controls first so the interface follows the iOS 26 Liquid Glass system automatically.
- Store video files in app-managed storage and persist only their URLs.
- Prompt on explicit stop before saving recordings shorter than 10 seconds; lifecycle interruptions should save automatically.
- Starting a second recording mode while another is active should route the user back to the active recorder, not create another `WalkRecorder`.
- Recording stop controls and live time/distance belong in the app-level active recording banner, not duplicated inside the Walk and Video Walk tabs.
- Permission prompts should follow explicit user intent; opening a tab may refresh authorization status but must not request camera, microphone, location, or Photos access.
- Background GPS decisions must stay centralized in `BackgroundRecordingPolicy`; Video Walk should remain foreground-only even when the user's Background GPS Recording setting is enabled.
- Put ASMR Walk-specific GPX metadata in `<extensions>` and never export local sandbox video URLs.
- User-initiated exports and share links are not background collection by ASMR Walk, but privacy policy and review notes must explain what route data they contain.
- High-risk release flows should have deterministic Swift Testing or XCUI coverage when possible; physical-device-only behavior belongs in `RELEASE_CHECKLIST.md`.

## Build And Run

Open the project in Xcode, select the `ASMR Walk` scheme, and run on an iPhone iOS 26 simulator or physical iPhone. Location and camera recording must ultimately be verified on a physical iPhone.

## Gotchas

- Google Maps URLs cannot preserve every recorded route point; GPX is the fidelity-preserving export.
- GPX exports include plugin-friendly extensions for duration, mode, video presence, accuracy, and optional speed while remaining readable by generic GPX tools.
- GPS background recording is supported only when the user enables it, starts a GPS Walk, and grants Always location permission.
- Camera, microphone, and location usage descriptions must be configured before their APIs are requested.
- Photos save/playback needs `NSPhotoLibraryAddUsageDescription` and `NSPhotoLibraryUsageDescription`; source code guards against missing keys, but device testing requires the target settings.
- Photos add and read usage strings must stay distinct: add-only explains saving finished video walks to Photos, read explains replaying saved video walks with routes.
- Background GPS recording needs `NSLocationAlwaysAndWhenInUseUsageDescription` and `UIBackgroundModes` containing `location`.
- DockKit support is guarded with `#if canImport(DockKit)` so local SDKs without the framework still build; real accessory behavior must be verified on an iPhone and SDK that expose DockKit.
- The Video Walk tab requests a landscape scene geometry and restores portrait when leaving; the target must continue supporting landscape orientations.
- Disable the idle timer only while video recording is active, not for GPS-only walks.
- Confirm that a video file exists before saving a video walk record; incomplete video sessions should not appear in history.
- Delete messaging must distinguish Photos-backed videos, which remain in Photos, from app-managed fallback video files, which are removed with the recording.
- Route points need accuracy and distance filtering before they affect distance totals or persistence.
- Adding analytics, crash reporting SDKs, iCloud sync, accounts, remote storage, or any app-owned network upload requires revisiting `PrivacyInfo.xcprivacy`, App Privacy answers, and `PRIVACY_POLICY.md`.
