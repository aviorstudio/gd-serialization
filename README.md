# gd-serialization

Game-agnostic object serialization helpers for Godot 4.

- Package: `@aviorstudio/gd-serialization`
- Godot: `4.x` (tested on `4.4`)

## Install

Place this folder under `res://addons/<addon-dir>/` (for example `res://addons/@aviorstudio_gd-serialization/`).

- With `gdpm`: install/link into your project's `addons/`.
- Manually: copy or symlink this repo folder into `res://addons/<addon-dir>/`.

## Files

- `plugin.cfg` / `plugin.gd`: editor plugin entry (no runtime behavior).
- `src/object_serialization_module.gd`: object ↔ dictionary serialization helpers.

## Usage

```gdscript
const ObjectSerializationModule = preload("res://addons/<addon-dir>/src/object_serialization_module.gd")

var serializer := ObjectSerializationModule.new()
var payload := serializer.to_dict(my_data)
```
