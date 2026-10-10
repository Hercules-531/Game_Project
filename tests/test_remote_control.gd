extends GutTest

var world: Node


func before_each() -> void:
	world = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(world)
	await wait_physics_frames(3)


func after_each() -> void:
	InputContext.set_context(InputContext.Context.WALK)


func test_deployment_is_timed_interlocked_and_recall_is_local() -> void:
	var control: Node = world.get_node("FleetControl")
	var mule: Node = control.selected()
	assert_true(control.request_transfer(true))
	assert_false(control.request_transfer(true),"One sealed transfer at a time")
	assert_false(world.get_node("Bunker/Airlock").request_open(&"inner"))
	control.advance_transfer(7.0)
	assert_false(mule.deployed)
	control.advance_transfer(1.0)
	await wait_physics_frames(2)
	assert_true(mule.deployed)
	assert_true(mule.position.z < -10.0)
	assert_false(world.get_node("Bunker/Airlock").busy)
	mule.position.z = -70.0
	assert_false(control.request_transfer(false),"Dock cannot teleport a distant bot home")
	mule.position = Vector3(-2,0.02,-14)
	assert_true(control.request_transfer(false))
	control.advance_transfer(8.0)
	assert_false(mule.deployed)
	assert_true(mule.position.z > -6.0)


func test_control_switch_leaving_and_actual_surface_collision() -> void:
	var control: Node = world.get_node("FleetControl")
	world.get_node("FleetPanel").open()
	assert_true(control.request_transfer(true))
	control.advance_transfer(8.0)
	await wait_physics_frames(2)
	var mule: CharacterBody3D = control.selected()
	var operator_at: Vector3 = world.get_node("Operator").position
	control.piloting = true
	control.held = Vector2(0,-1)
	await wait_physics_frames(30)
	assert_lt(mule.position.z,-14.5)
	assert_almost_eq(world.get_node("Operator").position.z,operator_at.z,0.01)
	assert_true(control.select("hover_01"))
	await wait_physics_frames(10)
	assert_eq(mule.get_node("Controller").command,Vector2.ZERO)
	assert_false(control.select("missing"))
	control.select("mule_01")
	mule.position = Vector3(58,0.02,-30)
	mule.rotation.y = -PI / 2
	control.held = Vector2(0,-1)
	await wait_physics_frames(90)
	assert_lt(mule.position.x,60.1,"Real boundary collider stops bot")
	world.get_node("FleetPanel").close()
	assert_false(control.piloting)
	assert_eq(mule.velocity,Vector3.ZERO)
	assert_true(load("res://scripts/drones/drone.gd").validate(mule.snapshot()))
