# ASMR Walk Privacy Policy

Last updated: August 30, 2026

ASMR Walk is designed as a private walking journal. The app records walking routes, optional video walks on your iPhone, and GPS-only walks from the Apple Watch companion app. ASMR Walk does not run a developer-operated account system, analytics service, advertising network, or backend server.

## Data Stored On Your Device

ASMR Walk stores walk titles, editable walk descriptions, dates, durations, distances, route thumbnails, and route points using Apple's persistence frameworks.

Route points can include latitude, longitude, timestamp, altitude when available, horizontal accuracy, and speed when available.

## iCloud Sync

ASMR Walk can sync recording metadata and route data through your private iCloud database using Apple's CloudKit service. This lets recordings created on one signed-in device, including Apple Watch GPS recordings, appear on another signed-in device.

iCloud sync can include walk titles, descriptions, dates, durations, distances, route points, recording source, generated place metadata, route thumbnail references, and export-related metadata. For Watch routes paired with footage from a separate camera, export-related metadata can include an external clip label and timing values used to align the route with that separate footage. Full video files are not synced by ASMR Walk. Video walks remain stored in app-managed local storage on the device where they were recorded unless you choose to save or share a copy.

Your iCloud account and Apple's CloudKit service are operated by Apple, not ASMR Walk. ASMR Walk does not run its own sync server.

## Location

ASMR Walk uses location while recording to draw and save your walking route.

On Apple Watch, ASMR Walk uses location only for GPS-only Watch walk recording. The Watch app asks for location access when you start recording from the Watch.

Background GPS recording is optional on iPhone, applies only to iPhone GPS Walk recordings, and requires Always location permission. When enabled, ASMR Walk may continue recording a GPS-only walk while the iPhone app is backgrounded or the screen is locked. Video Walks do not continue recording in the background.

After a recording is saved, ASMR Walk may use Apple's MapKit services to generate a route thumbnail and suggest a place-based title and description. This work is best-effort and is used only to improve the local recording details shown in the app.

## Camera And Microphone

ASMR Walk uses the camera and microphone only for iPhone Video Walk recording. Video capture happens on your device. Apple Watch recordings do not use the camera or microphone.

## Photos

ASMR Walk keeps newly recorded video walks in app-managed local storage for playback with your saved route. From a video walk's History detail screen, you can choose to save a copy of that local video to your Photos library. If a video walk's metadata and route appear on another device through iCloud sync, the video itself may not be available on that other device.

Deleting an ASMR Walk recording removes the app's route, metadata, app-managed thumbnail, and app-managed video file. It does not delete any copy you chose to save to Photos. ASMR Walk may still read older Photos-backed video walks created by earlier versions so they can replay with their saved routes.

Photos may use Apple's own services, such as iCloud Photos, depending on your device settings. ASMR Walk does not operate those services.

## Sharing And Exports

ASMR Walk can create exports when you choose to share them:

- GPX files include route points and ASMR Walk metadata such as recording duration, recording mode, recording description, video presence, recording ID, horizontal accuracy, and speed when available.
- For Watch routes paired with an external camera, GPX files may include the external clip label and timing values you entered so other tools can align the route with separately recorded footage.
- Google Maps route links include the route start, destination, and sampled waypoints.

Sharing is user-initiated through the iOS share sheet. The destination you choose may receive the exported data and apply its own privacy practices.

## Network Activity

ASMR Walk does not make direct app-owned network requests for analytics, developer-operated accounts, advertising, or developer-operated server storage.

Some Apple frameworks or user-selected destinations may contact network services outside ASMR Walk's control. Examples include CloudKit syncing recording metadata and routes through your private iCloud database, MapKit loading map imagery or reverse geocoding a saved route point, Photos loading an iCloud-backed video asset, or the user opening a Google Maps route link.

## Tracking

ASMR Walk does not track users across apps or websites.

## Contact

For privacy questions, contact `heathdj@me.com`.
