extends GutTest
var world: Node
var tracked: Node
func before_each() -> void:
	world = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(world)
	tracked = world.get_node("Fleet").DRONE.instantiate()
	tracked.identity = "tracked_test"
	tracked.hull_id = "tracked"
	tracked.battery = 2.0
	tracked.deployed = true
	tracked.position = Vector3(25,0.02,-69)
	world.get_node("Fleet").add_child(tracked)
	world.get_node("FleetControl").set_physics_process(false)
	world.get_node("Failsafes").set_physics_process(false)
	await wait_physics_frames(2)
func after_each() -> void:
	await wait_process_frames(2)
func test_tracked_climbs_real_incline_that_stops_light_hull() -> void:
	var mule: Node = world.get_node("Fleet").drone("mule_01")
	mule.deployed = true
	mule.position = Vector3(22,0.02,-69)
	tracked.get_node("Controller").command = Vector2(0,-1)
	mule.get_node("Controller").command = Vector2(0,-1)
	await wait_physics_frames(240)
	assert_gt(tracked.position.y,2.0,"Track climbs the authored 30-degree physical ramp")
	assert_lt(mule.position.y,1.0,"Light hull cannot climb that incline")
	assert_lt(tracked.position.z,mule.position.z)
func test_scraper_changes_real_mud_travel_and_sealing_reduces_exposure() -> void:
	tracked.position = Vector3(-24,0.02,-60)
	tracked.get_node("Controller").command = Vector2(0,-1)
	await wait_physics_frames(120)
	var bare: float = -60.0 - tracked.position.z
	tracked.get_node("Controller").stop()
	tracked.position = Vector3(-24,0.02,-60)
	assert_true(tracked.install("utility","tread_scraper"))
	tracked.get_node("Controller").command = Vector2(0,-1)
	await wait_physics_frames(120)
	var scraped: float = -60.0 - tracked.position.z
	assert_gt(scraped,bare * 3.0)
	assert_gt(tracked.draw_kw(),tracked.hull().idle_kw)
	tracked.remove_module("utility")
	var h: Node = world.get_node("EnvironmentHazards")
	world.get_node("Weather").force("rain")
	h.rng.seed = 42
	var plain := 0
	for i in 1000:
		if h.sample_exposure(tracked): plain += 1
	assert_true(tracked.install("utility","sealed_housing"))
	h.rng.seed = 42
	var sealed := 0
	for i in 1000:
		if h.sample_exposure(tracked): sealed += 1
	assert_gt(sealed,0,"Sealing reduces risk without eliminating it")
	assert_lt(sealed,plain / 2)
func test_paid_tracked_fabrication_and_assembly_require_grid_charging() -> void:
	var inventory: Node = world.get_node("Inventory")
	var fabrication: Node = world.get_node("Fabrication")
	assert_true(fabrication.start("tracked_frame"))
	assert_eq(inventory.scrap,10)
	world.get_node("LifeSupport").supplied_fraction = 1.0
	fabrication.advance(180.0)
	assert_eq(inventory.hulls.tracked,1)
	assert_true(world.get_node("Workshop").assemble("tracked"))
	var made: Node = world.get_node("Fleet").drone("tracked_01")
	assert_eq(made.battery,0.0)
	assert_eq(inventory.hulls.tracked,0)
	assert_false(world.get_node("Workshop").assemble("tracked"))
	assert_false(world.get_node("Fleet").drone("mule_01").can_install("tool","heavy_winch"))
	var schema = load("res://scripts/persistence/save_schema.gd")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(schema.capture(world)))
	assert_eq(schema.validate(saved),"")
