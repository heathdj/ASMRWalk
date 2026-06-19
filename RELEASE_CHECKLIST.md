# ASMR Walk Release Checklist

Use this before uploading `1.0` to App Store Connect.

## Required Target Settings

- Bundle identifier is final.
- Version is `1.0`.
- Build number is incremented for every upload.
- Generated launch screen is enabled.
- App icon is configured.
- Supported iPhone orientations include portrait and landscape.
- Privacy strings are present:
  - `NSLocationWhenInUseUsageDescription`
  - `NSCameraUsageDescription`
  - `NSMicrophoneUsageDescription`

## Device Validation

Run these on a physical iPhone before submission:

- Start and save a GPS-only walk.
- Deny location permission and confirm the app shows a Settings recovery button.
- Start and save a video walk.
- Deny camera or microphone permission and confirm the app shows a Settings recovery button.
- Background the app during a walk and confirm the foreground-only recording behavior is acceptable.
- Open a saved video walk and confirm playback plus route overlay works.
- Delete a video walk and confirm the video file is removed.
- Export a Google Maps URL.
- Export a GPX file through the share sheet.

## App Store Connect

- Complete privacy nutrition labels for location, camera, microphone, and local user content.
- Confirm the app does not claim background recording in metadata.
- Include screenshots for History, Walk, Video Walk, and Recording Detail.
- Mention that recordings are stored locally.
- Review export behavior: Google Maps is a quick route share, GPX is the full-fidelity route export.

## Known Version 1 Scope

- Foreground recording only.
- No iCloud sync.
- No Apple Watch support.
- No burned-in video map overlay export.
