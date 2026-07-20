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

### The Screen Marker That Stole the Name Tags

UI testing caught a sneaky SwiftUI accessibility gotcha: putting an accessibility identifier on a broad `ZStack` can leak that identifier onto the child controls instead of creating a clean screen marker. The Walk screen looked present to automation, but the status card and start button could lose their own identifiers in the accessibility tree.

The fix was to make the Walk and Video Walk root stacks explicit accessibility containers before assigning their screen identifiers. Think of the screen as the room label on the door; the buttons and status cards still need their own name tags once you're inside.

### Videos Move Into the Family Album

Storing videos only inside the app sandbox is fragile. It works until an update, migration, cleanup, or reinstall changes the furniture. The new preferred path treats Photos as the long-term video home: when a video walk finishes, the app asks Photos to import the `.mov`, then stores the Photos asset identifier on the `WalkRecording`. Later playback asks Photos for an `AVPlayerItem` using that identifier.

The old sandbox URL remains as a fallback for existing recordings and for cases where Photos saving fails, but it is no longer the preferred source of truth. There is one important runtime trap: iOS will not even let an app ask for Photos access unless the target has the right usage descriptions. The code checks for those keys first so a missing setting becomes a normal error instead of a crash.

### Settings Give the App a Dimmer Switch

The app now has a Settings tab with a three-position theme picker: System, Light, and Dark. System is the default because most people have already told iOS what they prefer. The app stores the choice in `@AppStorage`, and the root tab view applies the selected color scheme so the setting affects the whole interface instead of just the settings screen.

Settings now also decides where the History empty-state recording button sends the user. The default is GPS Walk, which keeps the simple path simple, but people who mostly record video walks can switch that button to open Video Walk instead. The important fix is that the button now does real navigation rather than looking useful and doing nothing.

Background GPS recording is deliberately behind a switch. When it is off, ASMR Walk keeps the original foreground-only behavior and saves if the app leaves the foreground. When it is on, the Walk recorder asks for Always location permission and keeps a GPS-only walk alive in the background only if iOS grants that permission. Video stays foreground-only because background camera capture is a different level of complexity and App Store scrutiny.

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

The app uses Xcode's generated native launch screen, which is the part iOS and App Store review care about before SwiftUI starts running. The earlier SwiftUI splash screen was removed rather than shortened. Startup now goes straight to the app once SwiftUI is ready, and the static native launch screen carries the brand moment without pretending to load.

The practical lesson: the native launch screen and the in-app splash are different layers. The native launch screen must exist for system startup behavior; an in-app splash should only exist when real initialization work needs a transitional UI.

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

### The Launch Logo Learned About Safe Areas

The first native launch screen used the plist-only `UILaunchScreen` shortcut: point iOS at a background color and an image, then let the system draw it. That worked until device testing showed the logo could grow past the launch screen's safe area. The shortcut is convenient, but it is a blunt instrument.

The fix moved startup presentation into `Launch Screen.storyboard`, where Auto Layout can do the job it was built for. The logo is now an aspect-fit image view centered in the safe area, with maximum width and height constraints. Think of it like giving the hiker a marked campsite instead of saying "stand somewhere near the middle." On different iPhones, notches, and orientations, the constraints keep the artwork contained.

The lesson: launch screens are static, but they still need layout rules. A carefully resized PNG can pass on one device and fail on another; constraints travel better.

### The Dock Gets a Remote Control

DockKit support adds a new kind of input to Video Walk: the camera accessory can now ask the app to do camera things. `DockKitAccessoryService` listens for dock state and accessory events, then hands only the two useful commands to the video screen. Camera shutter is the big red button from across the room: start recording if idle, stop if already rolling. Camera zoom nudges the active `AVCaptureDevice` zoom factor up or down in small, clamped steps.

Everything else deliberately does nothing for now. That is not neglect; it is choosing a clean first contract. The Insta360 Flow 2 Pro can send more events than ASMR Walk currently needs, and silently ignoring unsupported inputs is better than inventing half-working behavior.

One practical gotcha: the local SDK in this development environment does not expose the `DockKit` module, so the service is wrapped in `#if canImport(DockKit)`. The app still builds here, while a DockKit-capable Xcode/iPhone pair gets the real accessory stream. Hardware features are like stage lighting: the wiring can be clean, but you still test with the actual rig before opening night.

### A First-Run Tour, Not a Toll Booth

Onboarding now introduces the three main rooms before dropping someone into the app: Walk for a GPS-only route, Video Walk for camera-plus-route recording, and History for replay, review, and GPX export. It is intentionally a guided tour rather than a permission gauntlet. No system prompts fire just because a page appeared; people should understand the front door before iOS starts asking for keys.

The completion flag lives in `@AppStorage`, which makes the root view choose between the onboarding tour and the normal tab shell without inventing a new persistence layer. Settings includes a "Show Onboarding Again" button because future-you will absolutely want to revisit the tour during testing, demos, and copy tweaks. Think of it as leaving the museum map at the front desk instead of throwing it away after the first visit.

### The Archivist Moved Off the Front Counter

The recording flow used to hand SwiftUI's `modelContext` to `WalkRecorder`, then checkpoint and save from the main actor. That worked functionally, but it meant database writes could happen right where the UI is trying to stay responsive. The runtime warning was the app tapping a clipboard, a camera, and a filing cabinet all at the front counter while the line was still moving.

`WalkRecordingSession` now keeps a plain value snapshot of the live walk. The UI can still render duration, distance, and map points immediately, but SwiftData models are created and updated inside `WalkRecordingPersistence`, a `@ModelActor`. Saves, checkpoints, and deletes now go through that actor, while History keeps its `@Query` for the normal live SwiftUI list. The rule of thumb from here: views may observe records, but background-worthy writes belong to the archivist actor.

### The Stopwatch Hid Inside the Notebook

Device testing found a sneaky side effect of moving recordings to value snapshots: Video Walk kept recording, but the visible timer and distance stayed frozen at zero. The data was changing inside `WalkRecordingSession.snapshot`, but SwiftUI was watching `WalkRecorder`. Mutating a nested helper object is like updating a note inside a closed notebook; the person watching the cover does not know anything changed.

The fix was to mirror the live recording values onto observable `WalkRecorder` properties: current duration, current distance, and route coordinates. The session still owns the recording math, and the persistence actor still owns the database, but the UI now has obvious top-level state to observe every second and after every accepted GPS point.

### The Dock Learned to Stop Following Strangers

DockKit system tracking is helpful in a normal camera app, but ASMR Walk wants the gimbal to behave like a steady mount unless the app explicitly handles an accessory event. On-device testing showed that the dock could try to track objects by itself as soon as the camera stream and dock were active.

`DockKitAccessoryService` now asks `DockAccessoryManager` to disable system tracking when the service starts and again when an accessory docks. That second call matters because DockKit enables system tracking by default when a device docks. The service still listens for shutter and zoom events, but it no longer invites the dock to chase whatever it sees in frame.

### Zoom Is a Multiplier, Not a Mood Ring

The DockKit zoom event does not send "positive means in, negative means out." It sends a multiplier: greater than `1.0` means zoom in, less than `1.0` means zoom out, and `1.0` means no change. ASMR Walk originally checked whether the factor was nonnegative, which made every normal DockKit zoom event look like zoom in. On a real gimbal, that meant the zoom control had an elevator-up button and no elevator-down button.

The camera service now compares the factor against `1.0`, so zoom-out events step the camera back toward its minimum zoom factor.

### One Recording Captain

QA found a serious loophole hiding in plain sight: GPS Walk and Video Walk each brought their own `WalkRecorder` to the party. That meant a GPS walk could keep running, the user could switch tabs, and Video Walk could start a second route recorder. Two captains were steering the same ship, and neither knew the other had grabbed the wheel.

`RecordingCoordinator` is now the single bouncer at the recording door. The tab shell owns it, both recording screens share its one `WalkRecorder`, and the coordinator remembers which mode is active until the recording is saved or discarded. If someone tries to start Video Walk during a GPS walk, the button becomes "Go to Walk" instead of pretending a second recording can begin. The reverse path works the same way for Video Walk.

The subtle bit is the short-recording dialog. A recording is still considered active while the app asks whether to save or discard it, because that dialog is not a finished state. Treating "waiting for a decision" as idle would reopen the same bug through a side door.

### The Recording Leash

The next QA catch was related: even with only one captain, the user could walk out of the room. A GPS recording kept running after a tab switch, but the stop button stayed behind on the Walk tab. Technically correct, practically awkward.

The app shell now carries a persistent active-recording banner, like a leash clipped to the bottom of the screen. Switch to History or Settings and the banner follows: current mode, elapsed time, distance, a return button, and for GPS walks a stop button. Stopping a short GPS walk from the banner still goes through the same save-or-discard confirmation, because a shortcut should not skip the safety rail.

The important pattern is ownership. A tab-specific view can own rich controls for its mode, but cross-tab recording visibility belongs to `ContentView`, where the tab selection and shared `RecordingCoordinator` already live.

The banner eventually became the single scoreboard too. Walk and Video Walk no longer carry their own time-and-distance cards while recording; duplicating those numbers made the screens busier and created two places to keep visually consistent. Video recordings also get the same right-side stop treatment in the banner, with the actual camera cleanup still delegated back to `VideoWalkView` where the video file is finalized.

### Choosing the Pocket-Sized Release

ASMR Walk kept describing itself as an iPhone app, but the Xcode target was still advertising iPad support. That little checkbox is not a harmless decoration; it invites iPad layouts, multitasking behavior, orientation coverage, screenshots, and review expectations. Shipping iPad support without doing the work would be like printing "all-terrain vehicle" on a bicycle.

Version 1 now draws a clean line: iPhone only. The app can focus on the device that actually matches the walking, camera, DockKit, and one-handed recording story. iPad can still become a real product decision later, but it should arrive with adaptive layouts and testing, not as an accidental build setting.

### The Little Light Learned to Speak

The first video recording indicator was just a tiny green dot. It was technically present, but easy to miss over a moving camera preview, and color alone is a shaky messenger. The fix keeps the lightweight idea but makes it clearer: the dot slowly pulses between 7 and 14 points, and the label beside it says `REC`.

That pulse is deliberately small. No timers, no glowing blur, no animated shadows; just one SwiftUI circle changing size inside a fixed 14-point box. Compared with live camera capture, GPS, and MapKit, this is pocket change, but it gives the user a visible heartbeat that says the video is rolling.

Then UI testing found a stage-management bug: the recording light and the status card were sharing the same spotlight. If the camera or location state needed to show a status card, the explicit recording indicator stepped offstage, even when the app was in a video-recording test state. The fix lets the status card explain the situation while the `REC` indicator remains separately discoverable. In accessibility terms, the warning sign and the "we are recording" sign are different signs; one should not erase the other.

### Ask at the Door, Not on the Sidewalk

Opening a tab used to be enough to make iOS ask for camera, microphone, or location access. That is technically easy and socially clumsy. Permissions are a conversation, and the user should know which button started it.

The recording tabs now refresh permission status on appear without prompting. The actual requests happen when the user starts a walk or video walk. Photos access follows the same rule: saving a finished video explains that ASMR Walk stores video walks in Photos before the Photos request appears, and playback explains that it needs to read saved videos from Photos. The pattern is simple: looking around is free; committing to the feature asks for the keys.

### The Camera Door Should Reopen

Fixing permission timing exposed a second-order bug: once Video Walk stopped asking for camera access on tab open, returning to the tab could leave the camera pipeline unprepared. The screen might sound calm and ready, but the preview was not actually running, and DockKit's shutter wisely refused to start from an unready camera.

The fix gives camera preview startup its own policy. If camera and microphone access are still undetermined, Video Walk waits for the user's Start action and does not prompt. If both are already authorized, the tab prepares the live preview automatically on appear or when the app becomes active again. If access is denied, the UI says privacy access is needed instead of pretending the camera is ready. It is the same door, but now the app checks whether it already has the key before standing in the hallway.

### Background GPS Got a Gatekeeper

Background GPS is powerful and review-sensitive, so the app now routes every decision through `BackgroundRecordingPolicy`. That policy has a short checklist: the user enabled it, the active mode is GPS Walk, a recording is actually running, and iOS granted Always location permission. Miss any one of those and background updates stay off.

This matters most for Video Walk. The settings switch can be on, but video recording still stays foreground-only. Camera capture, screen behavior, and Photos finalization already have enough moving parts; letting video walks silently continue as background GPS sessions would blur the product promise and make App Store review harder to explain. The rule is now easy to test and easy to say: background means walking routes only.

Permission recovery has its own tiny trapdoor. When someone leaves ASMR Walk, enables Location in Settings, and comes back, the Walk tab is still the same SwiftUI view. `onAppear` may not fire, so the old "Location access needed" message can hang around like a stale sign taped to an open door. The fix is to refresh and restart location preview whenever the scene becomes active. Background GPS also gets a clearer recovery path: if the user wants background walks but has only granted When In Use, the Walk tab now offers a direct Settings button for changing Location to Always.

### Testing the Weather, Not Just the Thermostat

Issue #34 exposed a testing blind spot. The app had plenty of polite little tests for policy helpers and result factories, but the riskiest bugs live where services change state: location permission gets denied then granted, When In Use needs to upgrade to Always, the app backgrounds mid-recording, the camera fails to stop, or Photos refuses a save.

The fix was to give those services test handles. `WalkRecorder` now talks to a `WalkLocationClient`, so tests can simulate Core Location authorization and background-update behavior without waking real GPS. Video stopping moved into `VideoWalkStopFlow`, where a fake camera can drive the same coordinator path the app uses. Think of it as practicing the emergency drill with the actual stage directions, just with cardboard props instead of live hardware.

Those fake services quickly paid rent. QA found that discarding an Always-authorized background GPS walk could clear the session while the recorder still claimed to be recording, letting background updates spring back to life during cleanup. The fix is a lifecycle rule worth remembering: before you recompute background privileges, make the state machine tell the truth. Capture the files and IDs you need, invalidate the background activity, transition out of `.recording`, then let policy recompute from honest state.

### When Photos Owned the Video

One earlier design gave video walks a split ownership model: ASMR Walk kept the route, stats, and playback reference while Photos kept the finished movie. That made deletion more like removing an index card from the app's catalog than deleting the movie itself.

That model taught the app to be precise about ownership. Legacy Photos-backed videos still remain in Photos when their ASMR Walk recording is deleted, and any user-saved Photos copy from the newer flow stays in Photos too.

### The Video Came Back Home

User testing flipped the video ownership model back to the simpler mental model: ASMR Walk records the video, ASMR Walk keeps the video, and Photos is an explicit export button instead of the default filing cabinet. New video walks now keep their `.mov` in app-managed storage and History playback uses that local file first. The detail screen offers **Save Video to Photos** when someone wants a copy in their library.

That small shift removes a lot of surprise. Recording no longer depends on Photos permission, playback does not need to ask Photos for the video the app just made, and deleting an ASMR Walk recording can honestly remove the app-managed video while leaving any user-saved Photos copy alone.

### Privacy Strings Need Separate Jobs

The Photos prompts used to say the same generic thing for both add and read access. That is not precise enough. Saving a finished video walk to Photos and reading that video back for route replay are different user moments, so the usage descriptions now say different things.

This is a small copy change with real review weight. Privacy strings are not marketing taglines; they are the labels on the permission keys. If the key opens Photos for saving, say saving. If it opens Photos for replay, say replay.

### Local-First Means Label What Actually Leaves

App Privacy labels are easy to overstate when an app touches sensitive APIs. ASMR Walk uses location, camera, microphone, and Photos, but version 1 does not run a developer backend, analytics pipeline, account system, ad network, or sync service. The important distinction is access versus collection.

Routes, metadata, and newly recorded videos live on the phone inside ASMR Walk. Data leaves ASMR Walk only when the user chooses to share a GPX file, open a Google Maps route link, save a video copy to Photos, or when Apple frameworks such as Photos do their own system-level work based on the user's settings. The release checklist now treats privacy review like checking a valve: verify what actually flows off device before declaring anything collected.

### Checkpoints Learned to Stop Recopying the Trail

The first persistence pass treated every checkpoint like a full rewrite: delete all saved route points, then recreate the entire trail from the latest snapshot. That is simple, but it gets more expensive with every block walked. A long route turns each save into a bigger chore than the last one.

`WalkRecordingPersistence` now treats checkpoints like adding pages to a notebook. Metadata still updates every time, but route points are append-only: if 40 points are already saved and the live snapshot has 75, only points 41 through 75 are inserted. Re-saving the same checkpoint adds nothing, which keeps retries from duplicating points and gives interruption recovery the same final-save path.

### Tests Need Handles, Not Luck

The riskiest release flows live at the edge of iOS: permission denial, Photos fallback, video stop failure, background location, and interruptions. Some of that can only be proven on a phone, but a lot of it can be made deterministic if the app gives tests a clean handle.

Issue 34 added those handles in small places. Video stop handling now has a pure outcome type that can be tested without a camera or Photos library. UI tests can launch into denied-permission states without changing real device settings. The goal is not to fake the whole operating system; it is to make ASMR Walk's response to each operating-system answer predictable and covered.

### Onboarding Tests Need Their Own Front Door

UI tests were walking into the app like regular returning users and hoping the simulator remembered that onboarding had already been completed. That works until someone runs on a clean simulator, deletes the app, changes test order, or lets CI start from a blank slate. Then the test asks for History and the app politely shows the first-run tour instead.

The fix gives tests a proper key to the front door. In DEBUG builds, a launch environment value can seed onboarding as either `completed` or `firstLaunch` before SwiftUI reads `@AppStorage`. Returning-user tests now say "I am a returning user" before launch, while one dedicated test says "show me first launch" and verifies the tour. The onboarding pages also carry explicit accessibility identifiers, because test handles should be door labels, not guesses about how SwiftUI exposes combined text. The simulator's memory is no longer part of the contract.

### Accessibility Is a Weather Report

The recording screens are built on maps, camera previews, glass panels, and compact controls. That looks good in the default forecast, but accessibility settings change the weather: Dynamic Type makes text taller, Reduce Transparency weakens glass, Increase Contrast demands stronger edges, and VoiceOver needs state to be spoken instead of merely colored green or red.

The shared status card and active-recording banner now adapt instead of squeezing. They can reflow from horizontal to vertical, use more solid panel backgrounds when transparency or contrast settings call for it, and expose explicit labels for recording state, time, and distance. Video Walk keeps its route map square, but sizes it from the available landscape space so it gives room back to `REC`, status, and controls on smaller screens. The UI tests also gained an accessibility QA launch mode: not a replacement for Accessibility Inspector, but a repeatable smoke test that says the essentials still have handles when the adaptive surfaces are active.

### Release Docs Need One Story

Documentation can drift like a trail map copied too many times. One page says background GPS exists, another still hints it is future work, and suddenly App Review, QA, and future engineering are all reading different maps.

The release docs now use the same version-one story everywhere: ASMR Walk is iPhone-only, local-first, keeps finished video walks in the app with optional Photos export, GPS-only for optional background recording, and foreground-only for Video Walk. Roadmap items are labeled as future ideas instead of hanging around the feature list in disguise. `APP_STORE_COPY.md` now gives App Store Connect text the same source of truth as the README, checklist, and privacy policy.

### Onboarding Should Tell the Current Truth

The Video Walk onboarding page was still wearing yesterday's name tag. It promised that finished videos go straight to Photos, even after user testing moved the app to local video storage with an explicit **Save Video to Photos** action from History.

That copy matters because onboarding sets the user's mental model before the first permission prompt. The updated text now says the video stays in ASMR Walk and can be copied to Photos later, which lines up with recording, playback, deletion, privacy strings, and the History detail button.

## Engineer's Wisdom

- Make unfinished behavior visibly unfinished. A polished button wired to nothing is worse than an honest foundation state.
- Separate hardware services from views before hardware complexity arrives.
- Prefer system controls. They carry accessibility, platform behavior, and visual updates that custom components must otherwise recreate.
- Treat route fidelity and share convenience as separate export goals: Google Maps for convenience, GPX for accuracy.

## If I Were Starting Over...

This is the starting line, so the main retrospective is a guardrail: define the persistence model and recording state machine before building deep history UI. Real data shapes reveal the right interface faster than elaborate mock screens do.
