# gd-serialization

Convert Godot objects to dictionaries and back for saves, imports, exports, and network boundaries.

Use this addon when you have script-backed data objects and want repeatable dictionary payloads without hand-writing every mapper.

## Installation

### Via gdam

`gdam install @aviorstudio/gd-serialization`

### Manual

Copy `addon/` into `res://addons/@aviorstudio_gd-serialization/` and enable the plugin.

## Quick Start

```gdscript
const ObjectSerializationModule = preload("res://addons/@aviorstudio_gd-serialization/src/object_serialization_module.gd")

var serializer := ObjectSerializationModule.new()

var payload: Dictionary = serializer.to_wire_dict(player_save_data)
var restored: Object = serializer.from_wire_dict(payload, player_save_data.get_script())
```

## Common Uses

- Save script-backed data objects to disk.
- Build JSON-friendly dictionaries for HTTP or WebSocket payloads.
- Clone data objects at system boundaries.
- Normalize dictionary keys before persistence.

## What You Get

- `SerializationConfig`: class resolution, ignored properties, and hydration behavior.
- `to_wire_dict` / `from_wire_dict`: explicit boundary conversion helpers.
- `to_dict` / `from_dict`: shorter compatibility aliases.
- `normalize_keys`: convert dictionary keys to a stable representation.
- `deep_duplicate_for_boundary`: clone nested data for safe handoff.

## Notes

- Serializes script variables, not arbitrary scene-tree state.
- Cyclic object graphs are not supported.
- Reflection has runtime cost, so avoid per-frame serialization in hot loops.
- Engine objects, resources, and nodes should usually have explicit game-level serializers.

## Repository Layout

- `addon/`: Godot plugin source packaged for GDAM and manual installation.
- `addon/plugin.cfg`: plugin name, version, description, and entry script.
- `addon/src/`: reusable GDScript modules.
- `tests/`: Godot test project/scripts for addon behavior.
- `.github/workflows/ci.yml`: validates package shape and runs tests.
- `.github/workflows/release.yml`: creates GitHub release ZIPs and publishes to GDAM.

## Versioning And Releases

The version in `addon/plugin.cfg` is the addon package version. Releases are created from `main` with the manual release workflow and plain semver tags like `v0.0.1`; the workflow verifies `plugin.cfg`, builds `@aviorstudio_gd-serialization.zip`, and publishes `@aviorstudio/gd-serialization` to GDAM.

## Testing

Run locally with:

```sh
./tests/test.sh
```

CI runs the same test script when available.

## License

MIT
