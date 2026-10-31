#!/bin/zsh

set -euo pipefail

SCRIPT_DIRECTORY=${0:A:h}
PROJECT_DIRECTORY=${SCRIPT_DIRECTORY:h}
OUTPUT_DIRECTORY=${1:-${PROJECT_DIRECTORY}/Installer/Output}
VERSION=${VERSION:-1.1.0}
TEAM_ID=${TEAM_ID:?Set TEAM_ID to the Apple Developer team identifier.}
INSTALLER_SIGN_IDENTITY=${INSTALLER_SIGN_IDENTITY:?Set INSTALLER_SIGN_IDENTITY to a Developer ID Installer certificate name.}
NOTARY_PROFILE=${NOTARY_PROFILE:-}

WORK_DIRECTORY=$(mktemp -d "${TMPDIR:-/tmp}/asmr-walk-installer.XXXXXX")
trap 'rm -rf "${WORK_DIRECTORY}"' EXIT

ARCHIVE_DIRECTORY=${WORK_DIRECTORY}/Archives
EXPORT_DIRECTORY=${WORK_DIRECTORY}/Exports
PAYLOAD_DIRECTORY=${WORK_DIRECTORY}/Payload
EXPORT_OPTIONS=${WORK_DIRECTORY}/ExportOptions.plist
PACKAGE_PATH=${OUTPUT_DIRECTORY}/ASMR-Walk-Mac-Tools-${VERSION}.pkg

mkdir -p "${ARCHIVE_DIRECTORY}" "${EXPORT_DIRECTORY}" "${PAYLOAD_DIRECTORY}/Applications" "${OUTPUT_DIRECTORY}"
sed "s/__TEAM_ID__/${TEAM_ID}/g" "${SCRIPT_DIRECTORY}/DeveloperIDExportOptions.plist" > "${EXPORT_OPTIONS}"

archive_and_export() {
    local scheme_name=$1
    local archive_name=$2
    local export_name=$3

    xcodebuild archive \
        -project "${PROJECT_DIRECTORY}/ASMR Walk.xcodeproj" \
        -scheme "${scheme_name}" \
        -configuration Release \
        -destination "generic/platform=macOS" \
        -archivePath "${ARCHIVE_DIRECTORY}/${archive_name}.xcarchive" \
        -allowProvisioningUpdates \
        DEVELOPMENT_TEAM="${TEAM_ID}"

    xcodebuild -exportArchive \
        -archivePath "${ARCHIVE_DIRECTORY}/${archive_name}.xcarchive" \
        -exportPath "${EXPORT_DIRECTORY}/${export_name}" \
        -exportOptionsPlist "${EXPORT_OPTIONS}" \
        -allowProvisioningUpdates
}

archive_and_export "ASMR Walk Mac Importer" "MacImporter" "MacImporter"
archive_and_export "ASMR Walk Route Overlay" "RouteOverlay" "RouteOverlay"

ditto \
    "${EXPORT_DIRECTORY}/MacImporter/ASMR Walk Mac Importer.app" \
    "${PAYLOAD_DIRECTORY}/Applications/ASMR Walk Mac Importer.app"
ditto \
    "${EXPORT_DIRECTORY}/RouteOverlay/ASMR Walk Route Overlay.app" \
    "${PAYLOAD_DIRECTORY}/Applications/ASMR Walk Route Overlay.app"

codesign --verify --deep --strict --verbose=2 \
    "${PAYLOAD_DIRECTORY}/Applications/ASMR Walk Mac Importer.app"
codesign --verify --deep --strict --verbose=2 \
    "${PAYLOAD_DIRECTORY}/Applications/ASMR Walk Route Overlay.app"

pkgbuild \
    --root "${PAYLOAD_DIRECTORY}" \
    --install-location / \
    --identifier "com.bald-traveler.ASMRWalk.MacTools" \
    --version "${VERSION}" \
    --ownership recommended \
    --sign "${INSTALLER_SIGN_IDENTITY}" \
    "${PACKAGE_PATH}"

if [[ -n "${NOTARY_PROFILE}" ]]; then
    xcrun notarytool submit "${PACKAGE_PATH}" \
        --keychain-profile "${NOTARY_PROFILE}" \
        --wait
    xcrun stapler staple "${PACKAGE_PATH}"
    xcrun stapler validate "${PACKAGE_PATH}"
else
    echo "NOTARY_PROFILE is not set; the signed package was not notarized."
fi

pkgutil --check-signature "${PACKAGE_PATH}"
echo "Created ${PACKAGE_PATH}"
