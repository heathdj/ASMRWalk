# ASMR Walk Project Memory

## Overview

ASMR Walk is an iPhone walking journal. It will record GPS routes, optionally pair a route with a walk video, keep recordings locally, and export routes for use outside the app.

## Architecture Decisions

- SwiftUI owns the interface and top-level tab navigation.
- SwiftData will persist walk metadata and route points locally.
- `WalkRecording` is the SwiftData root model and owns `LocationPoint` children with a cascade delete rule.
- Sample recordings are created through `SampleData` and only inserted into in-memory preview/test containers.
- Core Location will be isolated behind a recording service so views do not manage location callbacks directly.
- AVFoundation video capture will remain separate from GPS tracking; both outputs will be linked by one walk recording.
- Version 1 will render map overlays in the app instead of burning them into exported video.

## Conventions

- Prefer Swift concurrency and async sequences over completion-handler APIs.
- Inject services into features so location, camera, and export behavior can be tested.
- Keep recording state in dedicated observable types, not inside large SwiftUI views.
- Use standard SwiftUI controls first so the interface follows the iOS 26 Liquid Glass system automatically.
- Store video files in app-managed storage and persist only their URLs.

## Build And Run

Open the project in Xcode, select the `ASMR Walk` scheme, and run on an iOS 26 simulator or device. Location and camera recording must ultimately be verified on a physical iPhone.

## Gotchas

- Google Maps URLs cannot preserve every recorded route point; GPX is the fidelity-preserving export.
- Foreground location recording is the initial scope. Background recording requires more permissions and capabilities.
- Camera, microphone, and location usage descriptions must be configured before their APIs are requested.
- Route points need accuracy and distance filtering before they affect distance totals or persistence.
