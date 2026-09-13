#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
REPOSITORY="${GITHUB_REPOSITORY:-}"
OWNER="${REPOSITORY%%/*}"
REPO="${REPOSITORY#*/}"
if [[ -z "$REPOSITORY" || "$OWNER" == "$REPO" ]]; then
    OWNER=aviorstudio
    REPO=gd-serialization
fi
ADDON_DIR="@${OWNER}_${REPO}"
DIST="$ROOT/dist"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

EXPECTED=(
    plugin.cfg
    plugin.gd
    plugin.gd.uid
    src/object_serialization_module.gd
    src/object_serialization_module.gd.uid
)

for relative in "${EXPECTED[@]}"; do
    source_path="$ROOT/addon/$relative"
    [[ -f "$source_path" && ! -L "$source_path" ]] || {
        echo "ERROR: missing, non-file, or symlinked package entry: addon/$relative" >&2
        exit 1
    }
    mkdir -p "$STAGE/$(dirname "$relative")"
    cp "$source_path" "$STAGE/$relative"
done

mapfile -t ACTUAL < <(cd "$ROOT/addon" && find . -type f -printf '%P\n' | sort)
mapfile -t DECLARED < <(printf '%s\n' "${EXPECTED[@]}" | sort)
[[ "${ACTUAL[*]}" == "${DECLARED[*]}" ]] || {
    echo "ERROR: package manifest mismatch" >&2
    exit 1
}

rm -rf "$DIST"
mkdir -p "$DIST"
(cd "$STAGE" && TZ=UTC zip -X -q "$DIST/${ADDON_DIR}.zip" "${EXPECTED[@]}")
sha256sum "$DIST/${ADDON_DIR}.zip" | tee "$DIST/${ADDON_DIR}.zip.sha256"
