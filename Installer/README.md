# ASMR Walk Mac Tools Installer

Version 1.1.0 ships both Mac-side artifacts in one signed flat package:

- `/Applications/ASMR Walk Mac Importer.app`
- `/Applications/ASMR Walk Route Overlay.app`, containing `Contents/PlugIns/ASMRWalkRouteOverlay.pluginkit`
- `~/Movies/Motion Templates.localized/Generators.localized/ASMR Walk/ASMR Walk Route Overlay`, exposing the generator in Final Cut Pro

The wrapper app is the stable LaunchServices home for the FxPlug component. The importer’s **ASMR Walk Mac Importer > Final Cut Pro Plugin…** command checks both the installed component and the current user’s Motion template, and can launch the wrapper to repair registration. It does not copy or modify signed app bundles itself; rerunning the installer is the repair path for missing or damaged files.

The installer replaces only the `ASMR Walk/ASMR Walk Route Overlay` template owned by this project. Other categories and user-created Motion templates are preserved. Template updates keep the stable display name and category; the bundled `.motn` references the FxPlug UUID rather than a version-specific file path. Interactive package, timing, marker, and map-layout controls are published to Final Cut Pro. Read-only package, timing, and map status strings remain available in Motion but cannot be published by Motion.

## One-time owner setup

1. In Apple Developer Certificates, Identifiers & Profiles, create or install:
   - a **Developer ID Application** certificate;
   - a **Developer ID Installer** certificate;
   - any Developer ID provisioning profile Xcode requests for the importer’s CloudKit entitlements.
2. In Xcode, confirm Release archives for both shared schemes use the same team and Developer ID signing.
3. Store notarization credentials in the keychain:

   ```sh
   xcrun notarytool store-credentials ASMRWalkNotary \
     --apple-id "OWNER_APPLE_ID" \
     --team-id "TEAM_ID" \
     --password "APP_SPECIFIC_PASSWORD"
   ```

4. Confirm Final Cut Pro or Motion is installed on the validation Mac.

## Build, sign, and notarize

Run from the repository root:

```sh
TEAM_ID="TEAM_ID" \
INSTALLER_SIGN_IDENTITY="Developer ID Installer: OWNER NAME (TEAM_ID)" \
NOTARY_PROFILE="ASMRWalkNotary" \
VERSION="1.1.0" \
./Installer/build-release-installer.sh
```

The script validates the Motion template, archives and Developer ID exports both apps, verifies their nested signatures, builds a signed distribution `.pkg` with a BSD 3-Clause license page, submits it to Apple’s notary service, staples the ticket, and writes the finished package under `Installer/Output`. Do not distribute a package built without `NOTARY_PROFILE`; that mode exists only for diagnosing signing locally.

## Install and validate

1. Quit Final Cut Pro and Motion.
2. Open the notarized package and install it.
3. Run `./Installer/verify-installed-tools.sh`. The script verifies both app signatures, validates the installed Motion template, asks Gatekeeper to assess the apps, launches the wrapper, and confirms the FxPlug identifier is visible in PlugInKit.
4. Open the importer and choose **ASMR Walk Mac Importer > Final Cut Pro Plugin…**. It should report that both the plugin and generator template are installed. Press **Register or Repair Plugin** once after a fresh installation.
5. Quit and reopen Motion. Confirm **ASMR Walk Route Overlay** appears in the **ASMR Walk** group and can be added to a new project.
6. Quit and reopen Final Cut Pro. Confirm the generator appears under **Generators > ASMR Walk**, can be connected above footage, and exposes route-package selection and timing offset in the inspector.
7. Continue with the full timeline/export matrix in issue #79.

If the wrapper or embedded plugin is missing, has the wrong identifier, or fails signature validation, rerun the same notarized installer. Never replace only the nested `.pluginkit`; modifying a signed wrapper invalidates its signature.

To uninstall the Mac tools, remove the two ASMR Walk apps from `/Applications` and remove only `~/Movies/Motion Templates.localized/Generators.localized/ASMR Walk/ASMR Walk Route Overlay`. Leave the enclosing `ASMR Walk` category in place if it contains other templates. Forgetting the package receipt with `sudo pkgutil --forget com.bald-traveler.ASMRWalk.MacTools` is optional and does not remove files.
