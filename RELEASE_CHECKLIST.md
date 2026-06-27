# ASMR Walk Release Checklist

Use this before uploading `1.0` to App Store Connect.

## Required Target Settings

- [ ] Bundle identifier is final.
- [ ] Version is `1.0`.
- [ ] Build number is incremented for every upload.
- [ ] Generated launch screen is enabled.
- [ ] App icon is configured.
- [ ] Supported iPhone orientations include portrait and landscape. The app locks Video Walk to landscape-right at runtime.
- [ ] Privacy strings are present in the generated target Info settings:
  - [ ] `NSLocationWhenInUseUsageDescription`
  - [ ] `NSLocationAlwaysAndWhenInUseUsageDescription`
  - [ ] `NSCameraUsageDescription`
  - [ ] `NSMicrophoneUsageDescription`
  - [ ] `NSPhotoLibraryAddUsageDescription`
  - [ ] `NSPhotoLibraryUsageDescription`
- [ ] Confirm the generated Info settings, not just `ASMR-Walk-Info.plist`, contain the privacy strings used at runtime.

## Build And Test

- [ ] Run a clean Release build.
- [ ] Run unit tests.
- [ ] Run UI tests.
- [ ] Confirm the native launch screen appears correctly.
- [ ] Confirm there is no artificial in-app splash delay after launch.
- [ ] Confirm Settings tab opens.
- [ ] Confirm Light, Dark, and System theme settings apply app-wide.
- [ ] Confirm Background GPS Recording defaults off.
- [ ] Confirm About sheet shows app name, version, build, and `heathdj@me.com`.

## Device Validation

Run these on a physical iPhone before submission:

- [ ] Start and save a GPS-only walk.
- [ ] Stop a GPS-only walk before 10 seconds and confirm Save/Discard behavior.
- [ ] Deny location permission and confirm the app shows a Settings recovery button.
- [ ] Background the app during a walk and confirm the foreground-only recording behavior is acceptable.
- [ ] Enable Background GPS Recording, grant Always location permission, lock the screen during a GPS walk, and confirm the route continues.
- [ ] Enable Background GPS Recording but deny Always location permission, then confirm the app explains the permission requirement and does not pretend to record in the background.
- [ ] Confirm Walk map opens near the user's current location at street level.
- [ ] Confirm Walk map shows the facing-direction indicator when heading data is available.
- [ ] Cold launch the app in light and dark appearance and confirm the native launch screen transitions directly to History.
- [ ] Open Video Walk and confirm the tab is landscape-only, never portrait.
- [ ] Start and save a video walk.
- [ ] Stop a video walk before 10 seconds and confirm Save/Discard behavior.
- [ ] Confirm the screen stays awake only while video recording is active.
- [ ] Confirm the small green recording indicator appears while video recording.
- [ ] Confirm the camera preview is live when returning to the Video Walk tab.
- [ ] Confirm the saved video appears in Photos.
- [ ] Confirm the recording stores a Photos asset reference and playback loads from Photos.
- [ ] Confirm legacy/local video fallback still works for older recordings if available.
- [ ] Deny camera or microphone permission and confirm the app shows a Settings recovery button.
- [ ] Deny Photos permission and confirm video recording fails gracefully or falls back without crashing.
- [ ] Open a saved video walk and confirm playback plus route overlay works.
- [ ] Delete a video walk and confirm the app recording is removed. Photos-library videos are user-owned and should remain in Photos unless a separate delete-from-Photos feature is added.
- [ ] Export a Google Maps URL.
- [ ] Export a GPX file through the share sheet.
- [ ] Inspect an exported GPX file and confirm ASMR Walk extensions include duration, recording mode, `hasVideo`, recording ID, horizontal accuracy, and speed when available.
- [ ] Confirm exported GPX does not include local sandbox video URLs.

## App Store Connect

- [ ] Complete privacy nutrition labels for foreground/background location, camera, microphone, Photos, and user-generated content.
- [ ] Confirm the app describes background GPS recording as optional and user-enabled.
- [ ] Include screenshots for History, Walk, Video Walk, Recording Detail, and Settings.
- [ ] Mention that route data is stored locally.
- [ ] Mention that video walks are saved to the user's Photos library.
- [ ] Review export behavior: Google Maps is a quick route share, GPX is the full-fidelity route export with optional ASMR Walk metadata extensions.

## Known Version 1 Scope

- No iCloud sync.
- No Apple Watch support.
- No HealthKit workout integration.
- Background route recording is GPS-only and opt-in.
- No burned-in video map overlay export.
- No delete-from-Photos management for videos saved to the user's Photos library.
