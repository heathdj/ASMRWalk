# ASMR Walk

ASMR Walk is an iPhone walking journal built with SwiftUI. It records GPS walking routes, can pair a route with a walk video, stores recordings locally with SwiftData, and exports routes for use outside the app.

## Version 1.1.0 Scope

ASMR Walk 1.1.0 is intentionally iPhone-only and local-first. It supports GPS Walk recordings, Video Walk recordings, optional background GPS for GPS Walk only, local video storage with user-initiated Photos export, local history, generated place-based recording details, and route export. It does not include iPad support, Apple Watch, HealthKit, iCloud sync, analytics, accounts, advertising, or a developer-operated backend.

## Current Features

- History tab for saved walk recordings.
- GPS-only walk recording with a live MapKit route overlay.
- Optional background GPS recording for GPS-only walks, gated by a Settings toggle and Always location permission.
- Video walk recording with camera preview, microphone audio, landscape-first UI, and live route overlay.
- Saved video walk playback with a synchronized route-progress map overlay.
- Local persistence with SwiftData.
- Recording detail screens with editable titles and descriptions, route maps, duration, distance, route-point counts, and video indicators.
- Best-effort place metadata generation after saving a walk, with fallback date/time titles when lookup is unavailable.
- Delete support for saved recordings. App-managed video files are removed with their recording; any user-saved Photos copies remain in Photos.
- Route export through the iOS share sheet.
- Google Maps walking-route URL export.
- GPX file export for higher-fidelity route sharing, including recording descriptions when present.

## Tech Stack

- SwiftUI for the app UI.
- SwiftData for local persistence.
- MapKit for live and saved route maps.
- Core Location for GPS tracking.
- AVFoundation for video and microphone capture.
- Swift Testing for unit tests.
- XCTest / XCUIAutomation for UI tests.

## Project Structure

```text
ASMR Walk/
  Features/
    History/   Saved recordings, details, route maps, and exports
    Video/     Camera preview, video capture, landscape video-walk UI
    Walk/      GPS recording flow and route session logic
  Models/      SwiftData models and presentation helpers
```

## Requirements

- Xcode with iOS 26 SDK support.
- iOS 26 iPhone simulator or physical iPhone.
- A physical iPhone is recommended for final GPS, camera, and microphone validation.
- Version 1.1.0 is intentionally iPhone-only; iPad support is out of scope until the app receives a full adaptive-layout pass.

## Setup

Open the project in Xcode and select the `ASMR Walk` scheme.

Before running recording features, confirm the app target includes these generated Info properties:

- `Privacy - Location When In Use Usage Description`
- `Privacy - Location Always and When In Use Usage Description`
- `Privacy - Camera Usage Description`
- `Privacy - Microphone Usage Description`

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

Finished video walks are kept in ASMR Walk's app-managed storage for playback. From a video walk's History detail screen, the user can save a copy to Photos. Deleting an ASMR Walk recording removes the route, app metadata, and app-managed video file, but it does not delete any Photos copy the user saved.

## Privacy

ASMR Walk is local-first. The app does not include developer-operated accounts, analytics, advertising, sync, or backend upload code. Route data, recording metadata, and video references stay on the device unless the user saves video to Photos or explicitly exports or shares a route. After saving, ASMR Walk may ask Apple's MapKit reverse-geocoding service for a place name so it can suggest a useful title and description.

See `PRIVACY_POLICY.md` for the public privacy-policy source. Before App Store submission, publish that policy at a stable URL and enter the URL in App Store Connect.

## Running

1. Open the project in Xcode.
2. Select an iPhone simulator or physical iPhone.
3. Run the `ASMR Walk` scheme.
4. For simulator route testing, choose a simulated location or GPX route in Xcode.

The Video Walk tab requests landscape orientation when opened and restores portrait when leaving. The target must continue supporting landscape orientations for that behavior to work.

Background GPS recording requires the `location` background mode, the Background GPS Recording setting, and Always location permission. It applies only to GPS-only walks; Video Walk recordings remain foreground-only and stop when the app leaves the foreground.

## Testing

Use Xcode's test action for the `ASMR Walk` scheme.

The unit test suite covers:

- Tab metadata.
- SwiftData recording lifecycle.
- Generated and editable recording metadata.
- GPS route filtering and distance accumulation.
- Video-walk recording metadata.
- Google Maps route export.
- GPX route export.

UI tests cover the main tab surfaces and launch behavior. Camera and microphone flows should be validated on a real device after privacy keys are configured.

The app uses a native static launch screen configured through the target Info settings. It does not show an artificial SwiftUI splash screen after launch.

## Current Limitations

- Exported Google Maps URLs sample waypoints; GPX remains the complete route export.
- The map overlay is rendered in the app and is not burned into exported video.
- Video Walk does not continue recording in the background.
- iPad, Apple Watch, HealthKit, and iCloud sync are not part of version 1.1.0.

## Roadmap

These are future ideas, not shipped 1.1.0 features:

- iCloud sync.
- Route thumbnails.
- HealthKit workout integration.
- Apple Watch companion recording.
- Burned-in video map overlay export.
