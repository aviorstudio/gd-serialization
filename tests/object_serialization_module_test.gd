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

func _initialize() -> void:
	var serializer_script := load("res://src/object_serialization_module.gd")
	if serializer_script == null:
		push_error("Failed to load res://src/object_serialization_module.gd")
		quit(1)
		return

	var serializer = serializer_script.new()
	var sample := SampleData.new()
	sample.name = "alpha"
	sample.count = 42
	sample.tags = ["x", "y"]
	sample.position = Vector2i(2, 7)

	var serialized: Dictionary = serializer.to_dict(sample)
	var hydrated: SampleData = serializer.from_dict(serialized, SampleData)
	var cloned: SampleData = serializer.deep_duplicate(sample, SampleData)

	var failures: Array[String] = []
	if hydrated.name != "alpha" or hydrated.count != 42:
		failures.append("from_dict failed primitive fields")
	if hydrated.position != Vector2i(2, 7):
		failures.append("from_dict failed Vector2i")
	if cloned.tags.size() != 2 or cloned.tags[0] != "x":
		failures.append("deep_duplicate failed array values")
	if cloned == sample:
		failures.append("deep_duplicate returned original instance")

	if failures.is_empty():
		print("PASS gd-serialization object_serialization_module_test")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
