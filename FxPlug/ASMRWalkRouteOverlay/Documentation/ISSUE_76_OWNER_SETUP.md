# Issue #76 Owner Setup: FxPlug Generator Target

Issue #76 creates the bring-up path for the ASMR Walk Route Overlay FxPlug generator. The checked-in scaffold under `FxPlug/ASMRWalkRouteOverlay` documents the desired shape, and the active Xcode target now uses the target-local files under `ASMRWalkRouteOverlay`.

## Local Prerequisites

- Install the FxPlug SDK.
- Confirm these paths exist:
  - `/Library/Developer/SDKs/FxPlug.sdk`
  - `/Library/Developer/SDKs/FxPlug.sdk/Library/Frameworks/FxPlug.framework`
  - `/Library/Developer/SDKs/FxPlug.sdk/Library/Frameworks/PluginManager.framework`
  - `/Library/Developer/Frameworks/FxPlug.framework`
  - `/Library/Developer/Frameworks/PluginManager.framework`
- Install Motion and/or Final Cut Pro for host validation.

## Xcode Target Setup

1. Create a new macOS wrapper app target named `ASMR Walk Route Overlay`.
2. Add a new XPC Service target named `ASMRWalkRouteOverlay`.
3. Set the XPC service target's Wrapper Extension build setting to `pluginkit`.
4. Embed the XPC service in the wrapper app using an Embed PlugIns or Copy Files build phase with code signing enabled.
5. Add `FxPlug.framework` and `PluginManager.framework` to the XPC service target.
6. Add these build settings to the XPC service target:
   - Framework Search Paths: `/Library/Developer/SDKs/FxPlug.sdk/Library/Frameworks /Library/Developer/Frameworks $(inherited)`
   - Additional SDKs: `/Library/Developer/SDKs/FxPlug.sdk`
   - Objective-C Bridging Header: `FxPlug/ASMRWalkRouteOverlay/ASMRWalkRouteOverlay/ASMRWalkRouteOverlay-Bridging-Header.h`
7. Use `ASMRWalkRouteOverlay/Info.plist` as the XPC service Info.plist.
8. Add these source files to the XPC service target:
   - `main.swift`
   - `ASMRWalkRouteOverlay.swift`
   - `ASMRRoutePackageInput.swift`

## Bundle Identifiers

Suggested development identifiers:

- Wrapper app: `com.bald-traveler.ASMRWalk.RouteOverlay`
- XPC service/plugin: `com.bald-traveler.ASMRWalk.RouteOverlay.ASMRWalkRouteOverlay`

Use the same Apple development team as the Mac importer unless signing policy requires a separate identifier.

## Validation

1. Build the wrapper app and XPC service.
2. Confirm `ASMRWalkRouteOverlay.pluginkit` is embedded under `ASMR Walk Route Overlay.app/Contents/PlugIns`.
3. Run the wrapper app once.
4. Query PlugInKit:

   ```sh
   pluginkit -m -p FxPlug | grep "ASMR Walk Route Overlay"
   ```

5. Launch Motion and confirm the generator appears under the `ASMR Walk` group.
6. For Final Cut Pro, create or update the Motion template wrapper needed to expose the generator to Final Cut Pro.

## Scope Boundary

This issue is complete when the target builds and the generator is discoverable. Real route drawing from `.asmrroute` packages belongs to #77, timing/performance refinements belong to #78, and full FCP/Motion release validation belongs to #79.
