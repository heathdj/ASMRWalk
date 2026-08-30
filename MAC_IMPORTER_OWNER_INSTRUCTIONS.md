# Mac Importer Owner Instructions

Issue #73 adds source files for the first Mac-side importer workflow. The project still needs owner action in Xcode because creating targets and changing project membership requires editing the project file.

## Target Setup

1. In Xcode, add a new macOS App target named `ASMR Walk Mac Importer`.
2. Use SwiftUI for the interface and Swift for the language.
3. Add these files to the new target:
   - `ASMR Walk Mac Importer/ASMRWalkMacImporterApp.swift`
   - `ASMR Walk Mac Importer/MacImporterView.swift`
   - `ASMR Walk Mac Importer/MacImporterViewModel.swift`
   - `ASMR Walk/Features/History/ASMRRoutePackage.swift`
   - `ASMR Walk/Features/History/ASMRGPXRouteImporter.swift`
   - `ASMR Walk/Models/RecordingMode.swift`
   - `ASMR Walk/Models/WalkRecordingSource.swift`
4. Leave `ASMRRoutePackage+WalkRouteExport.swift`, `WalkRouteExport.swift`, `WalkRecording.swift`, and `LocationPoint.swift` in the iPhone target for now. Those files adapt live app records into packages, but the Mac GPX importer does not need SwiftData model access for this issue.

## Capabilities

For the first GPX-to-package workflow:

- Enable App Sandbox.
- Allow user-selected file read access.
- Allow user-selected file read/write access for the output package folder.

CloudKit and Photos capabilities are intentionally not required for this issue. Those belong to the later #60 and #74 child issues.

## Manual Verification

1. Export a GPX route from the iPhone app.
2. Launch the Mac importer.
3. Choose the exported `.gpx` file.
4. Choose an output folder.
5. Confirm a `.asmrroute` package is created with:
   - `manifest.json`
   - `route-points.json`
   - `source.gpx`
6. Confirm the package loads with `ASMRRoutePackage.load(from:)`.
