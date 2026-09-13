## Strict, bounded JSON-wire serialization for script-backed Godot data models.
class_name ObjectSerializationModule
extends RefCounted

const DEFAULT_IGNORED_PROPERTY_NAMES: Array[String] = ["RefCounted", "script", "Script Variables"]
const MAX_EXACT_FLOAT_INTEGER := 9007199254740992

var _property_cache: Dictionary = {}

class SerializationConfig extends RefCounted:
	var class_resolver: Callable
	var ignored_properties: Array[String]
	var cache_enabled: bool
	var max_depth: int
	var max_nodes: int
	var max_collection_items: int
	var max_string_bytes: int
	var max_byte_array_bytes: int

	func _init(
		class_resolver: Callable = Callable(),
		ignored_properties: Array[String] = DEFAULT_IGNORED_PROPERTY_NAMES,
		cache_enabled: bool = true,
		max_depth: int = 32,
		max_nodes: int = 10_000,
		max_collection_items: int = 1_000,
		max_string_bytes: int = 1_048_576,
		max_byte_array_bytes: int = 1_048_576
	) -> void:
		self.class_resolver = class_resolver
		self.ignored_properties = ignored_properties.duplicate()
		self.cache_enabled = cache_enabled
		self.max_depth = max_depth
		self.max_nodes = max_nodes
		self.max_collection_items = max_collection_items
		self.max_string_bytes = max_string_bytes
		self.max_byte_array_bytes = max_byte_array_bytes

## Returns {ok: bool, value: Variant, errors: Array[Dictionary]}.
## No partial value is returned on failure.
func to_dict(obj: Object, config: SerializationConfig = null) -> Dictionary[String, Variant]:
	var resolved := config if config != null else SerializationConfig.new()
	var invalid := _validate_config(resolved)
	if not invalid.is_empty():
		return _failure(invalid)
	if obj == null:
		return _failure([_error("NULL_ROOT", "$", "Root object must not be null")])
	var state := _new_state()
	var serialized: Variant = _serialize_value(obj, "$", 0, resolved, state)
	return _finish(serialized, state.errors)

func to_wire_dict(obj: Object, config: SerializationConfig = null) -> Dictionary[String, Variant]:
	return to_dict(obj, config)

## Hydrates only declared script variables and returns a result dictionary.
## A failed result never exposes the temporary, potentially partially assigned object.
func from_dict(data: Dictionary, type: GDScript, config: SerializationConfig = null) -> Dictionary[String, Variant]:
	var resolved := config if config != null else SerializationConfig.new()
	var invalid := _validate_config(resolved)
	if not invalid.is_empty():
		return _failure(invalid)
	if type == null:
		return _failure([_error("INVALID_TYPE", "$", "A GDScript type is required")])
	var state := _new_state()
	var hydrated := _hydrate_object(data, type, "$", 0, resolved, state)
	return _finish(hydrated, state.errors)

func from_wire_dict(data: Dictionary, type: GDScript, config: SerializationConfig = null) -> Dictionary[String, Variant]:
	return from_dict(data, type, config)

## Utility only. Strict wire methods reject non-string dictionary keys instead of coercing them.
func normalize_keys(dict: Dictionary) -> Dictionary[String, Variant]:
	var normalized: Dictionary[String, Variant] = {}
	for key in dict.keys():
		normalized[str(key)] = dict[key]
	return normalized

func warm_cache(types: Array, config: SerializationConfig = null) -> void:
	var resolved := config if config != null else SerializationConfig.new()
	for entry in types:
		if entry is GDScript:
			var instance: Object = entry.new()
			if instance != null:
				_get_script_properties(instance, resolved)

func serialize_slot_keyed_dict(data: Dictionary, config: SerializationConfig = null) -> Dictionary[String, Variant]:
	var output: Dictionary[String, Variant] = {}
	var errors: Array[Dictionary] = []
	for slot in data:
		if not (slot is int):
			errors.append(_error("INVALID_SLOT_KEY", "$", "Slot keys must be integers"))
			continue
		var result := to_dict(data[slot], config)
		if result.ok:
			output[str(slot)] = result.value
		else:
			_append_prefixed_errors(errors, result.errors, "$[%s]" % slot)
	return _finish(output, errors)

func deserialize_slot_keyed_dict(data: Dictionary, type: GDScript, config: SerializationConfig = null) -> Dictionary[String, Variant]:
	var output: Dictionary = {}
	var errors: Array[Dictionary] = []
	for slot_text in data:
		if not (slot_text is String) or not String(slot_text).is_valid_int():
			errors.append(_error("INVALID_SLOT_KEY", "$", "Serialized slot keys must be integer strings"))
			continue
		if not (data[slot_text] is Dictionary):
			errors.append(_error("TYPE_MISMATCH", "$[%s]" % slot_text, "Slot value must be an object dictionary"))
			continue
		var result := from_dict(data[slot_text], type, config)
		if result.ok:
			output[int(slot_text)] = result.value
		else:
			_append_prefixed_errors(errors, result.errors, "$[%s]" % slot_text)
	return _finish(output, errors)

func _serialize_value(value: Variant, path: String, depth: int, config: SerializationConfig, state: Dictionary) -> Variant:
	if not _visit(path, depth, config, state):
		return null
	if value == null or value is bool or value is int:
		return value
	if value is float:
		if not is_finite(value):
			state.errors.append(_error("NON_FINITE_NUMBER", path, "JSON numbers must be finite"))
			return null
		return value
	if value is String:
		if value.to_utf8_buffer().size() > config.max_string_bytes:
			state.errors.append(_error("STRING_LIMIT", path, "UTF-8 string exceeds max_string_bytes"))
			return null
		return value
	if value is Vector2i:
		return {"x": value.x, "y": value.y}
	if value is PackedByteArray:
		if value.size() > config.max_byte_array_bytes or value.size() > config.max_collection_items:
			state.errors.append(_error("BYTE_ARRAY_LIMIT", path, "PackedByteArray exceeds configured bounds"))
			return null
		var bytes: Array = []
		for byte in value:
			bytes.append(byte)
		return bytes
	if value is Dictionary:
		if not _enter_container(value, path, config, state):
			return null
		var dictionary_result: Dictionary = {}
		for key in value:
			if not (key is String):
				state.errors.append(_error("INVALID_DICTIONARY_KEY", path, "JSON object keys must be strings"))
				continue
			dictionary_result[key] = _serialize_value(value[key], _field_path(path, key), depth + 1, config, state)
		_leave_container(state)
		return dictionary_result
	if value is Array:
		if not _enter_container(value, path, config, state):
			return null
		var array_result: Array = []
		for index in value.size():
			array_result.append(_serialize_value(value[index], "%s[%d]" % [path, index], depth + 1, config, state))
		_leave_container(state)
		return array_result
	if value is Object:
		var instance_id: int = value.get_instance_id()
		if state.object_ids.has(instance_id):
			state.errors.append(_error("CYCLE_DETECTED", path, "Object cycle detected"))
			return null
		state.object_ids[instance_id] = true
		var object_result: Dictionary[String, Variant] = {}
		for property in _get_script_properties(value, config):
			var name: String = property.get("name", "")
			object_result[name] = _serialize_value(value.get(name), _field_path(path, name), depth + 1, config, state)
		state.object_ids.erase(instance_id)
		return object_result
	state.errors.append(_error("UNSUPPORTED_TYPE", path, "Type %s is not JSON wire compatible" % type_string(typeof(value))))
	return null

func _hydrate_object(data: Dictionary, script: GDScript, path: String, depth: int, config: SerializationConfig, state: Dictionary) -> Object:
	if not _visit(path, depth, config, state):
		return null
	if not _enter_container(data, path, config, state):
		return null
	var obj: Object = script.new()
	if obj == null:
		state.errors.append(_error("CONSTRUCTION_FAILED", path, "Script did not construct an object"))
		_leave_container(state)
		return null
	var properties: Array[Dictionary] = _get_script_properties(obj, config)
	var property_map: Dictionary = {}
	for property in properties:
		property_map[property.get("name", "")] = property
	for key in data:
		if not (key is String):
			state.errors.append(_error("INVALID_DICTIONARY_KEY", path, "Input object keys must be strings"))
		elif not property_map.has(key):
			state.errors.append(_error("UNKNOWN_FIELD", _field_path(path, key), "Field is not a declared script variable"))
	if not state.errors.is_empty():
		_leave_container(state)
		return null
	for key in data:
		var field_path := _field_path(path, key)
		var converted: Variant = _hydrate_value(data[key], property_map[key], field_path, depth + 1, config, state)
		if not state.errors.is_empty():
			continue
		obj.set(key, converted)
		var observed: Variant = obj.get(key)
		if not _strict_equal(observed, converted):
			state.errors.append(_error("SETTER_REJECTED", field_path, "Setter result did not exactly match the validated value"))
	_leave_container(state)
	return obj

func _hydrate_value(value: Variant, property: Dictionary, path: String, depth: int, config: SerializationConfig, state: Dictionary) -> Variant:
	if not _visit(path, depth, config, state):
		return null
	var expected: int = int(property.get("type", TYPE_NIL))
	match expected:
		TYPE_NIL:
			return _validate_json_value(value, path, depth, config, state)
		TYPE_BOOL:
			if value is bool: return value
		TYPE_INT:
			if value is int: return value
			if value is float and is_finite(value) and value == floor(value) and abs(value) <= MAX_EXACT_FLOAT_INTEGER:
				return int(value)
		TYPE_FLOAT:
			if value is float and is_finite(value): return value
			if value is int and abs(value) <= MAX_EXACT_FLOAT_INTEGER: return float(value)
		TYPE_STRING:
			if value is String:
				if value.to_utf8_buffer().size() <= config.max_string_bytes: return value
				state.errors.append(_error("STRING_LIMIT", path, "UTF-8 string exceeds max_string_bytes"))
				return null
		TYPE_VECTOR2I:
			if value is Dictionary and value.size() == 2 and value.has("x") and value.has("y") and _is_exact_json_integer(value.x) and _is_exact_json_integer(value.y):
				return Vector2i(int(value.x), int(value.y))
		TYPE_PACKED_BYTE_ARRAY:
			if value is Array:
				if value.size() > config.max_byte_array_bytes or value.size() > config.max_collection_items:
					state.errors.append(_error("BYTE_ARRAY_LIMIT", path, "Byte array exceeds configured bounds"))
					return null
				var packed := PackedByteArray()
				for index in value.size():
					if not _is_exact_json_integer(value[index]) or value[index] < 0 or value[index] > 255:
						state.errors.append(_error("TYPE_MISMATCH", "%s[%d]" % [path, index], "Byte must be an integer from 0 through 255"))
						return null
					packed.append(int(value[index]))
				return packed
		TYPE_DICTIONARY:
			if value is Dictionary:
				return _validate_json_value(value, path, depth, config, state)
		TYPE_ARRAY:
			if value is Array:
				return _hydrate_array(value, property, path, depth, config, state)
		TYPE_OBJECT:
			if value == null: return null
			if value is Dictionary:
				var class_hint: String = property.get("class_name", "")
				var script_path := _resolve_script_path(class_hint, config)
				if not script_path.is_empty():
					var nested_script = load(script_path)
					if nested_script is GDScript:
						return _hydrate_object(value, nested_script, path, depth, config, state)
				state.errors.append(_error("UNRESOLVED_OBJECT_TYPE", path, "Object field requires a resolvable script class"))
				return null
	state.errors.append(_error("TYPE_MISMATCH", path, "Expected %s, received %s" % [type_string(expected), type_string(typeof(value))]))
	return null

func _hydrate_array(value: Array, property: Dictionary, path: String, depth: int, config: SerializationConfig, state: Dictionary) -> Array:
	if not _enter_container(value, path, config, state):
		return []
	var hint: String = property.get("hint_string", "")
	var element_type: int = _type_from_hint(hint)
	var element_script: Script = null
	if element_type == TYPE_OBJECT:
		var element_path := _resolve_script_path(hint, config)
		if element_path.is_empty():
			state.errors.append(_error("UNRESOLVED_OBJECT_TYPE", path, "Typed object array requires a resolvable script class"))
			_leave_container(state)
			return []
		element_script = load(element_path)
	var result: Array = []
	for index in value.size():
		var item_property := {"type": element_type, "class_name": hint if element_type == TYPE_OBJECT else ""}
		result.append(_hydrate_value(value[index], item_property, "%s[%d]" % [path, index], depth + 1, config, state))
	_leave_container(state)
	if element_type == TYPE_NIL:
		return result
	var base_class := StringName(element_script.get_instance_base_type()) if element_script != null else StringName()
	return Array(result, element_type, base_class, element_script)

func _validate_json_value(value: Variant, path: String, depth: int, config: SerializationConfig, state: Dictionary) -> Variant:
	if value == null or value is bool or value is int:
		return value
	if value is float:
		if is_finite(value): return value
		state.errors.append(_error("NON_FINITE_NUMBER", path, "JSON numbers must be finite"))
		return null
	if value is String:
		if value.to_utf8_buffer().size() <= config.max_string_bytes: return value
		state.errors.append(_error("STRING_LIMIT", path, "UTF-8 string exceeds max_string_bytes"))
		return null
	if value is Dictionary:
		if not _enter_container(value, path, config, state): return null
		var result: Dictionary = {}
		for key in value:
			if not (key is String):
				state.errors.append(_error("INVALID_DICTIONARY_KEY", path, "JSON object keys must be strings"))
				continue
			result[key] = _hydrate_untyped(value[key], _field_path(path, key), depth + 1, config, state)
		_leave_container(state)
		return result
	if value is Array:
		if not _enter_container(value, path, config, state): return null
		var result: Array = []
		for index in value.size():
			result.append(_hydrate_untyped(value[index], "%s[%d]" % [path, index], depth + 1, config, state))
		_leave_container(state)
		return result
	state.errors.append(_error("UNSUPPORTED_TYPE", path, "Value is not JSON compatible"))
	return null

func _hydrate_untyped(value: Variant, path: String, depth: int, config: SerializationConfig, state: Dictionary) -> Variant:
	if not _visit(path, depth, config, state): return null
	return _validate_json_value(value, path, depth, config, state)

func _visit(path: String, depth: int, config: SerializationConfig, state: Dictionary) -> bool:
	if depth > config.max_depth:
		state.errors.append(_error("DEPTH_LIMIT", path, "Value exceeds max_depth"))
		return false
	state.nodes += 1
	if state.nodes > config.max_nodes:
		state.errors.append(_error("NODE_LIMIT", path, "Payload exceeds max_nodes"))
		return false
	return true

func _enter_container(value: Variant, path: String, config: SerializationConfig, state: Dictionary) -> bool:
	if value.size() > config.max_collection_items:
		state.errors.append(_error("COLLECTION_LIMIT", path, "Collection exceeds max_collection_items"))
		return false
	for active in state.containers:
		if is_same(active, value):
			state.errors.append(_error("CYCLE_DETECTED", path, "Container cycle detected"))
			return false
	state.containers.append(value)
	return true

func _leave_container(state: Dictionary) -> void:
	state.containers.pop_back()

func _validate_config(config: SerializationConfig) -> Array[Dictionary]:
	var errors: Array[Dictionary] = []
	for entry in [["max_depth", config.max_depth], ["max_nodes", config.max_nodes], ["max_collection_items", config.max_collection_items], ["max_string_bytes", config.max_string_bytes], ["max_byte_array_bytes", config.max_byte_array_bytes]]:
		if entry[1] < 1:
			errors.append(_error("INVALID_LIMIT", "$.config.%s" % entry[0], "Limit must be at least 1"))
	return errors

func _new_state() -> Dictionary:
	return {"nodes": 0, "containers": [], "object_ids": {}, "errors": [] as Array[Dictionary]}

func _error(code: String, path: String, message: String) -> Dictionary:
	return {"code": code, "path": path, "message": message}

func _finish(value: Variant, errors: Array) -> Dictionary[String, Variant]:
	if errors.is_empty():
		return {"ok": true, "value": value, "errors": []}
	return _failure(errors)

func _failure(errors: Array) -> Dictionary[String, Variant]:
	return {"ok": false, "value": null, "errors": errors}

func _field_path(parent: String, field: String) -> String:
	return "%s.%s" % [parent, field]

func _append_prefixed_errors(target: Array[Dictionary], source: Array, prefix: String) -> void:
	for source_error in source:
		var copied: Dictionary = source_error.duplicate()
		copied.path = prefix + String(copied.get("path", "$")).trim_prefix("$")
		target.append(copied)

func _strict_equal(left: Variant, right: Variant) -> bool:
	if typeof(left) != typeof(right): return false
	if left is Object: return is_same(left, right)
	if left is Array:
		if left.size() != right.size(): return false
		for index in left.size():
			if not _strict_equal(left[index], right[index]): return false
		return true
	if left is Dictionary:
		if left.size() != right.size(): return false
		for key in left:
			if not right.has(key) or not _strict_equal(left[key], right[key]): return false
		return true
	return left == right

func _is_exact_json_integer(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value) and abs(value) <= MAX_EXACT_FLOAT_INTEGER)

func _type_from_hint(hint: String) -> int:
	match hint:
		"bool": return TYPE_BOOL
		"int": return TYPE_INT
		"float": return TYPE_FLOAT
		"String": return TYPE_STRING
		"Dictionary": return TYPE_DICTIONARY
		"Array": return TYPE_ARRAY
		"PackedByteArray": return TYPE_PACKED_BYTE_ARRAY
		"Vector2i": return TYPE_VECTOR2I
		"": return TYPE_NIL
		_: return TYPE_OBJECT

## Creates a deep copy of script-variable properties for non-wire handoff.
func deep_duplicate(obj: Object, type: GDScript, config: SerializationConfig = null) -> Object:
	var resolved := config if config != null else SerializationConfig.new()
	var new_obj: Object = type.new()
	for property in _get_script_properties(obj, resolved):
		var name: String = property.get("name", "")
		new_obj.set(name, _duplicate_value(obj.get(name)))
	return new_obj

func deep_duplicate_for_boundary(obj: Object, type: GDScript, config: SerializationConfig = null) -> Object:
	return deep_duplicate(obj, type, config)

func _duplicate_value(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	if value is Vector2i:
		return Vector2i(value.x, value.y)
	if value is Object and value.has_method("duplicate"):
		return value.duplicate()
	return value

func _get_script_properties(obj: Object, config: SerializationConfig) -> Array[Dictionary]:
	var script: Variant = obj.get_script()
	var properties: Array[Dictionary] = []
	if config.cache_enabled and script != null and _property_cache.has(script):
		properties = _property_cache[script]
	else:
		for property in obj.get_property_list():
			var name: String = property.get("name", "")
			var usage: int = int(property.get("usage", 0))
			if not name.is_empty() and not name.begins_with("_") and (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
				properties.append(property)
		if config.cache_enabled and script != null:
			_property_cache[script] = properties
	var filtered: Array[Dictionary] = []
	for property in properties:
		if not config.ignored_properties.has(property.get("name", "")):
			filtered.append(property)
	return filtered

func _resolve_script_path(class_name_hint: String, config: SerializationConfig) -> String:
	if config.class_resolver.is_valid():
		var resolved: Variant = config.class_resolver.call(class_name_hint)
		if resolved is String and not resolved.is_empty(): return resolved
	for entry in ProjectSettings.get_global_class_list():
		if entry is Dictionary and entry.get("class", "") == class_name_hint:
			return entry.get("path", "")
	return ""
