# Issue #76 Historical Setup: FxPlug Generator Target

These targets are already configured. Do not recreate them for installation or submission. Use [the current installer instructions](../../../Installer/README.md) and [support instructions](../../../SUPPORT_PAGE.md). The setup below is retained as engineering history, not an outstanding owner task.

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

The original scaffold scope is complete. Route rendering (#77), timing/performance (#78), and FCP/Motion release validation (#79) are also complete; #79 records owner manual verification. See the current release checklist for future regression scenarios.
