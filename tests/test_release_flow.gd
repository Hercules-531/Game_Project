extends GutTest
var original_store: RefCounted
func before_each() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	original_store = UserSettings.store
	UserSettings.store = preload("res://scripts/settings/settings_store.gd").new("user://tests/release_probe/gut-settings.json")
func after_each() -> void:
	Engine.time_scale = 1
	get_tree().paused = false
	InputContext.menu_locked = false
	UserSettings.store = original_store
	UserSettings.store.apply()
	InputContext.set_context(InputContext.Context.WALK)
	await wait_process_frames(2)
func test_shipped_acceptance_flow_in_isolated_profile() -> void:
	var probe = load("res://scenes/diagnostics/release_flow.tscn").instantiate()
	add_child_autofree(probe)
	var result: Dictionary = await probe.run(false)
	assert_true(result.ok,str(result.failures))
	assert_gte(result.checks.size(),25)
