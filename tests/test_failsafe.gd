extends GutTest

var world: Node
var mule: Node
var system: Node

func before_each() -> void:
	world = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(world)
	mule = world.get_node("Fleet").drone("mule_01")
	system = world.get_node("Failsafes")
	await wait_physics_frames(2)

func after_each() -> void:
	await wait_process_frames(2)

func test_freeze_and_retrace_use_real_body_without_teleport() -> void:
	mule.deployed = true
	mule.position = Vector3(0,0.02,-20)
	await wait_physics_frames(2)
	world.get_node("Radio").range_multiplier = 0.0
	mule.velocity = Vector3(0,0,-3)
	system.advance(0.016)
	assert_eq(mule.velocity,Vector3.ZERO)
	assert_eq(system.states[mule.identity].mode,"freeze")
	mule.install("utility","retrace")
	system.states[mule.identity].mode = "idle"
	system.history(mule.identity).points.assign([Vector3(0,0.02,-14),Vector3(0,0.02,-16)])
	var before: Vector3 = mule.position
	await wait_physics_frames(150)
	assert_eq(system.states[mule.identity].mode,"retrace")
	assert_gt(mule.position.z,before.z,"Return follows physical movement")
	assert_lt(mule.position.z,-14.0,"No instantaneous jump home")
	var schema = load("res://scripts/persistence/save_schema.gd")
	var data: Dictionary = JSON.parse_string(JSON.stringify(schema.capture(world)))
	assert_eq(schema.validate(data),"")
	var cursor: int = system.states[mule.identity].cursor
	var mid_return: float = mule.position.z
	schema.restore(world,data)
	# Test-only forced blackout is not saved weather. Reapply after weather restore.
	world.get_node("Radio").range_multiplier = 0.0
	mule = world.get_node("Fleet").drone("mule_01")
	assert_eq(system.states[mule.identity].cursor,cursor,"Full campaign restore preserves retrace cursor")
	await wait_physics_frames(80)
	assert_gt(mule.position.z,mid_return,"Interrupted return resumes physical motion")
	mule.battery = 0.0
	await wait_physics_frames(2)
	assert_eq(mule.velocity,Vector3.ZERO)

func test_blocked_trail_freezes_and_save_preserves_return_cursor() -> void:
	mule.install("utility","retrace")
	mule.deployed = true
	mule.position = Vector3(0,0.02,-20)
	world.get_node("Radio").range_multiplier = 0.0
	system.history(mule.identity).points.assign([Vector3(0,0.02,-14)])
	load("res://scripts/world/surface_kit.gd").box(world.get_node("Surface"),"BlockedReturn",Vector3(4,2,1),Vector3(0,1,-18.8))
	await wait_physics_frames(2)
	system.advance(3.0)
	assert_eq(system.states[mule.identity].mode,"freeze")
	assert_lt(mule.position.z,-19.0)
	var data: Dictionary = system.snapshot()
	assert_true(system.validate(JSON.parse_string(JSON.stringify(data))))
	system.restore(data)
	assert_eq(system.states[mule.identity].cursor,0)
	assert_eq(system.history(mule.identity).points.size(),1)
