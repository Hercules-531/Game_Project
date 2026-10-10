extends GutTest
var world: Node
var mule: Node
var orders: Node
const Schema = preload("res://scripts/persistence/save_schema.gd")
func before_each() -> void:
	world = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(world)
	mule = world.get_node("Fleet").drone("mule_01")
	orders = world.get_node("Orders")
	world.get_node("Radio").dropout_chance = 0.0
	mule.deployed = true
	mule.position = Vector3(-3,0.02,-22)
	await wait_physics_frames(2)
func after_each() -> void:
	InputContext.set_context(InputContext.Context.MENU)
	await wait_process_frames(2)
func reload() -> void:
	var data: Dictionary = JSON.parse_string(JSON.stringify(Schema.capture(world)))
	assert_eq(Schema.validate(data),"")
	Schema.restore(world,data)
	mule = world.get_node("Fleet").drone("mule_01")

func test_two_programs_move_real_bodies_reload_and_manual_interrupt() -> void:
	assert_false(orders.submit("mule_01",[{"kind":"waypoint","x":NAN,"north":20}]))
	assert_true(orders.programs.is_empty())
	assert_true(orders.submit("mule_01",[{"kind":"waypoint","x":-3.0,"north":20.0}]))
	var hover: Node = world.get_node("Fleet").drone("hover_01")
	hover.deployed = true
	hover.position = Vector3(3,0.02,-22)
	assert_true(orders.submit("hover_01",[{"kind":"waypoint","x":3.0,"north":20.0}]))
	await wait_physics_frames(60)
	assert_lt(mule.position.z,-24.0)
	assert_lt(hover.position.z,-24.0)
	reload()
	await wait_physics_frames(90)
	assert_eq(orders.programs.hover_01.mode,"complete")
	var control: Node = world.get_node("FleetControl")
	control.piloting = true
	control.selected_id = "mule_01"
	orders.advance(0.1)
	assert_eq(orders.programs.mule_01.mode,"interrupted")
	assert_eq(mule.get_node("Controller").command,Vector2.ZERO)

func test_low_cell_returns_over_route_before_loading_and_docks_once() -> void:
	var trail: RefCounted = world.get_node("Failsafes").history("mule_01")
	trail.points.assign([Vector3(-3,0.02,-16),Vector3(-3,0.02,-19),Vector3(-3,0.02,-22)])
	mule.position = Vector3(-3,0.02,-46)
	trail.points.append(mule.position)
	mule.battery = 0.19
	assert_true(orders.submit("mule_01",[{"kind":"scrap_collect"},{"kind":"waypoint","x":-3.0,"north":60.0},{"kind":"battery_abort"}]))
	orders.advance(0.1)
	assert_eq(orders.programs.mule_01.mode,"return")
	assert_eq(mule.cargo_kg,0.0,"Abort precedes pickup")
	await wait_physics_frames(120)
	reload()
	await wait_physics_frames(1020)
	assert_false(mule.deployed,"Return enters the real timed loader")
	assert_eq(orders.programs.mule_01.mode,"complete")
	assert_eq(world.get_node("Inventory").scrap,80)

func test_local_scrap_and_sensor_gated_silence_obstruction_and_loss() -> void:
	mule.position = Vector3(-3,0.02,-46)
	orders.submit("mule_01",[{"kind":"scrap_collect"}])
	orders.advance(0.1)
	assert_eq(mule.cargo_kg,24.0)
	assert_eq(world.get_node("Inventory").scrap,80)
	var beacon := Node3D.new()
	world.add_child(beacon)
	beacon.position = mule.position + Vector3(2,0,-5)
	beacon.add_to_group("hostile_pings")
	mule.get_node("Sonar").last_ping = -100
	orders.submit("mule_01",[{"kind":"hostile_silent"},{"kind":"waypoint","x":-3.0,"north":50.0}])
	orders.advance(0.1)
	assert_true(mule.silent_running)
	assert_false(mule.get_node("Sonar").ping(),"Silence inhibits active sonar")
	world.get_node("Radio").range_multiplier = 0.0
	world.get_node("Failsafes").advance(0.1)
	orders.advance(0.1)
	assert_eq(mule.get_node("Controller").command,Vector2.ZERO,"Ordinary loss owns failsafe")
	world.get_node("Radio").range_multiplier = 1.0
	orders.stop("mule_01")
	assert_false(mule.silent_running)
	mule.position = Vector3(0,0.02,-30)
	var wall = load("res://scripts/world/surface_kit.gd").box(world.get_node("Surface"),"ProgramWall",Vector3(4,2,0.4),Vector3(0,1,-31.1))
	await wait_physics_frames(2)
	orders.submit("mule_01",[{"kind":"waypoint","x":0.0,"north":30.0}])
	await wait_physics_frames(240)
	assert_eq(orders.programs.mule_01.mode,"blocked")
	wall.queue_free()
	beacon.queue_free()

func test_safety_rules_remain_active_at_a_completed_waypoint() -> void:
	orders.submit("mule_01",[{"kind":"waypoint","x":-3.0,"north":12.0},{"kind":"battery_abort"}])
	orders.advance(0.1)
	orders.advance(0.1)
	assert_eq(orders.programs.mule_01.mode,"complete")
	mule.battery = 0.2
	orders.advance(0.1)
	assert_eq(orders.programs.mule_01.mode,"complete","Exactly 20% does not abort")
	mule.battery = 0.199
	orders.advance(0.1)
	assert_eq(orders.programs.mule_01.mode,"return","Standing safety runs after travel completes")

func test_loader_holds_physical_body_while_autonomy_waits() -> void:
	mule.position = Vector3(-2,0.02,-16)
	orders.submit("mule_01",[{"kind":"battery_abort"}])
	mule.battery = 0.19
	await wait_physics_frames(180)
	assert_false(world.get_node("FleetControl").transfer.is_empty())
	assert_almost_eq(mule.position.y,0.02,0.01,"Hidden loader body must not fall through its disabled collision")
	assert_false(mule.get_node("Controller").available)
