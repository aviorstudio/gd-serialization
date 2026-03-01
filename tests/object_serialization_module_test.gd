extends SceneTree

class SampleData extends RefCounted:
	var name: String = ""
	var count: int = 0
	var tags: Array[String] = []
	var position: Vector2i = Vector2i.ZERO

	func to_dict() -> Dictionary[String, Variant]:
		return {
			"name": name,
			"count": count,
			"tags": tags,
			"position": {"x": position.x, "y": position.y},
		}

	static func from_dict(data: Dictionary) -> SampleData:
		var result := SampleData.new()
		result.name = str(data.get("name", ""))
		result.count = int(data.get("count", 0))
		var source_tags: Array = data.get("tags", [])
		result.tags = source_tags.duplicate(true)
		var position_data: Dictionary = data.get("position", {})
		result.position = Vector2i(int(position_data.get("x", 0)), int(position_data.get("y", 0)))
		return result

class NestedData extends RefCounted:
	var value: String = ""

class MismatchData extends RefCounted:
	var name: String = ""
	var payload_obj: Object = RefCounted.new()

func _initialize() -> void:
	var serializer_script: GDScript = load("res://src/object_serialization_module.gd")
	if serializer_script == null:
		push_error("Failed to load res://src/object_serialization_module.gd")
		quit(1)
		return

	var serializer: Object = serializer_script.new()
	var sample := SampleData.new()
	sample.name = "alpha"
	sample.count = 42
	sample.tags = ["x", "y"]
	sample.position = Vector2i(2, 7)

	var config: Variant = serializer_script.SerializationConfig.new()
	config.class_resolver = Callable()
	config.ignored_properties.clear()
	for property_name in ["RefCounted", "script", "Script Variables", "count"]:
		config.ignored_properties.append(property_name)

	var serialized_ignored: Dictionary[String, Variant] = serializer.to_dict(sample, config)
	var payload: Dictionary[String, Variant] = serialized_ignored.duplicate(true)
	payload["count"] = 42
	var hydrated: SampleData = serializer.from_dict(payload, SampleData)
	var cloned: SampleData = serializer.deep_duplicate(sample, SampleData)
	var normalized: Dictionary[String, Variant] = serializer.normalize_keys({1: "one", "two": 2})
	var mismatch_payload: Dictionary[String, Variant] = {
		"name": "beta",
		"payload_obj": {"nested": true}
	}
	var mismatch_default: MismatchData = serializer.from_dict(mismatch_payload, MismatchData)
	var skip_mismatch_config: Variant = serializer_script.SerializationConfig.new()
	skip_mismatch_config.skip_type_mismatch = true
	var mismatch_skipped: MismatchData = serializer.from_dict(mismatch_payload, MismatchData, skip_mismatch_config)

	var failures: Array[String] = []
	if serialized_ignored.has("count"):
		failures.append("to_dict should honor ignored_properties config")
	if hydrated.name != "alpha" or hydrated.count != 42:
		failures.append("from_dict failed primitive fields")
	if hydrated.position != Vector2i(2, 7):
		failures.append("from_dict failed Vector2i")
	if normalized.get("1", "") != "one" or int(normalized.get("two", 0)) != 2:
		failures.append("normalize_keys failed to convert dictionary keys to strings")
	if cloned.tags.size() != 2 or cloned.tags[0] != "x":
		failures.append("deep_duplicate failed array values")
	if cloned == sample:
		failures.append("deep_duplicate returned original instance")
	if mismatch_default.payload_obj != null:
		failures.append("from_dict should set object property to null on mismatched dictionary by default")
	if mismatch_skipped.payload_obj == null:
		failures.append("skip_type_mismatch should preserve existing object property when value is mismatched")

	if failures.is_empty():
		print("PASS gd-serialization object_serialization_module_test")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
