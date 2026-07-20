# ASMR Walk Release Checklist

Use this before uploading `1.0.1` to App Store Connect.

## Required Target Settings

- [ ] Bundle identifier is final.
- [ ] Version is `1.0.1`.
- [ ] Build number is incremented for every upload.
- [ ] Generated launch screen is enabled.
- [ ] App icon is configured.
- [ ] Targeted device family is iPhone only for version 1.0.1.
- [ ] Supported iPhone orientations include portrait and landscape. The app locks Video Walk to landscape-right at runtime.
- [ ] Privacy strings are present in the generated target Info settings:
  - [ ] `NSLocationWhenInUseUsageDescription`
  - [ ] `NSLocationAlwaysAndWhenInUseUsageDescription`
  - [ ] `NSCameraUsageDescription`
  - [ ] `NSMicrophoneUsageDescription`
  - [ ] `NSPhotoLibraryAddUsageDescription`
  - [ ] `NSPhotoLibraryUsageDescription`
- [ ] Confirm the generated Info settings, not just `ASMR-Walk-Info.plist`, contain the privacy strings used at runtime.
- [ ] Confirm archived `Info.plist` Photos add text explains user-initiated Save Video to Photos.
- [ ] Confirm archived `Info.plist` Photos read text explains replaying older Photos-backed video walks with routes.
- [ ] Confirm archived `Info.plist` location, camera, microphone, and Photos strings use sentence case and ending punctuation.

## Build And Test

- [ ] Run a clean Release build.
- [ ] Archive the app and generate Xcode's privacy report from the archive.
- [ ] Confirm the privacy report shows no tracking and no app-declared collected data.
- [ ] Run unit tests.
- [ ] Run UI tests.
- [ ] Run UI tests on a clean simulator and confirm onboarding state is seeded by launch environment, not retained defaults.
- [ ] Confirm the native launch screen appears correctly.
- [ ] Confirm there is no artificial in-app splash delay after launch.
- [ ] Confirm Settings tab opens.
- [ ] Confirm Light, Dark, and System theme settings apply app-wide.
- [ ] Confirm Walk, Video Walk, active recording banner, History, and Settings remain usable in light and dark appearance.
- [ ] Confirm Walk and Video Walk keep essential controls visible at accessibility Dynamic Type sizes.
- [ ] Confirm Walk and Video Walk keep essential controls visible with Button Shapes enabled.
- [ ] Confirm Walk and Video Walk keep essential controls visible with Reduce Transparency enabled.
- [ ] Confirm Walk and Video Walk keep essential controls visible with Increase Contrast enabled.
- [ ] Confirm Background GPS Recording defaults off.
- [ ] Confirm Background GPS Recording is described as optional, user-enabled, and GPS Walk only.
- [ ] Confirm documentation and App Store copy do not imply background video recording.
- [ ] Confirm About sheet shows app name, version, build, and `heathdj@me.com`.

## Device Validation

Run these on a physical iPhone before submission:

### Physical Device Only

- [ ] Start and save a GPS-only walk.
- [ ] Stop a GPS-only walk before 10 seconds and confirm Save/Discard behavior.
- [ ] Deny location permission and confirm the app shows a Settings recovery button.
- [ ] Background the app during a walk and confirm the foreground-only recording behavior is acceptable.
- [ ] Enable Background GPS Recording, grant Always location permission, lock the screen during a GPS walk, and confirm the route continues.
- [ ] Enable Background GPS Recording but deny Always location permission, then confirm the app explains the permission requirement and does not pretend to record in the background.
- [ ] Enable Background GPS Recording, start a Video Walk, background the app, and confirm Video Walk stops instead of continuing background GPS/video capture.
- [ ] Disable Background GPS Recording, start a GPS-only walk, background the app, and confirm the walk finalizes instead of continuing in the background.
- [ ] Record a long GPS route on device and confirm repeated checkpoints do not create duplicates or noticeably increase battery/database cost as the route grows.
- [ ] Confirm Walk map opens near the user's current location at street level.
- [ ] Confirm Walk map shows the facing-direction indicator when heading data is available.
- [ ] Cold launch the app in light and dark appearance and confirm the native launch screen transitions directly to History.
- [ ] Open Video Walk and confirm the tab is landscape-only, never portrait.
- [ ] Inspect Video Walk in landscape with accessibility Dynamic Type sizes and confirm the square route map does not overlap the REC indicator, status card, or start control.
- [ ] Start and save a video walk.
- [ ] Stop a video walk before 10 seconds and confirm Save/Discard behavior.
- [ ] Confirm the screen stays awake only while video recording is active.
- [ ] Confirm the small green recording indicator appears while video recording.
- [ ] Open Video Walk before granting camera or microphone permission and confirm the tab does not trigger system prompts.
- [ ] Grant camera and microphone permission, return to Video Walk, and confirm the live camera preview starts automatically.
- [ ] Confirm the camera preview is live when returning to the Video Walk tab.
- [ ] Confirm DockKit shutter can start a video walk after returning to the Video Walk tab.
- [ ] Confirm the saved video walk remains playable from app-managed local storage.
- [ ] From History detail, tap Save Video to Photos and confirm a copy appears in Photos.
- [ ] Confirm playback still loads from the local app-managed video after saving a Photos copy.
- [ ] Confirm legacy Photos-backed video playback still works for older recordings if available.
- [ ] Confirm delete messaging states app-managed local video files are removed with their recording.
- [ ] Confirm delete messaging states any user-saved Photos copy remains in Photos.
- [ ] Deny camera or microphone permission and confirm the app shows a Settings recovery button.
- [ ] Deny Photos permission and confirm Save Video to Photos fails gracefully without affecting local playback.
- [ ] Run VoiceOver through Walk, Video Walk, and the active recording banner and confirm recording state is understandable without relying on color.
- [ ] Run Accessibility Inspector on Walk, Video Walk, History, and Settings. Resolve or document any remaining issues.
- [ ] Open a saved video walk and confirm playback plus route overlay works.
- [ ] Delete a video walk and confirm the app recording and local video file are removed. User-saved Photos copies should remain in Photos unless a separate delete-from-Photos feature is added.
- [ ] Export a Google Maps URL.
- [ ] Export a GPX file through the share sheet.
- [ ] Inspect an exported GPX file and confirm ASMR Walk extensions include duration, recording mode, `hasVideo`, recording ID, horizontal accuracy, and speed when available.
- [ ] Confirm exported GPX does not include local sandbox video URLs.

### Automated Coverage Gate

- [ ] Confirm Swift Testing covers permission policy, permission recovery after Settings changes, Always authorization upgrade requests, concurrent recording prevention, GPS/video scene transition policy, video stop outcomes through the coordinator flow, local video storage semantics, Photos export/legacy fallback semantics, checkpoint recovery, and large-route persistence.
- [ ] Confirm XCUI tests cover first-launch onboarding, returning-user launch, permission recovery surfaces, active-recording cross-tab behavior, and accessibility QA surfaces with deterministic launch environment hooks.

## App Store Connect

- [ ] Publish `PRIVACY_POLICY.md` at a public, stable URL.
- [ ] Enter the public privacy-policy URL in App Store Connect.
- [ ] Complete App Privacy answers from actual off-device collection, not simply from protected APIs used on device.
- [ ] Confirm ASMR Walk does not collect data on developer-operated servers in version 1.
- [ ] Confirm App Privacy answers disclose no tracking.
- [ ] Confirm App Privacy answers do not mark locally stored routes, videos, Photos references, camera input, microphone input, or location as developer-collected data unless a future upload, analytics, sync, or backend feature is added.
- [ ] Document network behavior: no direct app-owned network calls, no analytics SDK, no account backend, no CloudKit sync.
- [ ] Document user-initiated sharing: GPX exports and Google Maps route links may send route data to the user's chosen share destination.
- [ ] Document Apple framework behavior separately: Photos may use iCloud Photos for copies the user saves or older Photos-backed videos.
- [ ] Confirm the app describes background GPS recording as optional and user-enabled.
- [ ] Confirm App Store copy says ASMR Walk 1.0.1 is iPhone-only.
- [ ] Include review notes that background location is GPS Walk only, requires the user to enable Background GPS Recording in Settings, and requires Always location permission.
- [ ] Include screenshots for History, Walk, Video Walk, Recording Detail, and Settings.
- [ ] Mention that route data is stored locally.
- [ ] Mention that video walks are stored locally in ASMR Walk by default.
- [ ] Mention that users can save a copy of a video walk to Photos from History detail.
- [ ] Mention that deleting an ASMR Walk recording removes the app-managed local video but does not delete user-saved Photos copies.
- [ ] Review export behavior: Google Maps is a quick route share, GPX is the full-fidelity route export with optional ASMR Walk metadata extensions.
- [ ] Revisit App Privacy answers before every release that adds analytics, crash reporting SDKs, iCloud sync, accounts, remote storage, or any other off-device collection.

## Known Version 1.0.1 Scope

- No iCloud sync.
- No iPad support.
- No Apple Watch support.
- No HealthKit workout integration.
- Background route recording is GPS-only and opt-in.
- No background Video Walk recording.
- No burned-in video map overlay export.
- No delete-from-Photos management for video copies saved to the user's Photos library.
