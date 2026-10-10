extends GutTest
const Part = preload("res://scripts/drones/part_condition.gd")
var world: Node

func before_each() -> void:
	world = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(world)
	await wait_physics_frames(2)

func after_each() -> void:
	await wait_process_frames(2)

func test_exact_bands_and_seeded_sampling_frequency() -> void:
	assert_eq(Part.efficiency(20.0),0.35)
	assert_eq(Part.efficiency(20.01),1.0)
	assert_eq(Part.efficiency(80.0),1.0)
	assert_eq(Part.efficiency(80.01),1.2)
	assert_eq(Part.malfunction_chance(20.0),0.5)
	assert_eq(Part.malfunction_chance(50.0),0.1)
	assert_eq(Part.malfunction_chance(100.0),0.0)
	var faults: Node = world.get_node("Conditions")
	var mule: Node = world.get_node("Fleet").drone("mule_01")
	var counts := {"low":0,"normal":0,"high":0}
	for band in counts:
		for trial in range(1000):
			mule.condition.sensor_a = 10.0 if band == "low" else (50.0 if band == "normal" else 100.0)
			mule.faults.clear()
			faults.sample_work_cycle(mule)
			if mule.faults.has("sensor_a"):
				counts[band] += 1
	assert_between(counts.low,440,560)
	assert_between(counts.normal,65,135)
	assert_eq(counts.high,0)

func test_distance_load_wear_fault_effects_and_paid_repair() -> void:
	var mule: Node = world.get_node("Fleet").drone("mule_01")
	var system: Node = world.get_node("Conditions")
	system.set_physics_process(false)
	mule.deployed = true
	system.advance(0.0)
	mule.position.z = -60.0
	mule.cargo_kg = 20.0
	system.advance(1.0)
	assert_lt(mule.components.joints,100.0)
	assert_lt(mule.condition.sensor_a,100.0)
	mule.faults.joints = 8.0
	assert_eq(mule.component_efficiency("joints"),0.0)
	mule.faults.sensor_a = 8.0
	assert_false(mule.get_node("Sonar").ping())
	var before: int = world.get_node("Inventory").scrap
	assert_false(world.get_node("Workshop").repair(mule.identity,"joints"),"No remote repair")
	mule.deployed = false
	assert_true(world.get_node("Workshop").repair(mule.identity,"joints"))
	assert_lt(world.get_node("Inventory").scrap,before)
	assert_eq(mule.components.joints,100.0)
	assert_false(mule.faults.has("joints"))
	var schema = load("res://scripts/persistence/save_schema.gd")
	var data: Dictionary = JSON.parse_string(JSON.stringify(schema.capture(world)))
	assert_eq(schema.validate(data),"")
	schema.restore(world,data)
	assert_eq(world.get_node("Fleet").drone("mule_01").faults.sensor_a,8.0)
