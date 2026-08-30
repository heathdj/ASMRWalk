# ASMR Walk

ASMR Walk is an iPhone walking journal with an Apple Watch companion recorder. It records GPS walking routes, can pair a route with a walk video, syncs recording metadata and route data through iCloud, keeps videos local, and exports routes for use outside the app.

## Version 1.1.0 Scope

ASMR Walk 1.1.0 uses the user's private iCloud account to sync recording metadata and route data. It supports iPhone GPS Walk recordings, iPhone Video Walk recordings, Apple Watch GPS-only recordings, optional background GPS for iPhone GPS Walk only, local video storage with user-initiated Photos export, synced history metadata/routes, route thumbnails, generated place-based recording details, external-camera timing metadata for Watch routes, and route export. It does not include iPad support, HealthKit, analytics, developer-operated accounts, advertising, developer-operated storage, or a developer-operated backend.

iCloud library sync is not gated by a StoreKit subscription in this implementation; it is available when the user is signed in to iCloud and CloudKit is available.

## Current Features

- History tab for saved walk recordings.
- GPS-only walk recording with a live MapKit route overlay.
- Optional background GPS recording for GPS-only walks, gated by a Settings toggle and Always location permission.
- Video walk recording with camera preview, microphone audio, landscape-first UI, and live route overlay.
- Apple Watch GPS-only recording with live elapsed time, distance, route-point count, GPS status, save, and discard controls.
- Saved video walk playback with a synchronized route-progress map overlay.
- SwiftData persistence with private iCloud sync for recording metadata and route points.
- Recording detail screens with editable titles and descriptions, route maps, duration, distance, route-point counts, and video indicators.
- Watch recording source labels in iPhone History and Recording Detail.
- External-camera timing fields for Watch recordings so separately captured footage can be aligned later.
- Settings iCloud status so users can see whether their private iCloud account is available for library sync.
- Generated route thumbnails for saved walks in History, detail views, and GPX share previews.
- Best-effort place metadata generation after saving a walk, with fallback date/time titles when lookup is unavailable.
- Delete support for saved recordings. App-managed video and thumbnail files are removed with their recording; any user-saved Photos copies remain in Photos.
- Route export through the iOS share sheet.
- Google Maps walking-route URL export.
- GPX file export for higher-fidelity route sharing, including recording descriptions when present.
- `.asmrroute` package contract for future Mac importer and Final Cut Pro/Motion route overlay workflows.
- GPX-to-`.asmrroute` importer core and macOS importer shell source for the planned Mac utility.
- Video files remain local to the device where they were recorded unless the user saves a copy to Photos.

## Tech Stack

- SwiftUI for the app UI.
- SwiftData for local persistence.
- CloudKit for private iCloud sync of recording metadata and route data.
- MapKit for live and saved route maps.
- Core Location for GPS tracking.
- AVFoundation for video and microphone capture.
- watchOS SwiftUI for the Apple Watch companion recorder.
- Swift Testing for unit tests.
- XCTest / XCUIAutomation for UI tests.

## Project Structure

```text
ASMR Walk/
  ASMR Walk/
    Features/
      History/   Saved recordings, details, route maps, and exports
      Video/     Camera preview, video capture, landscape video-walk UI
      Walk/      GPS recording flow and route session logic
    Models/      SwiftData models and presentation helpers
  ASMRWalk Watch App/
    Features/Recording/   Watch GPS recorder, session, and persistence
    Models/               Watch-side SwiftData models
```

## Requirements

- Xcode with iOS 26 SDK support.
- iOS 26 iPhone simulator or physical iPhone.
- watchOS simulator or physical Apple Watch for the companion app.
- A physical iPhone is recommended for final GPS, camera, and microphone validation.
- A paired physical Apple Watch and iPhone are required to validate Watch GPS recording and Watch-to-iPhone iCloud sync before App Store submission.
- An iCloud account and CloudKit-capable provisioning are required to validate sync across devices.
- iPad support is out of scope until the app receives a full adaptive-layout pass.

## Setup

Open the project in Xcode and select the `ASMR Walk` scheme.

Before running recording features, confirm the app target includes these generated Info properties:

- `Privacy - Location When In Use Usage Description`
- `Privacy - Location Always and When In Use Usage Description`
- `Privacy - Camera Usage Description`
- `Privacy - Microphone Usage Description`
- `Background Modes`: Location updates and Remote notifications
- `iCloud`: CloudKit with container `iCloud.com.bald-traveler.ASMRWalk`

The Watch app target should use the same CloudKit container and include a Watch location usage description. Watch recording asks for location access when the user starts a Watch walk.

Expected privacy strings:

| Key | Value |
| --- | --- |
| `NSLocationWhenInUseUsageDescription` | ASMR Walk uses your location while recording to draw and save your walking route. |
| `NSLocationAlwaysAndWhenInUseUsageDescription` | ASMR Walk uses background location only when you enable background GPS recording for walks. |
| `NSCameraUsageDescription` | ASMR Walk uses the camera to record video walks. |
| `NSMicrophoneUsageDescription` | ASMR Walk uses the microphone to record video walks. |
| `NSPhotoLibraryAddUsageDescription` | ASMR Walk saves a copy of a video walk to Photos when you choose Save Video to Photos. |
| `NSPhotoLibraryUsageDescription` | ASMR Walk reads older Photos-backed video walks so you can replay them with your route. |

iOS will terminate the app if camera or microphone capture is requested without those usage-description keys.

See `RELEASE_CHECKLIST.md` before uploading to App Store Connect.

Finished video walks are kept in ASMR Walk's app-managed storage for playback. iCloud sync carries the recording details and route, not the `.mov` file. From a video walk's History detail screen, the user can save a copy to Photos. Deleting an ASMR Walk recording removes the route, app metadata, and app-managed video file on that device, but it does not delete any Photos copy the user saved.

Apple Watch recordings are GPS-only route recordings. They sync through private iCloud as recording metadata and route points, then appear in iPhone History with an Apple Watch source label. Watch recordings do not include video. If the walk used a separate external camera, the iPhone detail screen can store the external clip label and start time so GPX export carries alignment metadata without importing or syncing the video file.

## Privacy

ASMR Walk does not include developer-operated accounts, analytics, advertising, or backend upload code. Route data and recording metadata may sync through the user's private iCloud database. Video files stay on the recording device unless the user saves video to Photos or explicitly exports or shares a route. After saving, ASMR Walk may ask Apple's MapKit services for map imagery and a place name so it can generate a route thumbnail and suggest a useful title and description.

See `PRIVACY_POLICY.md` for the public privacy-policy source. Before App Store submission, publish that policy at a stable URL and enter the URL in App Store Connect.

## Running

1. Open the project in Xcode.
2. Select an iPhone simulator or physical iPhone.
3. Run the `ASMR Walk` scheme.
4. For simulator route testing, choose a simulated location or GPX route in Xcode.

The Video Walk tab requests landscape orientation when opened and restores portrait when leaving. The target must continue supporting landscape orientations for that behavior to work.

Background GPS recording requires the `location` background mode, the Background GPS Recording setting, and Always location permission. It applies only to GPS-only walks; Video Walk recordings remain foreground-only and stop when the app leaves the foreground.

iCloud sync requires the CloudKit entitlement, the `iCloud.com.bald-traveler.ASMRWalk` container, and the `remote-notification` background mode. Sync uses the user's private iCloud database and may be temporarily unavailable when the device is signed out of iCloud or iCloud is restricted.

Watch-to-iPhone sync can be unreliable in Simulator and is treated as non-authoritative for release validation. Complete the physical-device validation tracked in GitHub issue #93 before submitting version 1.1.0 to the App Store.

## Testing

Use Xcode's test action for the `ASMR Walk` scheme.

The unit test suite covers:

- Tab metadata.
- SwiftData recording lifecycle.
- Generated and editable recording metadata.
- Route thumbnail path and persistence helpers.
- iCloud sync configuration and account-status presentation.
- Apple Watch recording session filtering, persistence, UI-facing state, and route metadata.
- GPS route filtering and distance accumulation.
- Video-walk recording metadata.
- Google Maps route export.
- GPX route export.

UI tests cover the main tab surfaces and launch behavior. Camera, microphone, outdoor GPS, and Watch-to-iPhone sync flows should be validated on physical devices after privacy keys and entitlements are configured.

The app uses a native static launch screen configured through the target Info settings. It does not show an artificial SwiftUI splash screen after launch.

## ASMR Route Packages

The `.asmrroute` package format is documented in `ASMR_ROUTE_PACKAGE.md`. Version 1 packages contain a deterministic `manifest.json`, normalized `route-points.json`, and optional preserved `source.gpx`. They are designed as the stable handoff from ASMR Walk import workflows to future Final Cut Pro/Motion rendering without requiring the renderer to query iCloud, Photos, or an iPhone sandbox.

The GPX importer core and initial macOS SwiftUI shell live under `ASMR Walk Mac Importer`. The macOS target requires owner setup in Xcode; see `MAC_IMPORTER_OWNER_INSTRUCTIONS.md`.

## Current Limitations

- Exported Google Maps URLs sample waypoints; GPX remains the complete route export.
- The map overlay is rendered in the app and is not burned into exported video.
- Video Walk does not continue recording in the background.
- iCloud sync does not sync full video files; videos remain on the recording device unless the user saves or shares a copy.
- Apple Watch recordings are GPS-only and do not record video or HealthKit workouts.
- Watch-to-iPhone sync needs physical-device/TestFlight validation before App Store submission because Simulator sync has not been reliable.
- iPad and HealthKit are not part of version 1.1.0.

## Roadmap

These are future ideas, not shipped 1.1.0 features:

- HealthKit workout integration.
- Burned-in video map overlay export.
- Shared route/model package for future iPhone, Watch, Mac importer, and Final Cut Pro plugin reuse.
