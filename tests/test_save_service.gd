extends GutTest

const Service = preload("res://scripts/persistence/save_service.gd")
const Schema = preload("res://scripts/persistence/save_schema.gd")
var session: Node
var save_path: String


func before_each() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	save_path = "user://tests/save_%d/save.json" % Time.get_ticks_usec()
	session = load("res://scenes/ui/main_menu.tscn").instantiate()
	session.save_path = save_path
	add_child_autofree(session)
	session.new_game()
	await wait_physics_frames(3)


func after_each() -> void:
	get_tree().paused = false
	await wait_process_frames(2)
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(save_path + suffix)
	DirAccess.remove_absolute(save_path.get_base_dir())


func test_save_and_continue_restore_world_and_visual_control_state() -> void:
	var world: Node = session.world
	var operator: Node3D = world.get_node("Operator")
	operator.position = Vector3(4.3,0.001,1.4)
	operator.rotation.y = 0.72
	operator.get_node("Head").rotation.x = -0.21
	world.elapsed_seconds = 123.0
	world.get_node("Bunker/CommandSwitch/Interaction").toggle_power()
	world.get_node("Bunker/CommandCRT/Interaction").toggle_power()
	InputContext.set_context(InputContext.Context.MENU)
	assert_true(session.save_current())
	var saved: Dictionary = session.saves.read_save().data
	session.return_to_menu()
	assert_true(session.menu.continue_button.visible)
	assert_false(session.menu.continue_button.disabled)
	assert_true(session.continue_game())
	InputContext.set_context(InputContext.Context.MENU)
	var restored: Dictionary = Schema.capture(session.world)
	for i in 3:
		assert_almost_eq(restored.operator.position[i],saved.operator.position[i],0.00001)
	assert_almost_eq(restored.operator.yaw,saved.operator.yaw,0.00001)
	assert_almost_eq(restored.operator.pitch,saved.operator.pitch,0.00001)
	assert_eq(restored.controls,saved.controls)
	assert_eq(restored.elapsed,saved.elapsed)
	assert_false(session.world.get_node("Bunker/CommandLight").visible)
	assert_false(session.world.get_node("Bunker/CommandCRT/ScreenStatus").visible)


func test_missing_corrupt_and_interrupted_write_preserve_last_good_state() -> void:
	var service = Service.new(save_path)
	assert_false(service.read_save().ok)
	var snapshot: Dictionary = Schema.capture(session.world)
	assert_true(service.write_save(snapshot).ok)
	snapshot.elapsed = 99.0
	assert_true(service.write_save(snapshot).ok)
	# Failed staging write never replaces the committed main file.
	_write_text(save_path + ".tmp","{unfinished")
	assert_eq(service.read_save().data.elapsed,99.0)
	# Simulate interruption after rotating main to backup, before committing temp.
	DirAccess.remove_absolute(save_path + ".bak")
	DirAccess.rename_absolute(save_path,save_path + ".bak")
	var recovered: Dictionary = service.read_save()
	assert_true(recovered.ok)
	assert_true(recovered.recovered)
	assert_eq(recovered.data.elapsed,99.0)
	_write_text(save_path,"corruption")
	assert_true(service.read_save().recovered)
	DirAccess.remove_absolute(save_path + ".bak")
	assert_false(service.read_save().ok)


func test_unsupported_version_is_not_overwritten_or_silently_recovered() -> void:
	var service = Service.new(save_path)
	var snapshot: Dictionary = Schema.capture(session.world)
	assert_true(service.write_save(snapshot).ok)
	assert_true(service.write_save(snapshot).ok)
	var future := snapshot.duplicate(true)
	future.version = 999
	var payload := JSON.stringify(future)
	var text := JSON.stringify({"format":"outpost-save","payload":payload,"sha256":payload.sha256_text()})
	_write_text(save_path,text)
	assert_eq(service.read_save().kind,"unsupported")
	assert_false(service.write_save(snapshot).ok)
	assert_eq(FileAccess.get_file_as_string(save_path),text)


func test_mid_cycle_save_is_rejected_without_discarding_world() -> void:
	var world: Node = session.world
	assert_true(world.get_node("Bunker/Airlock").request_open(&"inner"))
	assert_false(session.save_current())
	session.return_to_menu()
	assert_eq(session.world,world)
	await wait_seconds(1.1)
	assert_true(session.save_current())
	session.continue_game()
	assert_eq(session.world.get_node("Bunker/Airlock").opened_side,&"inner")
	assert_almost_eq(session.world.get_node("Bunker/Airlock/InnerDoor").position.x,1.8,0.001)


func test_checksum_and_invalid_state_are_rejected() -> void:
	var service = Service.new(save_path)
	var snapshot: Dictionary = Schema.capture(session.world)
	assert_true(service.write_save(snapshot).ok)
	var committed := FileAccess.get_file_as_string(save_path)
	var invalid := snapshot.duplicate(true)
	invalid.operator.position = [0,0,"invalid"]
	assert_false(service.write_save(invalid).ok)
	assert_eq(FileAccess.get_file_as_string(save_path),committed)
	var envelope: Dictionary = JSON.parse_string(committed)
	envelope.sha256 = "not-the-payload-checksum"
	_write_text(save_path,JSON.stringify(envelope))
	assert_false(service.read_save().ok)
	assert_eq(service.read_save().kind,"corrupt")


func _write_text(path: String, contents: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(contents)
	file.close()
