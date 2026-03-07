# gd-serialization

Reflective serialization helpers for persistence and transport boundaries in Godot 4.

This addon is intentionally not a recommendation for hot runtime state propagation.

## Installation

### Via gdpm
`gdpm install @aviorstudio/gd-serialization`

### Manual
Copy this directory into `addons/@aviorstudio_gd-serialization/` and enable the plugin.

## Quick Start

```gdscript
const ObjectSerializationModule = preload("res://addons/@aviorstudio_gd-serialization/src/object_serialization_module.gd")

var serializer := ObjectSerializationModule.new()
var payload: Dictionary = serializer.to_wire_dict(my_data)
var clone: Object = serializer.from_wire_dict(payload, my_data.get_script())
```

## API Reference

- `SerializationConfig`: class resolver, ignored property controls, and optional `skip_type_mismatch` behavior for safer `from_dict` hydration.
- `to_wire_dict` / `from_wire_dict`: explicit boundary-named object-dictionary conversion.
- `to_dict` / `from_dict`: compatibility aliases for existing callers.
- `normalize_keys`, `serialize_slot_keyed_dict`, `deserialize_slot_keyed_dict`.
- `deep_duplicate_for_boundary`: reflective deep clone helper for boundary workflows.

## Scope Boundary

- In scope: persistence/tooling/import-export/wire payload conversion.
- Out of scope: hot gameplay loops and repeated in-memory object movement.

## Configuration

No project settings are required.

## Testing

`./tests/test.sh`

## License

MIT
