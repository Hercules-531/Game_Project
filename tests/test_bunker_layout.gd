extends GutTest

var main: Node
var operator: CharacterBody3D
var previous_time_scale: float


func before_each() -> void:
	previous_time_scale = Engine.time_scale
	Engine.time_scale = 2.0
	main = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(main)
	operator = main.get_node("Operator")
	await wait_physics_frames(5)


func after_each() -> void:
	_clear_input()
	Engine.time_scale = previous_time_scale


func _clear_input() -> void:
	for action in ["move_left", "move_right", "move_forward", "move_back"]:
		Input.action_release(action)


func _walk_to(target: Vector2) -> bool:
	for step in range(500):
		var offset := target - Vector2(operator.position.x, operator.position.z)
		if offset.length() < 0.18:
			_clear_input()
			await wait_physics_frames(8)
			return true
		var direction := offset.normalized()
		Input.action_press("move_right", maxf(direction.x, 0.0))
		Input.action_press("move_left", maxf(-direction.x, 0.0))
		Input.action_press("move_back", maxf(direction.y, 0.0))
		Input.action_press("move_forward", maxf(-direction.y, 0.0))
		await wait_physics_frames(1)
	_clear_input()
	return false


func test_all_rooms_are_connected_by_walkable_openings() -> void:
	for target in [Vector2(0, 1), Vector2(4.3, 1), Vector2(0, 1),
		Vector2(-4.3, 1), Vector2(0, 1), Vector2(0, 8), Vector2(0, -4.5)]:
		assert_true(await _walk_to(target), "Walk to %s through actual doorways" % target)
		assert_true(operator.is_on_floor())
	var airlock = main.get_node("Bunker/Airlock")
	assert_true(airlock.request_open(&"inner"))
	await wait_seconds(1.1)
	assert_true(await _walk_to(Vector2(0, -8)), "Enter airlock through open inner door")
	assert_false(airlock.request_open(&"outer"), "Unsuited operator cannot exit")


func test_opening_door_does_not_carry_player_into_jamb() -> void:
	operator.position = Vector3(0, 0.01, -5.0)
	Input.action_press("move_forward")
	await wait_physics_frames(25)
	_clear_input()
	var airlock = main.get_node("Bunker/Airlock")
	assert_true(airlock.request_open(&"inner"))
	await wait_seconds(1.1)
	assert_almost_eq(operator.position.x, 0.0, 0.1, "Door must not carry operator sideways")
	assert_true(await _walk_to(Vector2(0, -8)), "Walk through after opening from contact")
