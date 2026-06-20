# ASMR Walk Journal

## The Big Picture

ASMR Walk is a pocket-sized walking journal. Press record, take a walk, and come back with a route, useful stats, and optionally a video that remembers what the path looked and sounded like. Think of it as a trail of digital breadcrumbs, except these breadcrumbs can be replayed and shared.

## Architecture Deep Dive

The app is planned like a small film crew. Core Location is the location scout, continuously marking where the walk goes. AVFoundation is the camera operator. SwiftData is the archivist who files the route, timing, and video reference together. SwiftUI is the editor at the front desk, presenting the live recording and making old walks easy to revisit.

Keeping those jobs separate matters. A view should ask a recorder to start rather than trying to operate GPS hardware itself. That gives the interface one clear job and lets tests replace real hardware with predictable stand-ins.

## The Codebase Map

- `ASMR Walk/ASMR_WalkApp.swift` is the app entry point.
- `ASMR Walk/ContentView.swift` currently contains the first-pass app shell and its three main destinations.
- `ASMR WalkTests` is for fast model and service tests.
- `ASMR WalkUITests` is for end-to-end interface flows.

As features grow, recording services, models, and feature views should move into focused files rather than turning `ContentView.swift` into a crowded equipment closet.

## Tech Stack & Why

- **SwiftUI** gives the app native navigation, accessibility, and iOS 26 Liquid Glass behavior with less custom chrome to maintain.
- **SwiftData** fits a private, local-first journal and integrates directly with SwiftUI queries.
- **MapKit and Core Location** provide Apple's native map rendering and location pipeline.
- **AVFoundation** provides the control required to capture and manage walk videos.
- **Swift concurrency** will keep long-running recording work readable and make cancellation explicit.

## The Journey

### Videos Move Into the Family Album

Storing videos only inside the app sandbox is fragile. It works until an update, migration, cleanup, or reinstall changes the furniture. The new preferred path treats Photos as the long-term video home: when a video walk finishes, the app asks Photos to import the `.mov`, then stores the Photos asset identifier on the `WalkRecording`. Later playback asks Photos for an `AVPlayerItem` using that identifier.

The old sandbox URL remains as a fallback for existing recordings and for cases where Photos saving fails, but it is no longer the preferred source of truth. There is one important runtime trap: iOS will not even let an app ask for Photos access unless the target has the right usage descriptions. The code checks for those keys first so a missing setting becomes a normal error instead of a crash.

### Settings Give the App a Dimmer Switch

The app now has a Settings tab with a three-position theme picker: System, Light, and Dark. System is the default because most people have already told iOS what they prefer. The app stores the choice in `@AppStorage`, and the root tab view applies the selected color scheme so the setting affects the whole interface instead of just the settings screen.

### GPX Learned to Speak Plugin

The original GPX export was a clean walking trail: coordinates, elevation, and timestamps. That is enough for generic map apps, but an FCP/Motion importer needs a little more context to sync a route to a finished walk or video. The export now keeps standard GPX as the main dish and puts ASMR Walk-specific details in `<extensions>`, which is the GPX-approved side pocket for app metadata.

Those extensions include the recording ID, duration, mode, `hasVideo`, horizontal accuracy, and speed when the phone captured it. The deliberate omission is the local video URL. A sandbox file path from an iPhone is useless on a Mac and leaks private implementation details, so the export says "this recording has video" without pretending the Mac can open the app's private file.

### Device Testing: The Camera Tells the Truth

The simulator was polite. The iPhone was honest. Real device testing showed that asking the Video Walk tab to appear in landscape was not enough; the camera preview and movie file both needed explicit AVFoundation rotation. The app now uses one fixed Video Walk capture orientation and applies its `videoRotationAngle` to both the `AVCaptureVideoPreviewLayer` and the movie output connection, so the preview and saved file agree instead of fighting over portrait defaults.

The second lesson was that "please rotate this scene" is not the same as "this screen does not support portrait." The Video Walk tab now temporarily changes the app-supported orientation mask to landscape-right while it is visible, then restores portrait for the rest of the app. Think of it as putting a one-way turnstile at the camera door: once you enter Video Walk, portrait is no longer an allowed direction.

The same pass tightened the camera lifecycle. A stale capture session can behave like an old TV paused on the last frame, so the video tab now refreshes its capture pipeline before preparing the preview. Stopping a recording also verifies the `.mov` file actually exists before SwiftData gets a video URL. If finalization fails, the app discards that incomplete video walk instead of filing a broken record in history.

One user-comfort rule is intentionally narrow: the idle timer is disabled only while video recording is active. GPS-only walks can let the screen sleep because they do not need a live camera preview burning battery. Short recordings also got a human checkpoint. If a user stops a walk or video walk before 10 seconds, the app asks whether to save or discard it rather than silently cluttering history with accidental taps.

The map learned one more trick too: while the Walk and Video Walk tabs preview location, Core Location heading updates feed a custom user annotation. The marker points roughly where the phone is facing, which makes the live map feel closer to Apple Maps and less like a dot floating without context.

### Release Polish Is Mostly About Bad Days

Phase 8 was less about adding shiny new screens and more about making the app behave well when the day goes sideways. If location, camera, or microphone access is blocked, the recording buttons now stop pretending they can work and the app gives the user a direct route to Settings. Video start failures are surfaced instead of disappearing silently.

This is the boring-but-important App Store work: every permission prompt, denied state, interrupted recording, and missing setup path needs a graceful answer. A good release candidate is not just the happy path; it is the unhappy path with decent manners.

### A Launch Screen, Not a Waiting Room

The app already uses Xcode's generated native launch screen, which is the part iOS and App Store review care about before SwiftUI starts running. We added a very short branded SwiftUI startup screen after launch for a more polished first impression, but kept it under a second so it does not turn into a fake loading delay.

The practical lesson: the native launch screen and the in-app splash are different layers. The native launch screen must exist for system startup behavior; the in-app splash is product polish and should get out of the user's way quickly.

### The Video Finally Got a Map Buddy

Phase 7 turned saved video walks from "a movie file with some stats nearby" into an actual review experience. The detail screen now loads the saved movie with `AVPlayer`, observes playback time every half second, and feeds that time into a route map overlay. As the video plays, the blue playback marker advances along the recorded GPS points.

The route sync uses the first accepted GPS point as time zero. That is a practical version-one choice because camera start and GPS start happen in the same user action, but the first usable GPS point may arrive a moment later than the first video frame. For review, that means the map starts moving when trustworthy route data begins rather than pretending noisy or missing GPS exists.

The important engineering pattern here is cleanup: `AVPlayer.addPeriodicTimeObserver` must be paired with `removeTimeObserver`. Forgetting that is like leaving a kitchen timer running after dinner; it may keep calling back into UI that no longer exists.

### Two Recorders, One Walk

Phase 6 introduced video walks without tangling camera capture into the GPS recorder. `VideoCaptureService` owns the AVFoundation capture session, camera preview, microphone input, and movie finalization. `WalkRecorder` continues doing the job it already understands: filtering GPS points, measuring distance, and saving SwiftData records. The video screen acts like a film director calling “action” and “cut” for both crews at the same time, then links the finished movie URL to the route before saving.

The movie itself lives in the app's Documents directory while SwiftData stores only its URL. This keeps large binary files out of the database and lets route metadata remain lightweight. Deleting a video walk removes both the SwiftData record and its movie file so abandoned recordings do not quietly consume storage.

Video Walk requests landscape orientation when its tab appears and restores portrait when leaving. Orientation is a scene-level preference, not a normal SwiftUI view modifier, so the app uses `UIWindowScene.requestGeometryUpdate`. The target must support landscape orientations for that request to succeed.

One runtime gotcha remains outside source code: iOS terminates apps that request camera or microphone access without `NSCameraUsageDescription` and `NSMicrophoneUsageDescription`. Those strings must be added to the target's generated Info properties before testing capture on a device.

### One Route, Two Passports

Phase 5 gave each saved route two ways to leave the app. A Google Maps URL is the lightweight passport: it carries the start, destination, walking mode, and a sampled set of waypoints so another person can quickly open directions. GPX is the full travel journal: it preserves every route point in chronological order, including timestamps and available elevation.

Export generation lives in an immutable `WalkRouteExport` snapshot instead of directly inside the SwiftUI view or SwiftData model. That separation keeps the view focused on presentation, avoids passing SwiftData objects into asynchronous file-transfer work, and makes URL and XML generation easy to verify with fast unit tests.

The gotcha is fidelity. Google Maps URLs are useful but cannot practically carry an unlimited GPS trail, so waypoints are sampled. GPX remains the source of truth when the exact recorded route matters.

### The Map That Started Too Far Away

The Walk tab originally opened with an automatic map camera while waiting for Core Location. Automatic framing had no useful coordinates yet, so MapKit showed a broad view of the United States. Route updates also switched the camera back to automatic framing, which could pull the view away from the walker.

The fix was to let `WalkRecorder` preview location updates while the Walk tab is visible, then move the map camera to the first valid coordinate at an 800-meter viewing distance. That is roughly street level without being so close that the user loses context. A native user-location button remains available for recentering after someone pans around.

The lesson: a user-location annotation and a user-focused camera are separate jobs. Showing the blue location marker does not guarantee the camera will frame it usefully.

### Foundation: Three Clear Doors

The starter project was a single “Hello, world!” screen. The first pass established three top-level destinations: History, Walk, and Video Walk. Each destination now communicates its purpose and current readiness without claiming unfinished recording features work.

The first useful lesson is that iOS 26 standard navigation and tab controls already adopt Liquid Glass. Custom glass is best reserved for controls floating over visual content, such as the recorder status, metrics, and start button. Covering every surface in glass would be like installing windows between every room: expensive, distracting, and not especially useful.

### Testing the Empty Building

There was no recording engine to unit test yet, but that does not mean the foundation gets a free pass. Tab metadata moved into a small `AppTab` type so Swift Testing can verify the app's promised destinations without trying to dissect SwiftUI views. UI tests now walk through all three doors and verify the visible ready states, controls, and accessibility labels.

Stable accessibility identifiers are the test crew's labeled floor marks. They let automation find important controls without depending on fragile screen coordinates or visual styling.

### Phase 2: Giving Every Walk a Filing Cabinet

The app now has a real SwiftData graph. `WalkRecording` is the folder containing a walk's title, date, statistics, mode, optional video URL, and route. Each `LocationPoint` is one timestamped breadcrumb inside that folder. Deleting the folder uses a cascade rule, so its breadcrumbs disappear too instead of becoming database clutter.

`RecordingMode` is stored as a Codable enum rather than a loose string. That turns invalid modes into a compile-time problem instead of a mysterious typo found months later. Sample walks live in an in-memory preview container, letting future screens work with realistic data without quietly adding fake walks to a person's journal.

### A Layered Face for the App

The app now uses an Icon Composer `AppIcon.icon` package instead of relying on the empty legacy app-icon asset set. Think of it less like a printed sticker and more like a tiny stage set: the three artwork layers let iOS apply lighting, depth, Liquid Glass treatments, and appearance variants while Xcode generates compatible icons for older releases.

### Phase 3: Opening the Archive

The archivist finally has a front desk. History now queries SwiftData newest-first, presents each walk with its date, duration, distance, type, and video status, and opens a detail page with a native MapKit route preview. Start and finish markers make the route readable at a glance instead of leaving a mysterious green line floating on the map.

Deleting a recording is deliberately a two-step operation: swipe to request deletion, then confirm before SwiftData removes the walk and cascade-deletes its route points. The code explicitly saves the context and rolls back on failure, because data loss is not a good place to rely on hopeful autosaving.

### Phase 4: Following the Breadcrumbs Live

The Walk tab is now a real foreground GPS recorder. Core Location's async live-update stream feeds a focused recording session, while MapKit draws accepted points as a green route. A draft is saved as soon as recording starts, then checkpointed every ten accepted points or thirty seconds. If the app leaves the foreground, the walk finalizes instead of pretending foreground-only recording can safely continue.

GPS is a noisy storyteller, so the recorder does not believe every sentence. It rejects stale readings, accuracy worse than 50 meters, and movement under three meters. That prevents a stationary phone from slowly wandering across the map and inflating distance totals.

## Engineer's Wisdom

- Make unfinished behavior visibly unfinished. A polished button wired to nothing is worse than an honest foundation state.
- Separate hardware services from views before hardware complexity arrives.
- Prefer system controls. They carry accessibility, platform behavior, and visual updates that custom components must otherwise recreate.
- Treat route fidelity and share convenience as separate export goals: Google Maps for convenience, GPX for accuracy.

## If I Were Starting Over...

This is the starting line, so the main retrospective is a guardrail: define the persistence model and recording state machine before building deep history UI. Real data shapes reveal the right interface faster than elaborate mock screens do.
