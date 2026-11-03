#!/bin/zsh

set -euo pipefail

IMPORTER_APP="/Applications/ASMR Walk Mac Importer.app"
OVERLAY_APP="/Applications/ASMR Walk Route Overlay.app"
PLUGIN_PATH="${OVERLAY_APP}/Contents/PlugIns/ASMRWalkRouteOverlay.pluginkit"
PLUGIN_IDENTIFIER="com.bald-traveler.ASMRWalkRouteOverlay"
MOTION_TEMPLATE="${HOME}/Movies/Motion Templates.localized/Generators.localized/ASMR Walk/ASMR Walk Route Overlay"

for path_to_check in "${IMPORTER_APP}" "${OVERLAY_APP}" "${PLUGIN_PATH}"; do
    if [[ ! -e "${path_to_check}" ]]; then
        echo "Missing required installed component: ${path_to_check}" >&2
        exit 1
    fi
done

if [[ ! -d "${MOTION_TEMPLATE}" ]]; then
    echo "Missing installed Motion template: ${MOTION_TEMPLATE}" >&2
    exit 1
fi

"${0:A:h}/validate-motion-template.sh" "${MOTION_TEMPLATE}"

codesign --verify --deep --strict --verbose=2 "${IMPORTER_APP}"
codesign --verify --deep --strict --verbose=2 "${OVERLAY_APP}"
spctl --assess --type execute --verbose=2 "${IMPORTER_APP}"
spctl --assess --type execute --verbose=2 "${OVERLAY_APP}"

open -gj "${OVERLAY_APP}"
pluginkit -a "${PLUGIN_PATH}"

PLUGIN_MATCHES=$(pluginkit -m -p FxPlug -i "${PLUGIN_IDENTIFIER}")
if [[ -z "${PLUGIN_MATCHES}" ]]; then
    echo "PlugInKit did not report ${PLUGIN_IDENTIFIER}." >&2
    exit 1
fi

echo "${PLUGIN_MATCHES}"
echo "ASMR Walk Mac tools and Motion generator are installed and visible to PlugInKit."
