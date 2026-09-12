extends SceneTree

func _initialize() -> void:
	var mode := OS.get_environment("RUNNER_FIXTURE_MODE")
	match mode:
		"success":
			print("TEST_ASSERTIONS_REACHED:1")
			print("TEST_FAILURES:0")
			quit(0)
		"push_error_zero":
			push_error("deliberate runner control")
			print("TEST_ASSERTIONS_REACHED:1")
			print("TEST_FAILURES:0")
			quit(0)
		"assert_overwritten":
			print("TEST_ASSERTIONS_REACHED:1")
			print("TEST_FAILURES:1")
			quit(1)
			quit(0)
		"timeout":
			while true:
				await process_frame
		_:
			push_error("unknown fixture mode")
			quit(0)
