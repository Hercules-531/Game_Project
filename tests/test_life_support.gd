extends GutTest

const Life = preload("res://scripts/simulation/life_support.gd")
const Schema = preload("res://scripts/persistence/save_schema.gd")
var session: Node


func before_each() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputContext.menu_locked = false


func after_each() -> void:
	get_tree().paused = false
	InputContext.menu_locked = false
	if is_instance_valid(session):
		for suffix in ["",".bak",".tmp"]:
			if FileAccess.file_exists(session.save_path + suffix):
				DirAccess.remove_absolute(session.save_path + suffix)
		DirAccess.remove_absolute(session.save_path.get_base_dir())
		session = null


func _isolated_life() -> Node:
	var life := Life.new()
	add_child_autofree(life)
	life.set_physics_process(false)
	return life


func _session() -> Node:
	session = load("res://scenes/ui/main_menu.tscn").instantiate()
	session.save_path = "user://tests/life_%d/save.json" % Time.get_ticks_usec()
	add_child_autofree(session)
	session.new_game()
	return session


func test_resource_conservation_and_switching_load() -> void:
	var life := _isolated_life()
	life.generator_on = false
	life.advance(60.0)
	assert_almost_eq(life.battery,2.0 - 2.9 / 60.0,0.000001)
	assert_eq(life.fuel,120.0)
	assert_almost_eq(life.rations,8.0 - 1.0 / 30.0,0.000001)
	assert_eq(life.oxygen,100.0)
	life.set_circuit("oxygen_on",false)
	life.set_circuit("heater_on",false)
	assert_almost_eq(life.load_kw(),0.3,0.000001)
	var charge: float = life.battery
	life.advance(60.0)
	assert_almost_eq(life.battery,charge - 0.3 / 60.0,0.000001)
	assert_almost_eq(life.oxygen,98.2,0.000001)
	assert_almost_eq(life.temperature,17.76,0.000001)
	life.set_circuit("generator_on",true)
	life.battery = 0.5
	charge = life.battery
	life.advance(60.0)
	assert_almost_eq(life.fuel,119.0,0.000001)
	assert_almost_eq(life.battery,charge + 3.7 / 60.0,0.000001)


func test_partial_fuel_and_battery_exhaustion_cannot_create_energy() -> void:
	var life := _isolated_life()
	life.battery = 0.0
	life.fuel = life.balance.fuel_per_second / 2.0
	life.oxygen = 80.0
	life.temperature = 10.0
	life.advance(1.0)
	assert_eq(life.fuel,0.0)
	assert_eq(life.battery,0.0)
	assert_almost_eq(life.supplied_fraction,2.0 / 2.9,0.000001)
	var oxygen: float = life.oxygen
	var temperature: float = life.temperature
	life.advance(1.0)
	assert_eq(life.supplied_fraction,0.0)
	assert_almost_eq(life.oxygen,oxygen - 0.03,0.000001)
	assert_almost_eq(life.temperature,temperature - 0.004,0.000001)
	assert_true(life.warning().contains("LOW BATTERY"))


func test_tick_partition_does_not_change_resource_drain() -> void:
	var whole := _isolated_life()
	var split := _isolated_life()
	whole.generator_on = false
	split.generator_on = false
	whole.advance(60.25)
	for index in 3600:
		split.advance(1.0 / 60.0)
	split.advance(0.25)
	assert_almost_eq(split.battery,whole.battery,0.000001)
	assert_almost_eq(split.rations,whole.rations,0.000001)
	assert_almost_eq(split.remainder,whole.remainder,0.000001)


func test_grace_recovery_and_each_exhaustion_cause() -> void:
	var life := _isolated_life()
	life.oxygen = 0.0
	life.oxygen_on = false
	life.advance(119.0)
	assert_false(life.dead)
	assert_true(life.warning().contains("RESTORE WITHIN 1s"))
	life.set_circuit("oxygen_on",true)
	life.advance(1.0)
	assert_false(life.dead)
	assert_eq(life.critical_seconds,0.0)
	for cause in ["oxygen","temperature","rations"]:
		var failed := _isolated_life()
		failed.oxygen_on = false
		failed.heater_on = false
		failed.set(cause,0.0)
		watch_signals(failed)
		failed.advance(120.0)
		assert_true(failed.dead,"%s must be lethal after the grace period" % cause)
		assert_signal_emit_count(failed,"died",1)
		var frozen: float = failed.rations
		failed.advance(10.0)
		assert_eq(failed.rations,frozen)


func test_physical_panel_pause_save_reload_and_death_preserve_last_save() -> void:
	_session()
	await wait_physics_frames(3)
	var life: Node = session.world.get_node("LifeSupport")
	life.set_physics_process(false)
	life.oxygen = 40.0
	life.advance(12.25)
	session.world.get_node("Bunker/LifeBreaker/Interaction").use()
	var panel: CanvasLayer = session.world.get_node("LifeSupportPanel")
	assert_true(panel.panel.visible)
	assert_true(panel.readings.text.contains("040.6%"))
	panel.buttons.oxygen_on.pressed.emit()
	assert_false(life.oxygen_on)
	assert_true(panel.buttons.oxygen_on.text.contains("OFF"))
	InputContext.set_context(InputContext.Context.MENU)
	life.set_physics_process(true)
	var before: Dictionary = life.snapshot()
	await wait_process_frames(6)
	assert_eq(life.snapshot(),before,"Menu pause must hold all life-support state")
	assert_true(session.save_current())
	var committed := FileAccess.get_file_as_string(session.save_path)
	life.set_physics_process(false)
	life.oxygen = 0.0
	life.advance(120.0)
	assert_true(get_tree().paused)
	assert_true(InputContext.menu_locked)
	assert_eq(session.menu.heading.text,"BUNKER QUIET")
	assert_false(session.menu.continue_button.disabled)
	assert_false(session.save_current())
	assert_eq(FileAccess.get_file_as_string(session.save_path),committed)
	InputContext.set_context(InputContext.Context.WALK)
	assert_eq(InputContext.active,InputContext.Context.MENU)
	session.open_settings()
	session.get_node("Settings").close()
	assert_eq(session.menu.heading.text,"BUNKER QUIET")
	assert_true(session.continue_game())
	InputContext.set_context(InputContext.Context.MENU)
	assert_false(InputContext.menu_locked)
	assert_false(session.world.get_node("LifeSupport").dead)
	var restored: Dictionary = session.world.get_node("LifeSupport").snapshot()
	for key in before:
		if before[key] is float:
			assert_almost_eq(restored[key],before[key],0.000001,"Saved %s" % key)
		else:
			assert_eq(restored[key],before[key])


func test_schema_migrates_old_save_and_rejects_invalid_life_state() -> void:
	_session()
	InputContext.set_context(InputContext.Context.MENU)
	var data: Dictionary = Schema.capture(session.world)
	data.life_support.oxygen = "invalid"
	assert_eq(Schema.validate(data),"Invalid life-support state.")
	data.version = 1
	data.erase("life_support")
	data = JSON.parse_string(JSON.stringify(data))
	assert_eq(Schema.validate(data),"")
	Schema.restore(session.world,data)
	assert_eq(session.world.get_node("LifeSupport").oxygen,100.0)
	assert_eq(Schema.capture(session.world).version,2)


func test_saved_grace_period_and_blackout_survive_reload() -> void:
	_session()
	var life: Node = session.world.get_node("LifeSupport")
	life.set_physics_process(false)
	life.fuel = 0.0
	life.battery = 0.0
	life.oxygen = 0.0
	life.advance(20.4)
	assert_eq(life.critical_seconds,20.0)
	assert_false(session.world.get_node("Bunker/CommandLight").visible)
	assert_false(session.world.get_node("Bunker/CommandCRT/ScreenStatus").visible)
	assert_true(session.save_current())
	assert_true(session.continue_game())
	InputContext.set_context(InputContext.Context.MENU)
	var restored: Node = session.world.get_node("LifeSupport")
	assert_eq(restored.critical_seconds,20.0)
	assert_almost_eq(restored.remainder,0.4,0.000001)
	assert_eq(restored.supplied_fraction,0.0)
	assert_false(session.world.get_node("Bunker/CommandLight").visible)
	assert_false(session.world.get_node("Bunker/CommandCRT/ScreenStatus").visible)


func test_death_without_save_offers_new_run_and_cannot_resume() -> void:
	_session()
	var life: Node = session.world.get_node("LifeSupport")
	life.set_physics_process(false)
	life.rations = 0.0
	life.advance(120.0)
	assert_true(session.menu.new_button.visible)
	assert_true(session.menu.continue_button.disabled)
	session.resume()
	assert_true(get_tree().paused)
	session.return_to_menu()
	assert_null(session.world)
	assert_false(FileAccess.file_exists(session.save_path))
	assert_false(InputContext.menu_locked)
