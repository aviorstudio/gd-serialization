#!/usr/bin/env bash
set -euo pipefail

GODOT="${GODOT_BIN:-godot}"
ZIP=${1:?usage: verify-package.sh PACKAGE.zip}
FIXTURE=$(mktemp -d)
trap 'rm -rf "$FIXTURE"' EXIT
ADDON_DIR="@aviorstudio_gd-serialization"
INSTALL="$FIXTURE/addons/$ADDON_DIR"
mkdir -p "$INSTALL"

if unzip -Z1 "$ZIP" | grep -Eq '(^/|(^|/)\.\.(/|$)|(^|/)[^/]+/$)'; then
    echo "ERROR: archive contains an absolute/traversal path or undeclared directory entry" >&2
    exit 1
fi
EXPECTED=$'plugin.cfg\nplugin.gd\nplugin.gd.uid\nsrc/object_serialization_module.gd\nsrc/object_serialization_module.gd.uid'
ACTUAL=$(unzip -Z1 "$ZIP" | sort)
[[ "$ACTUAL" == "$EXPECTED" ]] || {
    echo "ERROR: closed archive manifest mismatch" >&2
    printf '%s\n' "$ACTUAL" >&2
    exit 1
}
unzip -q "$ZIP" -d "$INSTALL"
if find "$INSTALL" -type l -print -quit | grep -q .; then
    echo "ERROR: installed tree contains a symlink" >&2
    exit 1
fi

cat >"$FIXTURE/project.godot" <<EOF
[application]
config/name="gd-serialization package fixture"
[studio_control]
consumer_owned="preserve-me"
[editor_plugins]
enabled=PackedStringArray("res://addons/$ADDON_DIR/plugin.cfg")
EOF
cat >"$FIXTURE/smoke.gd" <<EOF
extends SceneTree
func _initialize() -> void:
    var script = load("res://addons/$ADDON_DIR/src/object_serialization_module.gd")
    if script == null or script.new() == null:
        push_error("packaged serializer smoke failed")
        quit(1)
        return
    print("PACKAGE_SMOKE_REACHED:1")
    quit(0)
EOF

"$GODOT" --headless --editor --path "$FIXTURE" --quit-after 2
"$GODOT" --headless --editor --path "$FIXTURE" --quit-after 2
smoke_log=$("$GODOT" --headless --path "$FIXTURE" --script "$FIXTURE/smoke.gd" 2>&1)
printf '%s\n' "$smoke_log"
grep -q '^PACKAGE_SMOKE_REACHED:1$' <<<"$smoke_log"

cat >"$FIXTURE/project.godot" <<EOF
[application]
config/name="gd-serialization package fixture"
[studio_control]
consumer_owned="preserve-me"
[editor_plugins]
enabled=PackedStringArray()
EOF
"$GODOT" --headless --editor --path "$FIXTURE" --quit-after 2
"$GODOT" --headless --editor --path "$FIXTURE" --quit-after 2
grep -q 'consumer_owned="preserve-me"' "$FIXTURE/project.godot"
if grep -q '^\[autoload\]' "$FIXTURE/project.godot"; then
    echo "ERROR: addon left an owned autoload after disable/restart" >&2
    exit 1
fi
(cd "$INSTALL" && find . -type f -print0 | sort -z | xargs -0 sha256sum) | sha256sum | sed 's/  -$/  installed-tree/'
echo "PACKAGE_LIFECYCLE_PASS:enable-restart-smoke-disable-restart-cleanup"
