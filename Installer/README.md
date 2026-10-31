# ASMR Walk Mac Tools Installer

Version 1.1.0 ships both Mac-side artifacts in one signed flat package:

- `/Applications/ASMR Walk Mac Importer.app`
- `/Applications/ASMR Walk Route Overlay.app`, containing `Contents/PlugIns/ASMRWalkRouteOverlay.pluginkit`

The wrapper app is the stable LaunchServices home for the FxPlug component. The importer’s **ASMR Walk Mac Importer > Final Cut Pro Plugin…** command checks the installed bundle and can launch the wrapper to repair registration. It does not copy or modify signed app bundles itself; rerunning the installer is the repair path for missing or damaged files.

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

The script archives and Developer ID exports both apps, verifies their nested signatures, builds a signed `.pkg`, submits it to Apple’s notary service, staples the ticket, and writes the finished package under `Installer/Output`. Do not distribute a package built without `NOTARY_PROFILE`; that mode exists only for diagnosing signing locally.

## Install and validate

1. Quit Final Cut Pro and Motion.
2. Open the notarized package and install it.
3. Run `./Installer/verify-installed-tools.sh`. The script verifies both app signatures, asks Gatekeeper to assess them, launches the wrapper, and confirms the FxPlug identifier is visible in PlugInKit.
4. Open the importer and choose **ASMR Walk Mac Importer > Final Cut Pro Plugin…**. It should report that the plugin is installed. Press **Register or Repair Plugin** once after a fresh installation.
5. Quit and reopen Motion. Confirm **ASMR Walk Route Overlay** appears in the **ASMR Walk** group and can be added to a new project.
6. Final Cut Pro requires the Motion generator template tracked by issue #131. After that template is installed, confirm it appears in Final Cut Pro and exposes the FxPlug inspector controls.
7. Continue the package-selection and timing checks from issue #124, followed by the full timeline/export matrix in issue #79.

If the wrapper or embedded plugin is missing, has the wrong identifier, or fails signature validation, rerun the same notarized installer. Never replace only the nested `.pluginkit`; modifying a signed wrapper invalidates its signature.
