extends GutTest

var lab: Node3D
var operator: CharacterBody3D
var head: Node3D


func before_each() -> void:
	lab = load("res://scenes/diagnostics/movement.tscn").instantiate()
	add_child_autofree(lab)
	operator = lab.get_node("Operator")
	head = operator.get_node("Head")
	await wait_physics_frames(5)


func after_each() -> void:
	Input.action_release("move_forward")
	InputContext.set_context(InputContext.Context.MENU)


func test_look_rotates_body_yaw_and_clamps_pitch() -> void:
	head.apply_look(Vector2(100, 100000))
	assert_almost_eq(operator.rotation.y, -0.25, 0.001)
	assert_almost_eq(head.rotation.x, deg_to_rad(-80), 0.001)
	head.apply_look(Vector2(0, -100000))
	assert_almost_eq(head.rotation.x, deg_to_rad(80), 0.001)


func test_menu_and_terminal_block_movement_and_look() -> void:
	Input.action_press("move_forward")
	await wait_physics_frames(20)
	for context in [InputContext.Context.MENU, InputContext.Context.TERMINAL]:
		InputContext.set_context(context)
		var before_position := operator.position
		var before_yaw := operator.rotation.y
		head.apply_look(Vector2(100, 100))
		await wait_physics_frames(10)
		assert_almost_eq(operator.position.z, before_position.z, 0.001)
		assert_almost_eq(operator.rotation.y, before_yaw, 0.001)
	InputContext.set_context(InputContext.Context.WALK)
	var before_resume := operator.position.z
	await wait_physics_frames(10)
	assert_lt(operator.position.z, before_resume)
