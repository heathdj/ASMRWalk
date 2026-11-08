# Mac Importer Owner Instructions

The importer and overlay targets are already configured in the Xcode project. The original issue #73 target-creation steps have been superseded by the shipped 1.1.0 Mac tools.

## Install and use

Download [Mac Tools 1.1.0](https://github.com/heathdj/ASMRWalk/releases/download/release-1.1.0/ASMR-Walk-Mac-Tools-1.1.0.pkg). Follow [the support page](SUPPORT_PAGE.md) for installation, plugin registration/repair, GPX or synced-library import, prepared maps, and Final Cut Pro use.

## Maintain and rebuild

Follow [Installer/README.md](Installer/README.md) for the signed/notarized package build and installation layout. Build the existing targets; do not create duplicate targets. The importer uses private CloudKit container `iCloud.com.bald-traveler.ASMRWalk`, Push Notifications, and sandbox user-selected file read/write access. Preserve its existing entitlements and signing configuration.

Keep the wrapper's embedded plugin signed and intact. Registration launches the wrapper; it must not modify its signed plugin. The installer replaces only ASMR Walk-owned Motion templates.

## Verify changes

Use [the release checklist](RELEASE_CHECKLIST.md) for import, appearance, long-route segment transitions, registration, and host playback/export regression scenarios. Owner 1.1.0 manual acceptance is recorded in closed issue #79. Future Mac changes require rebuilding and validating the installer; iPhone/Watch-only retry tags do not change the existing Mac download.
