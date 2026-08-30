# ASMR Walk Release Checklist

Use this before uploading `1.1.0` to App Store Connect.

## Required Target Settings

- [ ] Bundle identifier is final.
- [ ] Version is `1.1.0`.
- [ ] Build number is incremented for every upload.
- [ ] Generated launch screen is enabled.
- [ ] App icon is configured.
- [ ] iPhone app targeted device family excludes iPad for version 1.1.0.
- [ ] Apple Watch companion app target is included in the archive.
- [ ] Apple Watch app icon is configured and visually matches the iPhone app icon.
- [ ] Supported iPhone orientations include portrait and landscape. The app locks Video Walk to landscape-right at runtime.
- [ ] iCloud capability is enabled with CloudKit container `iCloud.com.bald-traveler.ASMRWalk`.
- [ ] Watch app iCloud capability is enabled with CloudKit container `iCloud.com.bald-traveler.ASMRWalk`.
- [ ] Confirm iCloud library sync is not StoreKit-gated in this release; if product direction changes to Pro/subscription, add entitlement gating before release.
- [ ] Background Modes includes both Location updates and Remote notifications.
- [ ] Watch app has a location usage description for GPS-only Watch recording.
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
- [ ] Confirm archived `Info.plist` includes `UIBackgroundModes` values for `location` and `remote-notification`.
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
- [ ] Confirm Settings shows the current iCloud Library status.
- [ ] Confirm documentation and App Store copy do not imply background video recording.
- [ ] Confirm documentation and App Store copy describe the Apple Watch app as GPS-only.
- [ ] Confirm documentation and App Store copy do not imply HealthKit workout recording.
- [ ] Confirm documentation and App Store copy explain Watch-to-iPhone sync uses the user's private iCloud database.
- [ ] Confirm documentation and App Store copy explain external-camera timing stores metadata only and does not import or sync external video files.
- [ ] Confirm About sheet shows app name, version, build, and `heathdj@me.com`.

## Device Validation

Run these on physical devices before submission:

### Physical Device Only

- [ ] Start and save a GPS-only walk.
- [ ] Sign in to the same iCloud account on two devices, create a GPS-only walk on one device, and confirm the recording appears on the other.
- [ ] Confirm synced route points remain intact and draw correctly on the second device.
- [ ] Edit a synced recording title and description on one device and confirm the updated metadata appears on the other device.
- [ ] Confirm a saved GPS-only walk receives a route thumbnail in History and on the detail screen.
- [ ] Confirm route thumbnails are regenerated on devices where the local thumbnail file is missing.
- [ ] Confirm a saved video walk receives a route thumbnail while local video playback still works.
- [ ] Create a Video Walk on one device and confirm another synced device shows the route/details while explaining that the video file is not on that device.
- [ ] Confirm thumbnail generation failures leave the recording saved and usable.
- [ ] Confirm a saved GPS-only walk receives a useful place-based title and editable description when MapKit reverse geocoding succeeds.
- [ ] Confirm a saved walk keeps its fallback date/time title when place lookup fails or returns no usable place name.
- [ ] Edit a saved recording title and description from History detail, leave and reopen the detail screen, and confirm the edits persist.
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
- [ ] On a supported physical iPhone, confirm Video Walk recording uses video stabilization (`activeVideoStabilizationMode` is not `.off`) while saved video orientation remains correct.
- [ ] Confirm Video Walk stabilization field-of-view crop and low-light quality remain acceptable.
- [ ] Confirm the screen stays awake only while video recording is active.
- [ ] Confirm the small green recording indicator appears while video recording.
- [ ] Open Video Walk before granting camera or microphone permission and confirm the tab does not trigger system prompts.
- [ ] Grant camera and microphone permission, return to Video Walk, and confirm the live camera preview starts automatically.
- [ ] Confirm the camera preview is live when returning to the Video Walk tab.
- [ ] Confirm DockKit shutter can start a video walk after returning to the Video Walk tab and DockKit zoom still behaves correctly while stabilization is enabled.
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
- [ ] Delete a recording with a route thumbnail and confirm the app-managed thumbnail file is removed.
- [ ] Export a Google Maps URL.
- [ ] Export a GPX file through the share sheet.
- [ ] Inspect an exported GPX file and confirm ASMR Walk extensions include duration, recording mode, `hasVideo`, recording ID, horizontal accuracy, and speed when available.
- [ ] Inspect an exported GPX file for a described recording and confirm `<desc>` and `asmrwalk:description` include the editable recording description.
- [ ] Confirm exported GPX does not include local sandbox video URLs.
- [ ] Sign out of iCloud or use a restricted iCloud account and confirm Settings explains the sync state without blocking local recording.
- [ ] Confirm CloudKit schema is initialized in development and promoted before production release.

### Apple Watch Physical Device Gate

- [ ] Confirm GitHub issue #93 is closed before submitting version 1.1.0 to App Store Connect.
- [ ] Install the iPhone app and Apple Watch app on paired physical devices.
- [ ] Confirm the iPhone and Apple Watch are signed into the expected iCloud account and iCloud sync is available.
- [ ] Grant location permission to ASMR Walk on Apple Watch.
- [ ] Start a GPS-only walk from Apple Watch and confirm elapsed time, distance, route-point count, and GPS status update during the walk.
- [ ] Stop and save the Watch walk.
- [ ] Confirm the Watch shows the saved/sync-pending state after save.
- [ ] Confirm the saved Watch recording appears in iPhone History after iCloud sync.
- [ ] Confirm the iPhone History row and detail screen identify the recording as Apple Watch sourced.
- [ ] Confirm synced Watch route points draw correctly on iPhone and summary distance/duration are preserved.
- [ ] Confirm a local route thumbnail is generated or regenerated on iPhone for the synced Watch recording.
- [ ] Confirm the synced Watch recording does not imply a video file exists.
- [ ] Add external-camera timing metadata to a synced Watch recording on iPhone.
- [ ] Export GPX for the synced Watch recording and confirm it includes recording source, route timing, and external-camera timing metadata.
- [ ] Record any sync delay, entitlement, iCloud account, or permission findings in the release notes for issue #71.

### Automated Coverage Gate

- [ ] Confirm Swift Testing covers permission policy, permission recovery after Settings changes, Always authorization upgrade requests, concurrent recording prevention, GPS/video scene transition policy, video stop outcomes through the coordinator flow, local video storage semantics, Photos export/legacy fallback semantics, checkpoint recovery, large-route persistence, iCloud configuration, sync status messaging, and local-only video presentation.
- [ ] Confirm XCUI tests cover first-launch onboarding, returning-user launch, permission recovery surfaces, active-recording cross-tab behavior, and accessibility QA surfaces with deterministic launch environment hooks.

## App Store Connect

- [ ] Publish `PRIVACY_POLICY.md` at a public, stable URL.
- [ ] Enter the public privacy-policy URL in App Store Connect.
- [ ] Complete App Privacy answers from actual off-device collection, not simply from protected APIs used on device.
- [ ] Confirm ASMR Walk does not collect data on developer-operated servers in version 1.1.0.
- [ ] Confirm App Privacy answers disclose no tracking.
- [ ] Confirm App Privacy answers distinguish user-private iCloud sync from developer-operated collection.
- [ ] Confirm App Privacy answers do not mark videos, Photos references, camera input, microphone input, or location as developer-collected data unless a future upload, analytics, or developer-operated backend feature is added.
- [ ] Document network behavior: no direct app-owned analytics calls, no account backend, no advertising SDK, and no developer-operated storage.
- [ ] Document iCloud behavior: recording metadata and route data sync through the user's private iCloud database; full video files do not sync through ASMR Walk.
- [ ] Document user-initiated sharing: GPX exports and Google Maps route links may send route data to the user's chosen share destination.
- [ ] Document Apple framework behavior separately: Photos may use iCloud Photos for copies the user saves or older Photos-backed videos.
- [ ] Document Apple framework behavior separately: MapKit may load map imagery for route thumbnails and reverse geocode a saved route point to suggest editable titles and descriptions.
- [ ] Confirm the app describes background GPS recording as optional and user-enabled.
- [ ] Confirm App Store copy says the iPhone app excludes iPad support in version 1.1.0.
- [ ] Confirm App Store copy says version 1.1.0 includes a GPS-only Apple Watch companion app.
- [ ] Include review notes that background location is GPS Walk only, requires the user to enable Background GPS Recording in Settings, and requires Always location permission.
- [ ] Include review notes that the Apple Watch app records GPS-only walks, does not record video, and does not create HealthKit workouts.
- [ ] Include review notes that Watch recordings sync through the user's private iCloud database and appear in iPhone History after sync.
- [ ] Include review notes that external-camera fields are timing notes for user-managed footage and ASMR Walk does not import or sync those external video files.
- [ ] Include screenshots for History, Walk, Video Walk, Recording Detail, and Settings.
- [ ] Mention that route data is stored locally.
- [ ] Mention that route data and recording metadata can sync through iCloud.
- [ ] Mention that route thumbnails are stored locally.
- [ ] Mention that video walks are stored locally in ASMR Walk by default.
- [ ] Mention that video files do not sync to other devices through ASMR Walk.
- [ ] Mention that users can save a copy of a video walk to Photos from History detail.
- [ ] Mention that deleting an ASMR Walk recording removes the app-managed local video but does not delete user-saved Photos copies.
- [ ] Review export behavior: Google Maps is a quick route share, GPX is the full-fidelity route export with optional ASMR Walk metadata extensions.
- [ ] Revisit App Privacy answers before every release that adds analytics, crash reporting SDKs, developer-operated accounts, remote storage, video sync, or any other developer-operated off-device collection.

## Known Version 1.1.0 Scope

- No iPad support.
- Apple Watch support is GPS-only route recording.
- No HealthKit workout integration.
- Background route recording is GPS-only and opt-in.
- No background Video Walk recording.
- No burned-in video map overlay export.
- No delete-from-Photos management for video copies saved to the user's Photos library.
- iCloud sync covers recording metadata and routes, not full video files.
- Simulator Watch-to-iPhone sync is non-authoritative for release; physical-device/TestFlight validation is tracked in GitHub issue #93.
