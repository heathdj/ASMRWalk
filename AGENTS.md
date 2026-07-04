# ASMR Walk Project Memory

## Overview

ASMR Walk is an iPhone walking journal. It will record GPS routes, optionally pair a route with a walk video, keep recordings locally, and export routes for use outside the app.

## Architecture Decisions

- SwiftUI owns the interface and top-level tab navigation.
- SwiftData will persist walk metadata and route points locally.
- `WalkRecording` is the SwiftData root model and owns `LocationPoint` children with a cascade delete rule.
- Sample recordings are created through `SampleData` and only inserted into in-memory preview/test containers.
- History UI lives under `Features/History`; it reads with `@Query`, explicitly saves destructive changes, and renders routes with native MapKit SwiftUI content.
- Foreground GPS recording lives under `Features/Walk`; `WalkRecordingSession` owns filtering and distance calculations, while `WalkRecorder` owns Core Location streaming and SwiftData checkpoints.
- Core Location will be isolated behind a recording service so views do not manage location callbacks directly.
- AVFoundation video capture will remain separate from GPS tracking; both outputs will be linked by one walk recording.
- `VideoCaptureService` owns AVFoundation camera and microphone capture while `WalkRecorder` owns GPS persistence; `VideoWalkView` coordinates them.
- `DockKitAccessoryService` owns DockKit accessory state and event streams for Video Walk; camera shutter toggles recording, camera zoom adjusts `VideoCaptureService`, and other accessory events intentionally no-op for now.
- Video Walk locks the app-supported orientation mask to landscape-right while the tab is visible, and uses that same explicit capture orientation for both `AVCaptureVideoPreviewLayer` and movie output rotation.
- New video walks should save finished `.mov` files into Photos and store the resulting `PHAsset.localIdentifier`; legacy sandbox `videoURL` remains as fallback.
- `WalkRecorder` also owns live heading updates for map-facing indicators while recording or previewing location.
- Version 1 will render map overlays in the app instead of burning them into exported video.
- App appearance is controlled by `AppTheme` in `@AppStorage`, defaulting to system appearance.
- Startup should go directly from the native static launch screen to `ContentView`; do not reintroduce an artificial SwiftUI splash delay.
- The History empty-state recording button routes to the user's `StartRecordingDestination` setting, defaulting to GPS Walk.
- Background GPS recording is opt-in, GPS-only, and requires Always location authorization plus the `location` background mode.

## Conventions

- Prefer Swift concurrency and async sequences over completion-handler APIs.
- Inject services into features so location, camera, and export behavior can be tested.
- Keep recording state in dedicated observable types, not inside large SwiftUI views.
- Use standard SwiftUI controls first so the interface follows the iOS 26 Liquid Glass system automatically.
- Store video files in app-managed storage and persist only their URLs.
- Prompt on explicit stop before saving recordings shorter than 10 seconds; lifecycle interruptions should save automatically.
- Put ASMR Walk-specific GPX metadata in `<extensions>` and never export local sandbox video URLs.

## Build And Run

Open the project in Xcode, select the `ASMR Walk` scheme, and run on an iOS 26 simulator or device. Location and camera recording must ultimately be verified on a physical iPhone.

## Gotchas

- Google Maps URLs cannot preserve every recorded route point; GPX is the fidelity-preserving export.
- GPX exports include plugin-friendly extensions for duration, mode, video presence, accuracy, and optional speed while remaining readable by generic GPX tools.
- GPS background recording is supported only when the user enables it and grants Always location permission.
- Camera, microphone, and location usage descriptions must be configured before their APIs are requested.
- Photos save/playback needs `NSPhotoLibraryAddUsageDescription` and `NSPhotoLibraryUsageDescription`; source code guards against missing keys, but device testing requires the target settings.
- Background GPS recording needs `NSLocationAlwaysAndWhenInUseUsageDescription` and `UIBackgroundModes` containing `location`.
- DockKit support is guarded with `#if canImport(DockKit)` so local SDKs without the framework still build; real accessory behavior must be verified on an iPhone and SDK that expose DockKit.
- The Video Walk tab requests a landscape scene geometry and restores portrait when leaving; the target must continue supporting landscape orientations.
- Disable the idle timer only while video recording is active, not for GPS-only walks.
- Confirm that a video file exists before saving a video walk record; incomplete video sessions should not appear in history.
- Route points need accuracy and distance filtering before they affect distance totals or persistence.
