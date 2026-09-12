extends GutTest


func test_main_scene_advances_both_loops() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(main)
	await wait_physics_frames(3)
	await wait_process_frames(3)
	assert_gt(main.process_frames, 0, "Main scene processes rendered frames")
	assert_gt(main.physics_ticks, 0, "Main scene advances physics")
	assert_gt(main.elapsed_seconds, 0.0, "Elapsed time advances")
	assert_true(main.diagnostics.text.contains("Physics ticks:"), "Diagnostics reach the UI")
