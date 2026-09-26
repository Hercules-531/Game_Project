extends GutTest

const Store = preload("res://scripts/settings/settings_store.gd")
var original: RefCounted
var store: RefCounted


func before_each() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	original = UserSettings.store
	store = Store.new("user://tests/settings_%d.json" % Time.get_ticks_usec())
	UserSettings.store = store
	store.apply()


func after_each() -> void:
	get_tree().paused = false
	UserSettings.store = original
	original.apply()
	UserSettings.changed.emit()
	if FileAccess.file_exists(store.path):
		DirAccess.remove_absolute(store.path)


func test_preferences_round_trip_swap_and_defaults() -> void:
	assert_true(store.rebind("move_forward",KEY_S))
	assert_eq(store.keys.move_back,KEY_W)
	assert_false(store.rebind("interact",KEY_ESCAPE))
	store.volumes.effects = 0.35
	store.sensitivity = 0.004
	assert_true(store.save_settings())
	var loaded := Store.new(store.path)
	assert_true(loaded.load_settings())
	assert_eq(loaded.keys,store.keys)
	assert_almost_eq(loaded.volumes.effects,0.35,0.0001)
	assert_eq(loaded.sensitivity,0.004)
	loaded.reset_defaults()
	assert_eq(loaded.keys,Store.DEFAULT_KEYS)
	assert_eq(loaded.sensitivity,0.0025)


func test_invalid_preferences_do_not_partially_apply() -> void:
	store.rebind("interact",KEY_F)
	store.save_settings()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(store.path))
	data.sensitivity = -1
	var file := FileAccess.open(store.path,FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	var loaded := Store.new(store.path)
	assert_false(loaded.load_settings())
	assert_eq(loaded.keys,Store.DEFAULT_KEYS)


func test_applies_physical_keys_and_audio_gain() -> void:
	store.rebind("interact",KEY_F)
	store.volumes.effects = 0.5
	store.volumes.ambience = 0.0
	store.apply()
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F
	assert_true(InputMap.event_is_action(event,"interact"))
	event.physical_keycode = KEY_E
	assert_false(InputMap.event_is_action(event,"interact"))
	var effects := AudioServer.get_bus_index("Effects")
	assert_gte(effects,0)
	assert_almost_eq(db_to_linear(AudioServer.get_bus_volume_db(effects)),0.5,0.001)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("Ambience")))


func test_settings_menu_preserves_pause_and_updates_camera() -> void:
	var session = load("res://scenes/ui/main_menu.tscn").instantiate()
	session.save_path = "user://tests/settings_menu_no_save.json"
	add_child_autofree(session)
	await wait_process_frames(3)
	session.menu.settings_requested.emit()
	var settings = session.get_node("Settings")
	assert_true(settings.panel.visible)
	assert_false(session.menu.panel.visible)
	settings.close()
	assert_true(session.menu.panel.visible)
	session.new_game()
	await wait_physics_frames(3)
	store.rebind("interact",KEY_F)
	store.apply()
	var station := OutpostInteractable.new()
	station.display_name = "Test panel"
	session.world.get_node("StationUI").show_target(station)
	assert_eq(session.world.get_node("StationUI").prompt.text,"[F] Test panel")
	station.free()
	InputContext.set_context(InputContext.Context.MENU)
	session.menu.settings_requested.emit()
	var ticks: int = session.world.physics_ticks
	settings.sliders.sensitivity.value = 0.004
	assert_eq(session.world.get_node("Operator/Head").sensitivity,0.004)
	settings._begin_rebind("interact")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	get_viewport().push_input(escape)
	assert_eq(settings.pending_action,"")
	assert_true(settings.panel.visible)
	get_viewport().push_input(escape)
	await wait_process_frames(3)
	assert_false(settings.panel.visible)
	assert_true(session.menu.panel.visible)
	assert_true(get_tree().paused)
	assert_eq(session.world.physics_ticks,ticks)
