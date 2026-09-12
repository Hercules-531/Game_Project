extends GutTest

var airlock: Node3D


func before_each() -> void:
	airlock = load("res://scenes/bunker/airlock.tscn").instantiate()
	add_child_autofree(airlock)
	airlock.cycle_seconds = 0.1


func test_surface_door_requires_authorization() -> void:
	assert_false(airlock.request_open(&"outer"))
	assert_eq(airlock.opened_side, &"")
	assert_false(airlock.request_open(&"invalid"))


func test_interlock_and_real_door_positions() -> void:
	airlock.outer_authorized = true
	assert_true(airlock.request_open(&"inner"))
	assert_false(airlock.request_open(&"outer"), "Cannot switch during a cycle")
	await wait_seconds(0.2)
	assert_eq(airlock.opened_side, &"inner")
	assert_almost_eq(airlock.get_node("InnerDoor").position.x, 1.8, 0.01)
	assert_false(airlock.request_open(&"outer"), "Cannot open both doors")
	assert_true(airlock.request_close())
	await wait_seconds(0.2)
	assert_true(airlock.request_open(&"outer"))
	await wait_seconds(0.2)
	assert_almost_eq(airlock.get_node("InnerDoor").position.x, 0.0, 0.01)
	assert_almost_eq(airlock.get_node("OuterDoor").position.x, 1.8, 0.01)
