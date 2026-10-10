extends GutTest

var world: Node
const Schema = preload("res://scripts/persistence/save_schema.gd")
const Router = preload("res://scripts/sensors/sensor_router.gd")


func before_each() -> void:
	world = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(world)
	await wait_physics_frames(3)


func after_each() -> void:
	await wait_process_frames(2)


func test_camera_is_recovered_delivered_once_then_fitted_as_hardware() -> void:
	var mule: Node = world.get_node("Fleet").drone("mule_01")
	var case: Node = world.get_node("CameraDiscovery")
	assert_eq(Router.tier(mule),0)
	assert_false(case.recover(mule),"Cannot take remote salvage from workshop")
	mule.deployed = true
	mule.position = Vector3(4,0.02,-60)
	assert_true(case.recover(mule))
	assert_false(case.recover(mule),"One physical find")
	assert_eq(mule.cargo_kg,4.0)
	var saved: Dictionary = Schema.capture(world)
	assert_eq(Schema.validate(JSON.parse_string(JSON.stringify(saved))),"")
	Schema.restore(world,saved)
	mule = world.get_node("Fleet").drone("mule_01")
	assert_eq(case.state,"carried")
	mule.deployed = false
	case._physics_process(0.0)
	case._physics_process(0.0)
	var stock: Node = world.get_node("Inventory")
	assert_eq(stock.parts.size(),4)
	assert_eq(mule.cargo_kg,0.0)
	var serial: int = stock.parts.back().serial
	assert_eq(stock.parts.back().id,"ccd")
	assert_eq(stock.parts.back().condition,65.0)
	assert_eq(Router.tier(mule),0,"Delivery alone grants no vision")
	world.get_node("Workshop").remove("mule_01","sensor_a")
	assert_true(world.get_node("Workshop").fit("mule_01","sensor_a",serial))
	assert_eq(Router.tier(mule),1)
	assert_false(world.get_node("Fabrication").start("ccd"))


func test_ccd_cadence_does_not_limit_world_simulation() -> void:
	var sensor: Node = world.get_node("Fleet").drone("hover_01").get_node("CCD")
	sensor.set_physics_process(false)
	sensor.accumulator = 0.0
	var before: int = sensor.frame_count
	for tick in range(60):
		sensor.advance(1.0 / 60.0)
	assert_eq(sensor.frame_count - before,15)
	var blind: Node = world.get_node("Fleet").drone("mule_01").get_node("CCD")
	blind.advance(1.0)
	assert_eq(blind.frame_count,0)
	var ticks: int = world.physics_ticks
	await wait_physics_frames(10)
	assert_gt(world.physics_ticks,ticks)
