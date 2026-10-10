extends GutTest

const Model = preload("res://scripts/drones/drone.gd")
const Fleet = preload("res://scripts/drones/fleet.gd")
const Schema = preload("res://scripts/persistence/save_schema.gd")


func test_exact_opening_pair_and_blind_salvage_loadout() -> void:
	var fleet := Fleet.new()
	add_child_autofree(fleet)
	assert_eq(fleet.get_child_count(),2)
	var mule: Node = fleet.drone("mule_01")
	var hover: Node = fleet.drone("hover_01")
	assert_eq(mule.hull_id,"mule")
	assert_true("sonar" in mule.modules.values())
	assert_true("thermal" in mule.modules.values())
	assert_false("ccd" in mule.modules.values())
	assert_eq(hover.hull().motion,"hover")
	assert_true("ccd" in hover.modules.values())
	assert_almost_eq(mule.module_mass(),19.0,0.000001)
	assert_almost_eq(mule.draw_kw(),0.21,0.000001)
	assert_almost_eq(hover.payload_remaining(),30.0,0.000001)


func test_socket_and_payload_checks_preserve_configuration() -> void:
	var drone := Model.new()
	drone.identity = "test"
	add_child_autofree(drone)
	assert_false(drone.install("tool","ccd"))
	assert_false(drone.install("missing","sonar"))
	drone.cargo_kg = 98.0
	assert_false(drone.install("sensor_a","sonar"))
	drone.cargo_kg = 0.0
	assert_true(drone.install("sensor_a","sonar",45.0))
	assert_false(drone.install("sensor_a","thermal"))
	assert_false(drone.install("sensor_b","thermal",-1.0))
	var removed: Dictionary = drone.remove_module("sensor_a")
	assert_eq(removed.id,"sonar")
	assert_eq(removed.condition,45.0)
	assert_true(drone.install("sensor_a","ccd"))
	assert_true(Model.validate(drone.snapshot()))


func test_fleet_serialization_preserves_identity_and_configuration() -> void:
	var fleet := Fleet.new()
	add_child_autofree(fleet)
	var mule: Node = fleet.drone("mule_01")
	mule.remove_module("sensor_a")
	mule.install("sensor_a","ccd",68.0)
	mule.position = Vector3(1.5,0.02,-10.0)
	mule.battery = 0.4
	var saved: Array = JSON.parse_string(JSON.stringify(fleet.snapshot()))
	assert_true(Fleet.validate(saved))
	fleet.restore(saved)
	assert_eq(fleet.drone("mule_01").modules.sensor_a,"ccd")
	assert_eq(fleet.drone("mule_01").condition.sensor_a,68.0)
	assert_eq(fleet.drone("mule_01").position,Vector3(1.5,0.02,-10.0))
	assert_eq(fleet.drone("mule_01").battery,0.4)
	saved.append(saved[0])
	assert_false(Fleet.validate(saved),"Duplicate identity cannot create a second machine")
	await wait_process_frames(2)


func test_campaign_snapshot_and_old_save_migration() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(world)
	var data: Dictionary = Schema.capture(world)
	assert_eq(data.fleet.size(),2)
	assert_eq(Schema.validate(JSON.parse_string(JSON.stringify(data))),"")
	data.version = 2
	data.erase("fleet")
	assert_eq(Schema.validate(data),"")
	Schema.restore(world,data)
	assert_eq(world.get_node("Fleet").get_child_count(),2)
	var machine: Dictionary = world.get_node("Fleet").snapshot()[0]
	machine.modules.tool = "ccd"
	assert_false(Model.validate(machine),"Incompatible saved modules are rejected")
	await wait_process_frames(2)
