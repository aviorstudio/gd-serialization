## Generic object serialization helpers for typed Godot data models.
class_name ObjectSerializationModule
extends RefCounted

var _property_cache: Dictionary = {}

## Configuration for class resolution and ignored properties.
class SerializationConfig extends RefCounted:
	## Optional callable used to resolve a class name to a script path.
	var class_resolver: Callable
	## Property names to skip during serialization and duplication.
	var ignored_properties: Array[String]
	## Enables script property-list caching for faster repeated serialization.
	var cache_enabled: bool

	func _init(
		class_resolver: Callable = Callable(),
		ignored_properties: Array[String] = DEFAULT_IGNORED_PROPERTY_NAMES,
		cache_enabled: bool = true
	) -> void:
		self.class_resolver = class_resolver
		self.ignored_properties = []
		for property_name in ignored_properties:
			self.ignored_properties.append(str(property_name))
		self.cache_enabled = cache_enabled

const DEFAULT_IGNORED_PROPERTY_NAMES: Array[String] = [
	"RefCounted",
	"script",
	"Script Variables"
]

## Serializes an object's script variables into a dictionary.
func to_dict(obj: Object, config: SerializationConfig = null) -> Dictionary[String, Variant]:
	var resolved_config: SerializationConfig = config if config else SerializationConfig.new()
	var result: Dictionary[String, Variant] = {}
	var script_properties: Array[Dictionary] = _get_script_properties(obj, resolved_config)

	for property in script_properties:
		var property_name: String = property.get("name", "")
		if property_name == "":
			continue
		var value = obj.get(property_name)
		result[property_name] = _serialize_value(value, resolved_config)

	return result

## Creates a new object instance from serialized dictionary data.
##
## Callers should cast the return value to their expected type.
func from_dict(dict: Dictionary, type: GDScript, config: SerializationConfig = null) -> Object:
	var resolved_config: SerializationConfig = config if config else SerializationConfig.new()
	var obj: Object = type.new()
	var normalized_dict: Dictionary[String, Variant] = normalize_keys(dict)

	for key in normalized_dict.keys():
		if _has_property(obj, key):
			var value: Variant = normalized_dict[key]
			var property_info: Dictionary = _get_property_info(obj, key)
			if property_info:
				var deserialized_value: Variant = _deserialize_value(value, property_info, resolved_config)
				obj.set(key, deserialized_value)

	return obj

## Returns a copy of a dictionary with all keys coerced to strings.
func normalize_keys(dict: Dictionary) -> Dictionary[String, Variant]:
	var normalized: Dictionary[String, Variant] = {}
	for key in dict.keys():
		normalized[str(key)] = dict[key]
	return normalized

func _serialize_value(value, config: SerializationConfig) -> Variant:
	if value is int or value is float or value is String or value is bool:
		return value

	if value is Vector2i:
		return {"x": value.x, "y": value.y}

	if value is Dictionary:
		var result: Dictionary = {}
		for key in value.keys():
			result[key] = _serialize_value(value[key], config)
		return result

	if value is Array:
		return value.map(func(item) -> Variant: return _serialize_value(item, config))

	if value is Object:
		var has_to_dict: bool = value.has_method("to_dict")
		return value.to_dict() if has_to_dict else to_dict(value, config)

	return null

func _deserialize_value(value, property_info: Dictionary, config: SerializationConfig) -> Variant:
	var property_type: int = property_info.type

	if property_type == TYPE_INT:
		if value is int:
			return value
		return 0

	if property_type == TYPE_FLOAT:
		if value is float or value is int:
			return float(value)
		return 0.0

	if property_type == TYPE_STRING:
		if value is String:
			return value
		return ""

	if property_type == TYPE_BOOL:
		if value is bool:
			return value
		return false

	if property_type == TYPE_VECTOR2I:
		if value is Vector2i:
			return value
		if value is Dictionary:
			var x: int = value.get("x", 0)
			var y: int = value.get("y", 0)
			return Vector2i(x, y)
		return Vector2i.ZERO

	if property_type == TYPE_DICTIONARY:
		if value is Dictionary:
			var result: Dictionary = {}
			for key in value.keys():
				result[key] = value[key]
			return result
		return {}

	if property_type == TYPE_ARRAY:
		if value is Array:
			var hint_string: String = property_info.get("hint_string", "")
			var result: Array = []

			if not hint_string.is_empty():
				var class_hint = hint_string
				if ":" in hint_string:
					var parts = hint_string.split(":")
					if parts.size() >= 2:
						class_hint = parts[1]

				var script_path := _resolve_script_path(class_hint, config)
				if not script_path.is_empty():
					var script = load(script_path)
					if script:
						for item in value:
							if item is Dictionary:
								result.append(from_dict(normalize_keys(item), script, config))
							else:
								result.append(item)
						return result

			for item in value:
				result.append(item)
			return result
		return []

	if property_type == TYPE_OBJECT:
		if value is Object:
			return value
		if value is Dictionary:
			var class_hint: String = property_info.get("class_name", "")
			if class_hint.is_empty():
				return null

			var script_path := _resolve_script_path(class_hint, config)
			if script_path.is_empty():
				return null

			var script = load(script_path)
			if script:
				var script_instance = script.new()
				var has_from_dict: bool = script_instance.has_method("from_dict")
				var normalized_value: Dictionary[String, Variant] = normalize_keys(value)
				return script.from_dict(normalized_value) if has_from_dict else from_dict(normalized_value, script, config)
		return null

	return null

func _get_property_info(obj: Object, property_name: String) -> Dictionary:
	var properties: Array[Dictionary] = obj.get_property_list()
	for prop in properties:
		if prop.get("name", "") == property_name:
			return prop
	return {}

## Serializes a slot-indexed dictionary of objects by calling `to_dict` on each value.
func serialize_slot_keyed_dict(data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for slot in data:
		var obj = data[slot]
		if obj:
			result[str(slot)] = obj.to_dict()
	return result

## Deserializes a slot-indexed dictionary into typed objects.
func deserialize_slot_keyed_dict(serialized: Dictionary, type_hint: GDScript) -> Dictionary:
	var result: Dictionary = {}
	for slot_str in serialized:
		var slot: int = int(slot_str)
		var obj_data = serialized[slot_str]
		if obj_data is Dictionary:
			result[slot] = type_hint.from_dict(normalize_keys(obj_data))
		elif obj_data is Object:
			result[slot] = obj_data
	return result

## Creates a deep copy of an object by duplicating its script-variable properties.
func deep_duplicate(obj: Object, type: GDScript, config: SerializationConfig = null) -> Object:
	var resolved_config: SerializationConfig = config if config else SerializationConfig.new()
	var new_obj: Object = type.new()
	var script_properties: Array[Dictionary] = _get_script_properties(obj, resolved_config)

	for property in script_properties:
		var property_name: String = property.get("name", "")
		if property_name == "":
			continue
		var value = obj.get(property_name)
		var type_id: int = int(property.get("type", TYPE_NIL))
		var duplicated_value = _duplicate_value(value, type_id)
		new_obj.set(property_name, duplicated_value)

	return new_obj

func _duplicate_value(value, property_type: int) -> Variant:
	if value is int or value is float or value is String or value is bool:
		return value

	if value is Vector2i:
		return Vector2i(value.x, value.y)

	if value is Dictionary:
		return value.duplicate(true)

	if value is Array:
		return value.duplicate(true)

	if value is Object:
		var method_list: Array = value.get_method_list()
		var has_duplicate := false
		for method in method_list:
			if method.name == "duplicate":
				has_duplicate = true
				break

		if has_duplicate:
			return value.duplicate()
		else:
			return value

	return null

func _get_script_properties(obj: Object, config: SerializationConfig) -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	if obj == null:
		return properties

	var script: Variant = obj.get_script()
	var property_list: Array[Dictionary] = []
	if config.cache_enabled and script != null and _property_cache.has(script):
		property_list = _property_cache[script]
	else:
		var raw_property_list: Array[Dictionary] = obj.get_property_list()
		for prop in raw_property_list:
			var name: String = prop.get("name", "")
			var usage: int = int(prop.get("usage", 0))
			if name == "" or name.begins_with("_"):
				continue
			if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
				continue
			property_list.append(prop)
		if config.cache_enabled and script != null:
			_property_cache[script] = property_list

	for prop in property_list:
		var name: String = prop.get("name", "")
		if config.ignored_properties.has(name):
			continue
		properties.append(prop)
	return properties

func _has_property(obj: Object, property_name: String) -> bool:
	var property_list: Array[Dictionary] = obj.get_property_list()
	for prop in property_list:
		if prop.get("name", "") == property_name:
			return true
	return false

func _resolve_script_path(p_class_name: String, config: SerializationConfig) -> String:
	if config.class_resolver.is_valid():
		var resolved_path: Variant = config.class_resolver.call(p_class_name)
		if resolved_path is String:
			return resolved_path
	return ""
