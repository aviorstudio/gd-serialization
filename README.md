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

var encoded: Dictionary = serializer.to_wire_dict(player_save_data)
if not encoded.ok:
    push_error(encoded.errors)
    return

var decoded: Dictionary = serializer.from_wire_dict(encoded.value, player_save_data.get_script())
if not decoded.ok:
    push_error(decoded.errors)
    return
var restored: Object = decoded.value
```

## Common Uses

- Save script-backed data objects to disk.
- Build JSON-friendly dictionaries for HTTP or WebSocket payloads.
- Clone data objects at system boundaries.
- Normalize dictionary keys before persistence.

## What You Get

- `SerializationConfig`: class resolution, ignored properties, caching, and payload bounds.
- `to_wire_dict` / `from_wire_dict`: strict boundary conversion helpers.
- `to_dict` / `from_dict`: equivalent strict result-returning names.
- `normalize_keys`: convert dictionary keys to a stable representation.
- `deep_duplicate_for_boundary`: clone nested data for safe handoff.

## Notes

- Every serialization/hydration method returns `{ok, value, errors}`. On failure,
  `value` is `null`; each error has stable `code`, `path`, and `message` fields.
- **Correction (fieldsofrevik#153):** Previous versions accepted engine properties
  during hydration and silently defaulted or skipped mismatched values. Hydration
  now accepts declared script variables only, validates before assignment, and
  verifies setter readback. A failed temporary object's setter side effects cannot
  be rolled back, so boundary model setters should remain side-effect free.
- Defaults are depth 32, 10,000 visited nodes, 1,000 items per collection,
  1 MiB per UTF-8 string, and 1 MiB per byte array. All limits are configurable
  and values below one are rejected.
- Dictionary keys must be strings. Packed bytes use JSON integer arrays, and
  `Vector2i` uses exactly `{x, y}`. Non-finite numbers and unsupported Godot
  values fail instead of becoming `null`.
- Container and object cycles return `CYCLE_DETECTED`.
- Godot 4.7.2's JSON parser emits number tokens as floats. Finite integral floats
  are therefore accepted for integer fields, bytes, and `Vector2i` coordinates
  only when exact and in range; other lossy numeric conversions are rejected.
- Nested object hydration requires a global script class or an explicit
  `class_resolver`; arbitrary `to_dict`/`from_dict` hooks are never invoked.
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

**Correction (fieldsofrevik#153):** Earlier documentation said CI ran the test
script "when available", which could imply a missing suite was allowed to skip.
CI and release now require the Godot 4.7.2 suite, fail on runtime errors and
timeouts, prove assertion reach, and verify the exact closed-manifest ZIP through
an enable/restart/smoke/disable/restart editor lifecycle.

## License

MIT
