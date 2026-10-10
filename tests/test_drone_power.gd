extends GutTest

var world: Node
var power: Node
var mule: Node


func before_each() -> void:
	world = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(world)
	power = world.get_node("DronePower")
	power.set_physics_process(false)
	mule = world.get_node("Fleet").drone("mule_01")
	await wait_physics_frames(3)


func after_each() -> void:
	await wait_process_frames(2)


func test_field_draw_load_and_empty_cell_stop_real_movement() -> void:
	mule.deployed = true
	mule.position = Vector3(0,0.02,-20)
	var idle: float = power.draw_kw(mule)
	mule.get_node("Controller").command = Vector2(0,-1)
	var travel: float = power.draw_kw(mule)
	assert_gt(travel,idle)
	mule.cargo_kg = 20.0
	assert_gt(power.draw_kw(mule),travel)
	power.advance(10000.0)
	assert_eq(mule.battery,0.0)
	var at: Vector3 = mule.position
	mule.get_node("Controller").command = Vector2(0,-1)
	await wait_physics_frames(5)
	assert_eq(mule.position,at)
	assert_false(mule.get_node("Sonar").ping())


func test_charging_is_paid_by_grid_never_last_frames_fraction() -> void:
	var life: Node = world.get_node("LifeSupport")
	life.set_physics_process(false)
	mule.battery = 0.3
	life.generator_on = false
	life.battery = 0.0
	life.supplied_fraction = 1.0
	power._update_charge_request()
	life.advance(1.0)
	assert_eq(mule.battery,0.3,"No energy from stale supply fraction")
	life.generator_on = true
	var before: float = mule.battery
	life.advance(1.0)
	assert_gt(mule.battery,before)
	assert_lte(mule.battery - before,life.balance.generator_kw / 3600.0)
	power.charge_on = false
	power._update_charge_request()
	before = mule.battery
	life.advance(5.0)
	assert_eq(mule.battery,before)
	mule.deployed = true
	power.charge_on = true
	power._update_charge_request()
	assert_false(power.requests.has(mule.identity))


func test_capacity_and_saved_stranding_are_preserved() -> void:
	var life: Node = world.get_node("LifeSupport")
	life.set_physics_process(false)
	mule.battery = 0.99999
	power._update_charge_request()
	life.advance(3.0)
	assert_eq(mule.battery,1.0)
	mule.deployed = true
	mule.battery = 0.0
	power.charge_on = false
	var schema = load("res://scripts/persistence/save_schema.gd")
	var data: Dictionary = schema.capture(world)
	schema.restore(world,JSON.parse_string(JSON.stringify(data)))
	mule = world.get_node("Fleet").drone("mule_01")
	assert_eq(mule.battery,0.0)
	assert_true(mule.deployed)
	assert_false(power.charge_on)
