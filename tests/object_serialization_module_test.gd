extends SceneTree

const NestedFixture = preload("res://tests/fixtures/nested_data.gd")

class SampleData extends RefCounted:
	var name: String = ""
	var count: int = 0
	var ratio: float = 0.0
	var enabled: bool = false
	var tags: Array[String] = []
	var position: Vector2i = Vector2i.ZERO
	var bytes: PackedByteArray = PackedByteArray()
	var metadata: Dictionary = {}

class SetterData extends RefCounted:
	static var setter_calls := 0
	var guarded: int = 0:
		set(value):
			setter_calls += 1
			guarded = clampi(value, 0, 10)

class CycleData extends RefCounted:
	var next: Object

class UnsupportedData extends RefCounted:
	var callback: Callable = func() -> void: pass

class ParentData extends RefCounted:
	var nested: NestedFixture
	var children: Array[NestedFixture] = []

var assertions := 0
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)

func has_error(result: Dictionary, code: String, path: String = "") -> bool:
	for error in result.get("errors", []):
		if error.get("code", "") == code and (path.is_empty() or error.get("path", "") == path):
			return true
	return false

func _initialize() -> void:
	var serializer_script: GDScript = load("res://addon/src/object_serialization_module.gd")
	if serializer_script == null:
		push_error("Failed to load serializer")
		quit(1)
		return
	var serializer: Object = serializer_script.new()
	var sample := SampleData.new()
	sample.name = "alpha"
	sample.count = 42
	sample.ratio = 2.5
	sample.enabled = true
	sample.tags = ["x", "y"]
	sample.position = Vector2i(2, 7)
	sample.bytes = PackedByteArray([0, 127, 255])
	sample.metadata = {"nested": {"items": [1, true, null, "ok"]}}

	var encoded: Dictionary = serializer.to_wire_dict(sample)
	check(encoded.ok, "valid object should serialize")
	check(encoded.value.position == {"x": 2, "y": 7}, "Vector2i must use exact x/y object")
	check(encoded.value.bytes == [0, 127, 255], "PackedByteArray must use JSON byte array")
	check(not JSON.stringify(encoded.value).is_empty(), "successful output must be JSON encodable")

	var decoded: Dictionary = serializer.from_wire_dict(encoded.value, SampleData)
	check(decoded.ok, "valid payload should hydrate")
	if decoded.ok:
		var restored: SampleData = decoded.value
		check(restored.name == sample.name and restored.count == sample.count, "primitive round trip failed")
		check(restored.ratio == 2.5 and restored.enabled, "float/bool round trip failed")
		check(restored.tags is Array[String] and restored.tags == sample.tags, "typed string array round trip failed")
		check(restored.position == sample.position and restored.bytes == sample.bytes, "Godot value round trip failed")
		check(restored.metadata == sample.metadata, "nested JSON round trip failed")

	var json_roundtrip: Variant = JSON.parse_string(JSON.stringify(encoded.value))
	var decoded_json: Dictionary = serializer.from_dict(json_roundtrip, SampleData)
	check(decoded_json.ok, "JSON stringify/parse round trip should hydrate")
	var nested_config: Variant = serializer_script.SerializationConfig.new()
	nested_config.class_resolver = func(_class_name: String) -> String: return "res://tests/fixtures/nested_data.gd"
	var child := NestedFixture.new()
	child.value = "nested"
	var parent := ParentData.new()
	parent.nested = child
	parent.children = [child]
	var nested_encoded: Dictionary = serializer.to_dict(parent, nested_config)
	var nested_decoded: Dictionary = serializer.from_dict(nested_encoded.value, ParentData, nested_config)
	check(nested_encoded.ok and nested_decoded.ok, "nested object and typed object array should round trip")
	if nested_decoded.ok:
		check(nested_decoded.value.nested.value == "nested", "nested typed object value failed")
		check(nested_decoded.value.children is Array[NestedFixture] and nested_decoded.value.children[0].value == "nested", "typed object array value failed")

	var unknown: Dictionary = serializer.from_dict({"name": "safe", "script": null}, SampleData)
	check(not unknown.ok and unknown.value == null and has_error(unknown, "UNKNOWN_FIELD", "$.script"), "engine property must not be in inbound allowlist")
	var unknown_custom: Dictionary = serializer.from_dict({"not_declared": 1}, SampleData)
	check(has_error(unknown_custom, "UNKNOWN_FIELD", "$.not_declared"), "unknown key must return structured path error")

	var mismatch: Dictionary = serializer.from_dict({"count": "42"}, SampleData)
	check(not mismatch.ok and has_error(mismatch, "TYPE_MISMATCH", "$.count"), "string-to-int mismatch must not default or coerce")
	var float_from_int: Dictionary = serializer.from_dict({"ratio": 2}, SampleData)
	check(float_from_int.ok and float_from_int.value.ratio == 2.0, "exact integer-to-float conversion should be allowed")
	var int_from_float: Dictionary = serializer.from_dict({"count": 2.5}, SampleData)
	check(has_error(int_from_float, "TYPE_MISMATCH", "$.count"), "non-integral float-to-int conversion must be rejected")
	var exact_json_int: Dictionary = serializer.from_dict({"count": 2.0}, SampleData)
	check(exact_json_int.ok and exact_json_int.value.count == 2, "exact JSON float-to-int conversion should be allowed")

	SetterData.setter_calls = 0
	var setter_rejected: Dictionary = serializer.from_dict({"guarded": 99}, SetterData)
	check(not setter_rejected.ok and setter_rejected.value == null and has_error(setter_rejected, "SETTER_REJECTED", "$.guarded"), "setter clamp must return structured failure and no object")
	check(SetterData.setter_calls == 1, "setter side effect should occur exactly once on temporary object")
	var setter_ok: Dictionary = serializer.from_dict({"guarded": 5}, SetterData)
	check(setter_ok.ok and setter_ok.value.guarded == 5, "setter exact readback should succeed")

	var bad_byte: Dictionary = serializer.from_dict({"bytes": [256]}, SampleData)
	check(has_error(bad_byte, "TYPE_MISMATCH", "$.bytes[0]"), "out-of-range byte must fail")
	var bad_vector: Dictionary = serializer.from_dict({"position": {"x": 1, "y": 2, "z": 3}}, SampleData)
	check(has_error(bad_vector, "TYPE_MISMATCH", "$.position"), "Vector2i must reject extra or malformed fields")

	var non_string_key := SampleData.new()
	non_string_key.metadata = {1: "one"}
	check(has_error(serializer.to_dict(non_string_key), "INVALID_DICTIONARY_KEY", "$.metadata"), "non-string dictionary key must fail")
	var unsupported: Dictionary = serializer.to_dict(UnsupportedData.new())
	check(has_error(unsupported, "UNSUPPORTED_TYPE", "$.callback"), "unsupported output type must not become null")

	var object_cycle := CycleData.new()
	object_cycle.next = object_cycle
	check(has_error(serializer.to_dict(object_cycle), "CYCLE_DETECTED", "$.next"), "object cycle must fail")
	var container_cycle: Array = []
	container_cycle.append(container_cycle)
	var cycle_sample := SampleData.new()
	cycle_sample.metadata = {"cycle": container_cycle}
	check(has_error(serializer.to_dict(cycle_sample), "CYCLE_DETECTED"), "container cycle must fail")
	object_cycle.next = null
	container_cycle.clear()
	cycle_sample.metadata.clear()

	var small: Variant = serializer_script.SerializationConfig.new()
	small.max_depth = 2
	small.max_nodes = 5
	small.max_collection_items = 2
	small.max_string_bytes = 3
	small.max_byte_array_bytes = 2
	check(has_error(serializer.from_dict({"metadata": {"a": {"b": {"c": 1}}}}, SampleData, small), "DEPTH_LIMIT"), "depth bound must fail closed")
	var collection_result: Dictionary = serializer.from_dict({"tags": ["a", "b", "c"]}, SampleData, small)
	check(has_error(collection_result, "COLLECTION_LIMIT", "$.tags"), "collection bound must fail closed")
	check(has_error(serializer.from_dict({"name": "four"}, SampleData, small), "STRING_LIMIT", "$.name"), "UTF-8 string byte bound must fail closed")
	check(has_error(serializer.from_dict({"bytes": [1, 2, 3]}, SampleData, small), "BYTE_ARRAY_LIMIT", "$.bytes"), "byte bound must fail closed")
	var node_limited: Variant = serializer_script.SerializationConfig.new()
	node_limited.max_nodes = 2
	check(has_error(serializer.from_dict({"name": "a", "count": 1}, SampleData, node_limited), "NODE_LIMIT"), "total node bound must fail closed")

	var nan_sample := SampleData.new()
	nan_sample.ratio = NAN
	check(has_error(serializer.to_dict(nan_sample), "NON_FINITE_NUMBER", "$.ratio"), "non-finite output must fail")
	check(has_error(serializer.from_dict({"ratio": INF}, SampleData), "TYPE_MISMATCH", "$.ratio"), "non-finite input must fail")

	serializer.warm_cache([SampleData])
	check(serializer._property_cache.has(SampleData), "warm_cache should populate script properties")
	var cloned: SampleData = serializer.deep_duplicate(sample, SampleData)
	check(cloned != sample and cloned.tags == sample.tags, "non-wire deep duplicate should remain available")

	print("TEST_ASSERTIONS_REACHED:%d" % assertions)
	print("TEST_FAILURES:%d" % failures.size())
	if failures.is_empty():
		print("PASS gd-serialization strict object_serialization_module_test")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
