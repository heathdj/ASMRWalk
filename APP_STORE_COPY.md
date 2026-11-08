# ASMR Walk App Store Copy

Use this as the source draft for App Store Connect text for version 1.1.0. Keep it aligned with `README.md`, `RELEASE_CHECKLIST.md`, and `PRIVACY_POLICY.md`.

Public privacy policy URL: https://bald-traveler.com/asmr-walk-privacy-policy/

Public support URL: https://bald-traveler.com/asmr-walk-support-page/

## Subtitle

GPS routes and video walks

## Promotional Text

Record walks on iPhone or Apple Watch, choose your Video Walk microphone, and keep route memories together with private iCloud sync.

## What’s New in This Version

- Record GPS-only walks on Apple Watch and transfer saved routes directly to your paired iPhone, which can sync them through private iCloud.
- Choose the iPhone microphone or a supported connected Bluetooth or USB microphone before a Video Walk. See the active input and notices when an accessory disconnects.
- Add external-camera timing notes to Watch routes for use with separately recorded footage.
- Improved Video Walk audio-session cleanup when leaving the preview or putting the app in the background.

## Short Description (reference only; not an App Store Connect field)

ASMR Walk is a walking journal for iPhone and Apple Watch with GPS routes, optional iPhone video walks, iCloud-synced route history, and GPX route exports.

## Description

ASMR Walk helps you capture quiet walking memories. Record a GPS Walk on iPhone for a simple route journal, record a Video Walk on iPhone when you want camera and microphone audio alongside the route, or use the Apple Watch companion app to record a GPS-only walk from your wrist.

Before a Video Walk, choose Automatic, the iPhone microphone, or a supported connected Bluetooth or USB microphone. The app shows the active input and locks microphone selection during recording. Available inputs depend on your connected hardware.

Saved walk metadata and routes can sync through your private iCloud account. Watch recordings transfer directly to the paired iPhone and appear in History with an Apple Watch source label; the iPhone can then sync them through iCloud. Video walks are stored in ASMR Walk on the device where they were recorded for playback with the saved route, and you can save a copy to Photos from the History detail screen. Full video files do not sync to other devices through ASMR Walk.

After a walk is saved, ASMR Walk can generate a route thumbnail and use Apple Maps place information to suggest a useful title and description, which you can edit from the History detail screen. Deleting an ASMR Walk recording removes the route, app metadata, app-managed thumbnail, and app-managed video file on that device, but it does not delete any copy you chose to save to Photos.

ASMR Walk can export full-fidelity GPX files through the iOS share sheet, including recording descriptions when present, and can create Google Maps walking-route links for quick sharing. Watch routes can also store external-camera timing notes on iPhone, so a route can be aligned later with separately recorded footage.

Background GPS recording is optional and applies only to GPS Walk recordings. It requires the user to enable Background GPS Recording in Settings and grant Always location permission. Video Walk recording is foreground-only and stops when the app leaves the foreground.

Version 1.1.0 requires iOS 26.0 or later for the iPhone app and includes a GPS-only Apple Watch companion app. iPad, HealthKit workouts, developer-operated accounts, analytics, advertising, and developer-operated backend storage are not included in version 1.1.0.

## Keywords

walking, GPS, route, GPX, video walk, Apple Watch, walking journal, map, iCloud

## App Review Notes — paste into App Review Information > Notes

No ASMR Walk account or demo credentials are required. Core recording can be reviewed without an external microphone. Private iCloud sync requires devices signed into the same Apple Account with iCloud available.

Microphone selection (new in 1.1.0):
1. Use a physical iPhone. Open Video Walk and tap Start Video Walk to grant camera, microphone, and location permissions when requested. If this begins the first recording, stop it using the active recording banner; save or discard the short sample to return to the ready preview.
2. Tap the microphone pill on the ready preview. Confirm Automatic and iPhone Microphone are available. Select iPhone Microphone and verify the displayed active input.
3. Optionally connect a supported Bluetooth microphone or USB audio receiver. Open the picker, select its system-provided name, and check the active input. A wireless receiver attached through USB-C appears as USB audio. High-quality Bluetooth availability depends on the hardware and region; standard Bluetooth microphone routing is supported as fallback.
4. Record at least 10 seconds while speaking, stop using the active recording banner, then play the saved Video Walk from History to check the audio. Microphone selection is disabled during recording. Repeat with Automatic or an available external input.
5. Disconnect a selected external input. The app updates the effective input and displays a fallback notice. If a requested input cannot become active, an error prevents silently starting with the wrong microphone. Reconnect and select it again after stopping. Preferences apply to the current app session.
6. With a ready preview and no recording underway, put the app in the background: camera/microphone use ends. Return to Video Walk: the authorized preview becomes available again. Background an active Video Walk: recording stops and saves before capture shuts down. Video recording is foreground-only.

Other review paths:
- On Apple Watch, start and stop a GPS-only walk and allow location access. Open the updated app on both paired devices. Saved walks transfer directly to iPhone; allow time for delivery, then check History for the Watch source. The Watch confirms receipt only after iPhone saves. Use Retry Transfer on Watch and Settings > Apple Watch Transfers on iPhone if needed. The iPhone then uses private iCloud for other devices. Watch recording does not use the camera, microphone, or HealthKit workouts.
- External-camera timing fields on Watch routes store timing notes only; they do not import or sync external footage.
- Optional background location applies only to iPhone GPS Walk. Enable Background GPS Recording in Settings and grant Always location permission before testing a GPS Walk with the screen locked.
- New Video Walk movies stay in app-managed local storage. In History detail, Save Video to Photos explicitly exports a copy. Deleting a recording removes its app-managed files but leaves any saved Photos copy. Full videos do not sync through ASMR Walk; metadata and routes may sync privately through iCloud.
- MapKit generates route thumbnails and editable place suggestions after saving. ASMR Walk has no developer-operated accounts, analytics, ads, tracking, or backend uploads. Settings includes the Privacy Policy link.

The Mac importer and Final Cut Pro/Motion overlay are distributed separately in a Mac installer; neither is required to review the iPhone/Watch app.

## Owner Submission Steps — do not paste into Review Notes

1. Owner manual device testing was confirmed complete on November 8, 2026. Issues #93, #109, and #79 are closed. See `RELEASE_CHECKLIST.md` for validation evidence, reusable regression scenarios, and remaining archive/submission administration.
2. Create/select iOS version **1.1.0** in App Store Connect. Upload a matching archive with a new build number and the Watch companion included; select the processed build. The latest iPhone/Watch candidate tag is `release-1.1.0b`; select the processed build produced from that commit and verify its actual build number. The App Store version remains `1.1.0`.
3. Paste Subtitle, Promotional Text (optional), Description, Keywords, and What’s New into the corresponding fields. Copy only each section’s content. Use the exact public support and privacy URLs above. Both live pages were verified against `SUPPORT_PAGE.md` and `PRIVACY_POLICY.md` on November 8, 2026.
4. Paste App Review Notes into App Review Information > Notes. Leave Sign-in required unchecked. Verify the review contact name, email, and reachable phone number in App Store Connect; these are owner-provided account details, not demo credentials.
5. Supply current iPhone and Apple Watch screenshots. Verify age rating, export compliance, privacy answers, and any accessibility claims against the actual archive and completed testing. Microphone selection adds no developer collection; private iCloud route sync and user-directed exports remain as described in the privacy policy.
6. Select the desired release option (manual release allows coordination with the separate Mac installer), then submit when all applicable gates are complete. A pushed Git tag does not mean Apple has approved or published the version.
7. The separate Mac installer is already attached to the GitHub `release-1.1.0` release: [Download Mac Tools 1.1.0](https://github.com/heathdj/ASMRWalk/releases/download/release-1.1.0/ASMR-Walk-Mac-Tools-1.1.0.pkg). It is not an App Store Connect upload. The iPhone/Watch retry tag `release-1.1.0b` does not change this download URL; rebuild the installer only if its Mac sources change.

Apple reference: [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/).
