extends GutTest

var main: Node
var operator: CharacterBody3D
var interactor: Node


func before_each() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(main)
	operator = main.get_node("Operator")
	interactor = operator.get_node("Interactor")
	await wait_physics_frames(4)


func _aim(at: Vector3, toward: Vector3) -> void:
	operator.position = at
	operator.get_node("Head/Camera").look_at(toward,Vector3.UP)
	await wait_physics_frames(3)


func test_station_use_blocks_input_and_exit_restores_walk() -> void:
	await _aim(Vector3(3.2,0.02,0.4),Vector3(3.2,1.03,-1.02))
	assert_true(interactor.use_target(),"Use actual CRT collider")
	assert_eq(InputContext.active,InputContext.Context.TERMINAL)
	assert_true(main.get_node("FleetPanel").panel.visible)
	assert_false(interactor.use_target(),"Terminal context blocks world interaction")
	main.get_node("FleetPanel").close()
	assert_eq(InputContext.active,InputContext.Context.WALK)
	assert_false(main.get_node("FleetPanel").panel.visible)


func test_range_and_wall_occlusion_prevent_use() -> void:
	await _aim(Vector3(3.2,0.02,2.7),Vector3(3.2,1.03,-1.02))
	assert_false(interactor.use_target(),"CRT beyond two metres")
	await _aim(Vector3(3.2,0.02,-2.6),Vector3(3.2,1.03,-1.02))
	assert_false(interactor.use_target(),"Wall blocks nearby CRT")


func test_physical_switch_changes_room_light() -> void:
	await _aim(Vector3(2.4,0.02,-0.25),Vector3(1.46,1.35,-0.25))
	assert_true(interactor.use_target())
	assert_false(main.get_node("Bunker/CommandLight").visible)
	assert_true(interactor.use_target())
	assert_true(main.get_node("Bunker/CommandLight").visible)


func test_airlock_wall_control_remains_reachable_and_sweep_is_safe() -> void:
	await _aim(Vector3(-0.65,0.02,-4.6),Vector3(-1.03,1.35,-5.85))
	assert_true(interactor.use_target())
	await wait_seconds(1.1)
	var airlock = main.get_node("Bunker/Airlock")
	assert_eq(airlock.opened_side,&"inner")
	operator.position = Vector3(0,0.02,-6)
	await wait_physics_frames(3)
	assert_false(airlock.request_close(),"Occupied aperture must not close")
	await _aim(Vector3(-1.03,0.02,-7.3),Vector3(-1.03,1.35,-6.15))
	assert_true(interactor.use_target(),"Inside control works with door hidden behind wall")
	await wait_seconds(1.1)
	assert_eq(airlock.opened_side,&"")
