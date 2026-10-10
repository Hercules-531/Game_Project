extends GutTest
var world: Node
var mule: Node
var recovery: Node
func before_each() -> void:
	world = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(world)
	mule = world.get_node("Fleet").drone("mule_01")
	recovery = world.get_node("Recovery")
	await wait_physics_frames(2)
func after_each() -> void:
	await wait_process_frames(2)
func round_trip() -> void:
	var schema = load("res://scripts/persistence/save_schema.gd")
	var data: Dictionary = JSON.parse_string(JSON.stringify(schema.capture(world)))
	assert_eq(schema.validate(data),"")
	schema.restore(world,data)
	mule = world.get_node("Fleet").drone("mule_01")

func test_finite_hotwire_preserves_condition_and_rescues_existing_bot() -> void:
	var target: Node = recovery.bodies.derelict_01
	mule.deployed = true
	mule.position = target.position + Vector3(0,0,2.5)
	assert_false(recovery.hotwire(mule,target))
	assert_true(mule.install("utility","jumper"))
	var before: float = mule.battery
	assert_true(recovery.hotwire(mule,target))
	assert_almost_eq(mule.battery,before - 0.25,0.00001)
	assert_almost_eq(target.battery,0.225,0.00001)
	assert_eq(target.components.joints,55.0)
	assert_eq(target.condition.tool,55.0)
	assert_eq(target.get_parent(),world.get_node("Fleet"))
	assert_false(recovery.hotwire(mule,target))
	var hover: Node = world.get_node("Fleet").drone("hover_01")
	hover.deployed = true
	hover.position = mule.position + Vector3(1,0,0)
	hover.battery = 0.0
	assert_true(recovery.hotwire(mule,hover))
	assert_gt(hover.battery,0.0)
	round_trip()
	assert_eq(recovery.bodies.derelict_01,world.get_node("Fleet").drone("derelict_01"))

func test_tow_is_physical_slow_and_breaks_on_distance_and_obstruction() -> void:
	var donor: Node = recovery.bodies.derelict_01
	var target: Node = recovery.bodies.derelict_02
	mule.deployed = true
	mule.position = donor.position + Vector3(0,0,2.5)
	mule.install("utility","jumper")
	recovery.hotwire(mule,donor)
	donor.position = target.position + Vector3(0,0,3.2)
	mule.position = donor.position + Vector3(3,0,0)
	assert_false(recovery.start_tow(mule,"derelict_02"))
	assert_true(recovery.start_tow(donor,"derelict_02"))
	assert_eq(donor.speed_multiplier,0.25)
	assert_eq(donor.work_noise,2.0)
	var before: Vector3 = target.position
	await wait_physics_frames(40)
	assert_gt(target.position.distance_to(before),0.1)
	await wait_physics_frames(300)
	assert_eq(recovery.records.derelict_02.state,"towing","Resting cable must not be mistaken for a blockage")
	donor.position.z += 2.0
	round_trip()
	donor = world.get_node("Fleet").drone("derelict_01")
	assert_eq(recovery.records.derelict_02.state,"towing","Reload retains a cable stretched past attachment range")
	assert_true(recovery.lines.has("derelict_02"))
	assert_eq(donor.speed_multiplier,0.25)
	donor.position.z += 10.0
	recovery.advance(0.1)
	assert_eq(recovery.records.derelict_02.state,"dormant")
	assert_eq(donor.speed_multiplier,1.0)
	target = recovery.bodies.derelict_02
	donor.position = target.position + Vector3(0,0,3.8)
	var wall = load("res://scripts/world/surface_kit.gd").box(world.get_node("Surface"),"TowBlock",Vector3(5,2,0.4),target.position + Vector3(0,1,1.1))
	await wait_physics_frames(2)
	assert_true(recovery.start_tow(donor,"derelict_02"))
	await wait_physics_frames(250)
	assert_eq(recovery.records.derelict_02.state,"dormant")
	assert_lt(target.position.z,before.z + 1.0)
	wall.queue_free()

func test_strip_delivers_once_with_condition_and_leaves_landmark() -> void:
	var target: Node = recovery.bodies.derelict_01
	mule.deployed = true
	mule.position = target.position + Vector3(0,0,2.5)
	mule.remove_module("tool")
	mule.install("tool","torch")
	assert_true(recovery.start_strip(mule,"derelict_01"))
	recovery.advance(20.0)
	assert_eq(mule.cargo_kg,20.0)
	assert_eq(world.get_node("Inventory").parts.size(),3)
	assert_eq(recovery.deliver(mule),0)
	round_trip()
	mule.deployed = false
	assert_eq(recovery.deliver(mule),0,"Home flag alone cannot credit field cargo")
	mule.position = Vector3(-5,0.02,1)
	assert_eq(recovery.deliver(mule),1)
	assert_eq(world.get_node("Inventory").parts.size(),6)
	assert_eq(world.get_node("Inventory").parts[5].condition,55.0)
	assert_eq(recovery.deliver(mule),0)
	assert_eq(recovery.records.derelict_01.state,"stripped")
	assert_true(is_instance_valid(recovery.bodies.derelict_01))
	assert_eq(recovery.bodies.derelict_01.modules.size(),0)
	var schema = load("res://scripts/persistence/save_schema.gd")
	var data: Dictionary = JSON.parse_string(JSON.stringify(schema.capture(world)))
	data.recovery.derelict_01.owner = "ghost"
	assert_ne(schema.validate(data),"")

