# ASMR Walk App Store Copy

Use this as the source draft for App Store Connect text for version 1.1.0. Keep it aligned with `README.md`, `RELEASE_CHECKLIST.md`, and `PRIVACY_POLICY.md`.

Public privacy policy URL: https://bald-traveler.com/asmr-walk-privacy-policy/

## Short Description

ASMR Walk is a walking journal for iPhone and Apple Watch with GPS routes, optional iPhone video walks, iCloud-synced route history, and GPX route exports.

## Description

ASMR Walk helps you capture quiet walking memories. Record a GPS Walk on iPhone for a simple route journal, record a Video Walk on iPhone when you want camera and microphone audio alongside the route, or use the Apple Watch companion app to record a GPS-only walk from your wrist.

Saved walk metadata and routes can sync through your private iCloud account. Watch recordings appear in iPhone History after sync with an Apple Watch source label. Video walks are stored in ASMR Walk on the device where they were recorded for playback with the saved route, and you can save a copy to Photos from the History detail screen. Full video files do not sync to other devices through ASMR Walk.

After a walk is saved, ASMR Walk can generate a route thumbnail and use Apple Maps place information to suggest a useful title and description, which you can edit from the History detail screen. Deleting an ASMR Walk recording removes the route, app metadata, app-managed thumbnail, and app-managed video file on that device, but it does not delete any copy you chose to save to Photos.

ASMR Walk can export full-fidelity GPX files through the iOS share sheet, including recording descriptions when present, and can create Google Maps walking-route links for quick sharing. Watch routes can also store external-camera timing notes on iPhone, so a route can be aligned later with separately recorded footage.

Background GPS recording is optional and applies only to GPS Walk recordings. It requires the user to enable Background GPS Recording in Settings and grant Always location permission. Video Walk recording is foreground-only and stops when the app leaves the foreground.

Version 1.1.0 requires iOS 26.0 or later for the iPhone app and includes a GPS-only Apple Watch companion app. iPad, HealthKit workouts, developer-operated accounts, analytics, advertising, and developer-operated backend storage are not included in version 1.1.0.

## Keywords

walking, GPS, route, GPX, video walk, Apple Watch, walking journal, map, iCloud

## Review Notes

- Background location is used only for GPS Walk recordings.
- Background GPS requires the user to enable Background GPS Recording in Settings and grant Always location permission.
- Video Walk recordings stop when the app leaves the foreground.
- The Apple Watch companion app records GPS-only walks. It does not record video or HealthKit workouts in version 1.1.0.
- Watch recordings sync route metadata and points through the user's private iCloud database and appear in iPhone History after sync.
- Watch-to-iPhone sync is being validated on physical Watch/iPhone hardware before App Store submission because Simulator sync was not reliable during development.
- External-camera timing fields are notes for separately captured footage; ASMR Walk does not import or sync the external video file.
- Finished video walks are stored locally in ASMR Walk by default.
- Route data and recording metadata sync through the user's private iCloud database.
- Full video files do not sync to other devices through ASMR Walk.
- Users can save a copy of a video walk to Photos from the History detail screen.
- Deleting an ASMR Walk recording removes the app-managed local video but does not delete user-saved Photos copies.
- ASMR Walk uses Apple MapKit after saving a walk to generate route thumbnails and suggest editable place-based titles and descriptions.
- ASMR Walk does not use developer-operated accounts, analytics, advertising, or backend upload code in version 1.1.0.
- The Settings screen includes a Privacy Policy link.
