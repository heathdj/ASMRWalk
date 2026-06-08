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

## Engineer's Wisdom

- Make unfinished behavior visibly unfinished. A polished button wired to nothing is worse than an honest foundation state.
- Separate hardware services from views before hardware complexity arrives.
- Prefer system controls. They carry accessibility, platform behavior, and visual updates that custom components must otherwise recreate.
- Treat route fidelity and share convenience as separate export goals: Google Maps for convenience, GPX for accuracy.

## If I Were Starting Over...

This is the starting line, so the main retrospective is a guardrail: define the persistence model and recording state machine before building deep history UI. Real data shapes reveal the right interface faster than elaborate mock screens do.
