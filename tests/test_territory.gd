extends GutTest
const Schema = preload("res://scripts/persistence/save_schema.gd")
const DroneScene = preload("res://scenes/drones/drone.tscn")
var session: Node
var world: Node
var net: Node
var life: Node
var fleet: Node
func before_each() -> void:
	InputContext.menu_locked = false
	InputContext.set_context(InputContext.Context.WALK)
	session = load("res://scenes/ui/main_menu.tscn").instantiate()
	session.save_path = "user://tests/territory_%d.json" % Time.get_ticks_usec()
	add_child_autofree(session)
	session.new_game()
	world = session.world
	net = world.get_node("Territory")
	life = world.get_node("LifeSupport")
	fleet = world.get_node("Fleet")
	life.set_physics_process(false)
	net.set_physics_process(false)
	world.get_node("Radio").dropout_chance = 0.0
	for id in ["recovery","network","heavy"]:
		world.get_node("Research").archives[id] = {"state":"delivered","carrier":""}
		world.get_node("Research").completed.append(id)
	await wait_physics_frames(2)
func after_each() -> void:
	get_tree().paused = false
	InputContext.menu_locked = false
	InputContext.set_context(InputContext.Context.WALK)
	await wait_process_frames(2)
func scout(id: String, band: int) -> Node:
	var drone: Node = fleet.drone(id)
	if drone == null:
		drone = DroneScene.instantiate()
		drone.identity = id
		fleet.add_child(drone)
	if drone.modules.has("utility"): drone.remove_module("utility")
	assert_true(drone.install("utility","high_gain_dish"))
	drone.deployed = true
	drone.battery = drone.hull().battery_kwh
	drone.position = net.pad(band) + Vector3(0,0,3)
	await wait_physics_frames(2)
	return drone
func heavy() -> Node:
	var g: Node = DroneScene.instantiate()
	g.identity = "build_01"
	g.hull_id = "goliath"
	g.battery = 0.2
	g.deployed = true
	g.position = Vector3(-4,0.02,-17)
	assert_true(g.install("tool","prefab_winch"))
	fleet.add_child(g)
	var t: Node = DroneScene.instantiate()
	t.identity = "bank_01"
	t.hull_id = "tender"
	t.deployed = true
	t.battery = 12.0
	t.position = Vector3(-4,0.02,-20)
	assert_true(t.install("utility","power_coupler"))
	fleet.add_child(t)
	await wait_physics_frames(2)
	assert_true(world.get_node("PowerTether").attach(g.identity,t.identity))
	return g
func at_site(g: Node, band: int) -> void:
	g.position = net.pad(band)+Vector3(-3.5,0,0)
	fleet.drone("bank_01").position = g.position+Vector3(0,0,3)
	await wait_physics_frames(2)
func test_adjacent_only_claim_real_relay_and_upstream_loss() -> void:
	var s: Node = await scout("mule_01",1)
	assert_false(net.anchor(s.identity,2),"Cannot skip a band")
	s.position.x = 45
	await wait_physics_frames(2)
	assert_false(net.anchor(s.identity,1),"Cannot found a sideways site")
	s.position = net.pad(1)+Vector3(0,0,3)
	await wait_physics_frames(2)
	assert_true(net.anchor(s.identity,1))
	assert_false(net.anchor(s.identity,1),"Cannot repeat or go backwards")
	var second: Node = await scout("hover_01",2)
	assert_gt(world.get_node("Radio").quality(second),0.0,"First relay reaches next band")
	assert_true(net.anchor(second.identity,2))
	assert_eq(net.frontier(),2)
	assert_true(net.online(2))
	s.battery = 0.0
	assert_false(net.online(2),"Downstream cannot skip its dead upstream node")
	assert_eq(world.get_node("Radio").quality(second),0.0)
	assert_eq(net.frontier(),2,"Earned ground remains recorded")
	s.battery = 1.0
	assert_true(net.online(2))
	world.get_node("Radio").drops[s.identity] = 2.0
	assert_false(net.online(2),"An upstream packet blackout reaches downstream")
	world.get_node("Radio").drops.clear()
	world.get_node("Radio").range_multiplier = 0.0
	assert_false(net.online(2),"Aurora still disables wireless")
	world.get_node("Radio").range_multiplier = 1.0
	s.position += Vector3(20,0,0)
	assert_false(net.online(2),"Moving the relay breaks the path")
	assert_true(net.release_relay(s.identity))
	s.position = net.pad(1)+Vector3(0,0,3)
	await wait_physics_frames(2)
	assert_true(net.anchor(s.identity,1),"Existing relay can be restored without adding ground")
	assert_eq(net.frontier(),2)
	assert_true(net.online(2))
func test_paid_prefab_carriage_powered_build_and_once_completion() -> void:
	var s: Node = await scout("mule_01",1)
	assert_true(net.anchor(s.identity,1))
	var g: Node = await heavy()
	assert_false(net.load_prefab(s.identity,"pylon"),"Small hull cannot haul structures")
	assert_true(net.load_prefab(g.identity,"pylon"))
	assert_eq(world.get_node("Inventory").scrap,0)
	assert_eq(g.cargo_kg,600.0)
	assert_false(world.get_node("Workshop").remove(g.identity,"tool"),"Loaded prefab retains its carrying winch")
	assert_false(net.load_prefab(g.identity,"pylon"))
	assert_false(net.construct(g.identity,2),"Cannot build on unearned ground")
	await at_site(g,1)
	assert_true(net.construct(g.identity,1))
	world.get_node("PowerTether").links.clear()
	net.advance(60)
	assert_eq(net.job.remaining,180.0,"Unpowered work holds")
	assert_true(world.get_node("PowerTether").attach(g.identity,"bank_01"))
	var bank_before: float = fleet.drone("bank_01").battery
	world.get_node("PowerTether").advance(60)
	assert_lt(fleet.drone("bank_01").battery,bank_before,"Powered construction consumes finite convoy energy")
	net.advance(60)
	assert_eq(net.job.remaining,120.0)
	assert_eq(Schema.validate(Schema.capture(world)),"")
	var paid := JSON.parse_string(JSON.stringify(Schema.capture(world))) as Dictionary
	Schema.restore(world,paid)
	g = fleet.drone(g.identity)
	assert_eq(net.job.remaining,120.0)
	assert_eq(g.cargo_kg,600.0)
	assert_eq(world.get_node("Inventory").scrap,0)
	await wait_physics_frames(2)
	net.advance(120)
	assert_true(net.sites[1].pylon)
	assert_true(net.job.is_empty())
	assert_eq(g.cargo_kg,0.0)
	assert_eq(net.sites[1].battery,0.0,"Construction creates no energy")
	assert_false(net.construct(g.identity,1))
	assert_true(g.get_node("Controller").available)
func build_fixture() -> void:
	var state: Dictionary = net.snapshot()
	for i in range(1,3):
		state.sites[i].held = true
		state.sites[i].pylon = true
		state.sites[i].battery = 0.0
	net.restore(state)
	await wait_physics_frames(2)
func test_grid_charging_conserves_energy_blackout_and_wire_loss() -> void:
	await build_fixture()
	assert_true(net.wired(2))
	world.get_node("Radio").range_multiplier = 0.0
	assert_true(net.wired(2),"Physical conduits are distinct from the scrambled radio")
	world.get_node("Radio").range_multiplier = 1.0
	life.generator_on = false
	life.battery = 0.0
	life.advance(10)
	assert_eq(net.sites[1].battery,0.0)
	assert_eq(net.sites[2].battery,0.0)
	life.generator_on = true
	life.battery = 2.0
	life.advance(1)
	assert_almost_eq(net.sites[1].battery,1.0/3600.0,0.0000001)
	assert_almost_eq(net.sites[2].battery,1.0/3600.0,0.0000001)
	assert_eq(life.territory_load_kw,2.0)
	net.sites[1].condition = 0.0
	var previous: float = net.sites[2].battery
	life.advance(2)
	assert_eq(net.sites[2].battery,previous,"No upstream wire, no free downstream charge")
	assert_false(net.wired(2))
	net.sites[1].condition = 100.0
	var wall := preload("res://scripts/world/surface_kit.gd").box(world.get_node("Surface"),"WireBlock",Vector3(30,9,1),Vector3(8,4.5,-170))
	await wait_physics_frames(2)
	assert_false(net.wired(2),"Actual cover severs conduit path")
	wall.queue_free()
func test_finite_pylon_cell_and_heavy_cable_stop_real_motor() -> void:
	await build_fixture()
	net.sites[1].battery = 1.0
	var mule: Node = fleet.drone("mule_01")
	mule.deployed = true
	mule.battery = 0.0
	mule.position = net.pad(1)+Vector3(0,0,3)
	await wait_physics_frames(2)
	net.advance(3.6)
	assert_almost_eq(mule.battery,0.001,0.0000001)
	assert_lt(net.sites[1].battery,1.0)
	var g: Node = await heavy()
	await at_site(g,1)
	assert_true(world.get_node("PowerTether").release(g.identity))
	assert_true(net.attach_power(g.identity,1))
	assert_false(world.get_node("PowerTether").attach(g.identity,"bank_01"),"Heavy cannot collect from two donors")
	assert_true(g.has_power())
	var before: float = net.sites[1].battery
	net.advance(1)
	assert_lt(net.sites[1].battery,before)
	net.sites[1].battery = 0.0000001
	net.advance(1)
	assert_false(g.has_power())
	assert_true(net.power_links.is_empty())
	var position: Vector3 = g.position
	g.get_node("Controller").command = Vector2(0,-1)
	await wait_physics_frames(30)
	assert_lt(g.position.distance_to(position),0.05,"Depleted field bank stops the physical hull")
	net.sites[1].battery = 1.0
	assert_true(net.attach_power(g.identity,1))
	g.position += Vector3(-5,0,0)
	net.advance(0.1)
	assert_false(g.has_power(),"Cannot stretch cable beyond 6m")
func test_fob_requires_pylon_physical_footprint_and_saved_battery() -> void:
	var s: Node = await scout("mule_01",1)
	assert_true(net.anchor(s.identity,1))
	var g: Node = await heavy()
	world.get_node("Inventory").scrap = 150
	assert_true(net.load_prefab(g.identity,"fob"))
	await at_site(g,1)
	assert_false(net.construct(g.identity,1),"Depot requires a completed pylon")
	var state: Dictionary = net.snapshot()
	state.sites[1].pylon = true
	state.sites[1].battery = 3.0
	net.restore(state)
	await wait_physics_frames(2)
	var block := preload("res://scripts/world/surface_kit.gd").box(world.get_node("Surface"),"BlockedDepot",Vector3(2,2,2),net.pad(1)+Vector3(5,1,0))
	await wait_physics_frames(2)
	assert_false(net.construct(g.identity,1),"Physical obstruction holds construction")
	block.queue_free()
	await wait_physics_frames(2)
	assert_true(net.construct(g.identity,1))
	world.get_node("PowerTether").advance(300)
	net.advance(300)
	assert_true(net.sites[1].fob)
	assert_eq(g.cargo_kg,0.0)
	assert_true(net.visuals[1].has_node("DepotRoof"))
	assert_eq(world.get_node("Inventory").scrap,0)
	var data := JSON.parse_string(JSON.stringify(Schema.capture(world))) as Dictionary
	assert_eq(Schema.validate(data),"")
	var bank: float = net.sites[1].battery
	Schema.restore(world,data)
	assert_true(net.sites[1].fob)
	assert_almost_eq(net.sites[1].battery,bank,0.0000001)
	assert_false(net.construct(g.identity,1),"No duplicate depot")
func test_schema_migration_rejects_skips_and_panel_fits() -> void:
	var data := Schema.capture(world)
	data.version = 23
	data.erase("territory")
	assert_eq(Schema.validate(data),"")
	Schema.restore(world,data)
	assert_eq(net.frontier(),0)
	var invalid := Schema.capture(world)
	invalid.territory.sites[2].held = true
	assert_ne(Schema.validate(invalid),"")
	invalid = Schema.capture(world)
	invalid.territory.cargo.mule_01 = "pylon"
	assert_ne(Schema.validate(invalid),"","Saved mass and compatible carrier required")
	var panel: Node = world.get_node("TerritoryPanel")
	panel.open()
	await wait_process_frames(2)
	assert_lte(panel.panel.get_combined_minimum_size().y,480.0)
	assert_lte(panel.panel.get_combined_minimum_size().x,640.0)
	var buttons: Array = panel.panel.find_children("*","Button",true,false)
	assert_lte(buttons.back().global_position.y+buttons.back().size.y,480.0)
	buttons.back().pressed.emit()
	assert_true(world.get_node("FleetPanel").panel.visible)
