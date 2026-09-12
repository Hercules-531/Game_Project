extends GutTest

var lab: Node3D
var operator: CharacterBody3D
var original_physics_rate: int


func before_each() -> void:
	original_physics_rate = Engine.physics_ticks_per_second
	lab = load("res://scenes/diagnostics/movement.tscn").instantiate()
	add_child_autofree(lab)
	operator = lab.get_node("Operator")
	await wait_physics_frames(10)


func after_each() -> void:
	for action in ["move_left", "move_right", "move_forward", "move_back"]:
		Input.action_release(action)
	Engine.physics_ticks_per_second = original_physics_rate


func test_walk_has_bounded_speed_and_diagonal_is_not_faster() -> void:
	Input.action_press("move_right")
	await wait_physics_frames(20)
	var straight_speed := Vector2(operator.velocity.x, operator.velocity.z).length()
	Input.action_press("move_back")
	await wait_physics_frames(20)
	var diagonal_speed := Vector2(operator.velocity.x, operator.velocity.z).length()
	assert_almost_eq(straight_speed, 2.6, 0.02)
	assert_almost_eq(diagonal_speed, straight_speed, 0.02)
	assert_true(operator.is_on_floor(), "Player stays grounded")


func test_wall_blocks_and_releasing_input_stops() -> void:
	Input.action_press("move_forward")
	await wait_physics_frames(150)
	assert_gt(operator.position.z, -1.7, "Capsule cannot cross the wall")
	assert_lt(operator.position.z, -1.4, "Player reaches the wall")
	assert_almost_eq(operator.position.y, 0.0, 0.03)
	Input.action_release("move_forward")
	await wait_physics_frames(20)
	assert_almost_eq(operator.velocity.length(), 0.0, 0.01)


func test_distance_is_consistent_at_different_physics_rates() -> void:
	var distances: Array[float] = []
	for rate in [30, 120]:
		Engine.physics_ticks_per_second = rate
		operator.position = Vector3(-4, 0, 2)
		operator.velocity = Vector3.ZERO
		Input.action_press("move_right")
		await wait_physics_frames(rate)
		Input.action_release("move_right")
		distances.append(operator.position.x + 4.0)
	assert_almost_eq(distances[0], distances[1], 0.12, "Equal simulated time has equal travel")
	assert_between(distances[0], 2.25, 2.7)
