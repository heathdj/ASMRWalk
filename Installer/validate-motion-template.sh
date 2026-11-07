#!/bin/zsh

set -euo pipefail

TEMPLATE_DIRECTORY=${1:?Pass the ASMR Walk Route Overlay template directory.}
DOCUMENT_PATH="${TEMPLATE_DIRECTORY}/ASMR Walk Route Overlay.motn"
PLUGIN_UUID="D3A901A9-B749-4B9D-AF3D-F28509A457DF"

for required_path in "${DOCUMENT_PATH}" "${TEMPLATE_DIRECTORY}/large.png" "${TEMPLATE_DIRECTORY}/small.png"; do
    if [[ ! -f "${required_path}" ]]; then
        echo "Missing required Motion template file: ${required_path}" >&2
        exit 1
    fi
done

xmllint --noout "${DOCUMENT_PATH}"

if ! grep -Fq "pluginUUID=\"${PLUGIN_UUID}\"" "${DOCUMENT_PATH}"; then
    echo "Motion template does not reference the ASMR Walk FxPlug UUID." >&2
    exit 1
fi

REQUIRED_PUBLISHED_TARGETS=(
    '<target object="10012" channel="./2/1/11" name="Choose or Replace Route Package…"/>'
    '<target object="10012" channel="./2/1/12" name="Clear Route Package"/>'
    '<target object="10012" channel="./2/1/4" name="Route Timing"/>'
    '<target object="10012" channel="./2/1/14" name="Timing Offset (seconds)"/>'
    '<target object="10012" channel="./2/1/2" name="Show Current Position"/>'
    '<target object="10012" channel="./2/1/3" name="Show Start and End Markers"/>'
    '<target object="10012" channel="./2/1/5" name="Map Background"/>'
    '<target object="10012" channel="./2/1/16" name="Map Appearance"/>'
    '<target object="10012" channel="./2/1/6" name="Map Position"/>'
    '<target object="10012" channel="./2/1/7" name="Map Size"/>'
    '<target object="10012" channel="./2/1/8" name="Map Corners"/>'
    '<target object="10012" channel="./2/1/9" name="Map Opacity"/>'
)

for published_target in "${REQUIRED_PUBLISHED_TARGETS[@]}"; do
    if ! grep -Fq "${published_target}" "${DOCUMENT_PATH}"; then
        echo "Motion template is missing required published target: ${published_target}" >&2
        exit 1
    fi
done

if grep -Eq '<target[^>]+name="(Width|Height)"' "${DOCUMENT_PATH}"; then
    echo "Motion template unexpectedly publishes fixed render dimensions." >&2
    exit 1
fi

if grep -Eq '/Users/|file://' "${DOCUMENT_PATH}"; then
    echo "Motion template contains a user-specific or file URL." >&2
    exit 1
fi

if [[ -d "${TEMPLATE_DIRECTORY}/Media" ]] && \
   [[ -n "$(find "${TEMPLATE_DIRECTORY}/Media" -type f -print -quit)" ]]; then
    echo "Motion template unexpectedly contains local media." >&2
    exit 1
fi

echo "ASMR Walk Motion generator template is valid."
