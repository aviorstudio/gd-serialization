# gd-serialization

Convert Godot objects to dictionaries and back for saves, imports, exports, and network boundaries.

Use this addon when you have script-backed data objects and want repeatable dictionary payloads without hand-writing every mapper.

## Installation

### Via gdpm

`gdpm install @aviorstudio/gd-serialization`

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

## Testing

`./tests/test.sh`

## License

MIT
