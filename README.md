# gd-serialization

Object serialization utilities for Godot 4 data models.

## Installation

### Via gdpm
`gdpm install @aviorstudio/gd-serialization`

### Manual
Copy this directory into `addons/@aviorstudio_gd-serialization/` and enable the plugin.

## Quick Start

```gdscript
const ObjectSerializationModule = preload("res://addons/@aviorstudio_gd-serialization/src/object_serialization_module.gd")

var serializer := ObjectSerializationModule.new()
var payload: Dictionary = serializer.to_dict(my_data)
var clone: Object = serializer.from_dict(payload, my_data.get_script())
```

## API Reference

- `SerializationConfig`: class resolver and ignored property controls.
- `to_dict` / `from_dict`: object-dictionary conversion.
- `normalize_keys`, `serialize_slot_keyed_dict`, `deserialize_slot_keyed_dict`.
- `deep_duplicate`: typed deep clone helper.

## Configuration

No project settings are required.

## Testing

`./run_tests.sh`

## License

MIT
