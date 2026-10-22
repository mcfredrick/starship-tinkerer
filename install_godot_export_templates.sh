#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
	cat <<'EOF'
Usage: install_godot_export_templates.sh <godot_version>

Environment variables:
  GODOT_TEMPLATES_URL  Optional. Overrides the download URL.
  FORCE_INSTALL        Set to 1 to force reinstallation even if templates exist.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	usage
	exit 0
fi

if [[ $# -ge 1 ]]; then
	GODOT_VERSION="$1"
elif [[ -n "${GODOT_VERSION:-}" ]]; then
	GODOT_VERSION="${GODOT_VERSION}"
else
	echo "Error: Godot version not provided." >&2
	usage
	exit 1
fi

if [[ -z "${GODOT_VERSION}" ]]; then
	echo "Error: Empty Godot version string." >&2
	exit 1
fi

if [[ "$(uname)" == "Darwin" ]]; then
	EXPORT_ROOT="${HOME}/Library/Application Support/Godot/export_templates"
else
	EXPORT_ROOT="${HOME}/.local/share/godot/export_templates"
fi

TARGET_DIR="${EXPORT_ROOT}/${GODOT_VERSION}.stable"

if [[ -d "${TARGET_DIR}" && "${FORCE_INSTALL:-0}" != "1" ]]; then
	echo "Godot export templates already present in ${TARGET_DIR}"
	exit 0
fi

DEFAULT_URL="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_export_templates.tpz"
DOWNLOAD_URL="${GODOT_TEMPLATES_URL:-$DEFAULT_URL}"

TMP_DIR="$(mktemp -d)"
cleanup() {
	rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

ARCHIVE="${TMP_DIR}/templates.tpz"

echo "Downloading export templates for Godot ${GODOT_VERSION}..."
curl -L "${DOWNLOAD_URL}" -o "${ARCHIVE}"

echo "Extracting templates..."
unzip -qo "${ARCHIVE}" -d "${TMP_DIR}/unzipped"

if [[ ! -d "${TMP_DIR}/unzipped/templates" ]]; then
	echo "Error: Downloaded archive does not contain a templates directory." >&2
	exit 1
fi

echo "Installing templates into ${TARGET_DIR}"
rm -rf "${TARGET_DIR}"
mkdir -p "${TARGET_DIR}"
cp -R "${TMP_DIR}/unzipped/templates/." "${TARGET_DIR}/"

echo "Templates installed successfully."
