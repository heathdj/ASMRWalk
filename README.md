# ASMR Walk

ASMR Walk is an iPhone walking journal built with SwiftUI. It records GPS walking routes, can pair a route with a walk video, stores recordings locally with SwiftData, and exports routes for use outside the app.

## Current Features

- History tab for saved walk recordings.
- GPS-only walk recording with a live MapKit route overlay.
- Optional background GPS recording for GPS-only walks, gated by Always location permission.
- Video walk recording with camera preview, microphone audio, landscape-first UI, and live route overlay.
- Saved video walk playback with a synchronized route-progress map overlay.
- Local persistence with SwiftData.
- Recording detail screens with route maps, duration, distance, route-point counts, and video indicators.
- Delete support for saved recordings, with Photos videos left in Photos and app-managed fallback video files cleaned up.
- Route export through the iOS share sheet.
- Google Maps walking-route URL export.
- GPX file export for higher-fidelity route sharing.

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
- Version 1 is intentionally iPhone-only; iPad support is out of scope until the app receives a full adaptive-layout pass.

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
| `NSPhotoLibraryAddUsageDescription` | ASMR Walk saves finished video walks to Photos so they remain available outside the app. |
| `NSPhotoLibraryUsageDescription` | ASMR Walk reads saved video walks from Photos so you can replay them with your route. |

iOS will terminate the app if camera or microphone capture is requested without those usage-description keys.

See `RELEASE_CHECKLIST.md` before uploading to App Store Connect.

Finished video walks are saved to the user's Photos library when Photos access is available. Deleting an ASMR Walk recording removes the route and app metadata, but it does not delete the Photos video; older app-managed fallback video files are deleted with their recording.

## Running

1. Open the project in Xcode.
2. Select an iPhone simulator or physical iPhone.
3. Run the `ASMR Walk` scheme.
4. For simulator route testing, choose a simulated location or GPX route in Xcode.

The Video Walk tab requests landscape orientation when opened and restores portrait when leaving. The target must continue supporting landscape orientations for that behavior to work.

Background GPS recording requires the `location` background mode and Always location permission. It applies only to GPS-only walks, even when the Settings toggle is enabled; video walks still stop when the app leaves the foreground.

## Testing

Use Xcode's test action for the `ASMR Walk` scheme.

The unit test suite covers:

- Tab metadata.
- SwiftData recording lifecycle.
- GPS route filtering and distance accumulation.
- Video-walk recording metadata.
- Google Maps route export.
- GPX route export.

UI tests cover the main tab surfaces and launch behavior. Camera and microphone flows should be validated on a real device after privacy keys are configured.

The app uses a native static launch screen configured through the target Info settings. It does not show an artificial SwiftUI splash screen after launch.

## Current Limitations

- Exported Google Maps URLs sample waypoints; GPX remains the complete route export.
- The map overlay is rendered in the app and is not burned into exported video.

## Roadmap

- iCloud sync.
- Route thumbnails.
- HealthKit workout integration.
- Apple Watch companion recording.
- Burned-in video map overlay export.
