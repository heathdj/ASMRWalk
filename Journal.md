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
