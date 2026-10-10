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

func _convoy() -> Array:
	var fleet: Node = world.get_node("Fleet")
	var heavy: Node = fleet.DRONE.instantiate()
	heavy.hull_id = "goliath"
	heavy.identity = "heavy_test"
	heavy.battery = 0.2
	heavy.deployed = true
	heavy.position = Vector3(4,0.02,-35)
	fleet.add_child(heavy)
	var bank: Node = fleet.DRONE.instantiate()
	bank.hull_id = "tender"
	bank.identity = "bank_test"
	bank.battery = 6.0
	bank.deployed = true
	bank.position = Vector3(4,0.02,-31.1)
	bank.install("utility","power_coupler")
	fleet.add_child(bank)
	return [heavy,bank]

func test_heavy_power_consumes_finite_bank_and_distance_disconnects_actual_movement() -> void:
	var pair := _convoy()
	var heavy: Node = pair[0]
	var bank: Node = pair[1]
	var tether: Node = world.get_node("PowerTether")
	tether.set_physics_process(false)
	heavy.get_node("Controller").command = Vector2(0,-1)
	var initial: Vector3 = heavy.position
	await wait_physics_frames(10)
	assert_eq(heavy.position,initial,"Internal cell cannot move heavy chassis")
	assert_false(heavy.has_power())
	assert_true(tether.attach(heavy.identity,bank.identity))
	assert_true(heavy.install("tool","prefab_winch"))
	assert_true(load("res://scripts/salvage/cargo_hold.gd").can_load(heavy,1800.0))
	assert_false(load("res://scripts/salvage/cargo_hold.gd").can_load(world.get_node("Fleet").drone("mule_01"),1800.0))
	var before: float = bank.battery
	var demand: float = world.get_node("DronePower").required_kw(heavy)
	tether.advance(10.0)
	assert_almost_eq(before-bank.battery,demand*10.0/(3600.0*0.9),0.000001)
	assert_eq(heavy.battery,0.2,"Cable never creates stored heavy charge")
	heavy.get_node("Controller").command = Vector2(0,-1)
	await wait_physics_frames(90)
	assert_lt(heavy.position.z,initial.z-0.5)
	bank.position.z = -20.0
	tether.advance(0.1)
	assert_false(heavy.has_power())
	assert_true(tether.links.is_empty())
	assert_eq(heavy.get_node("Controller").command,Vector2.ZERO)
	bank.position = heavy.position + Vector3(0,0,3.9)
	assert_true(tether.attach(heavy.identity,bank.identity))
	bank.battery = 0.00001
	tether.advance(1.0)
	assert_eq(bank.battery,0.0)
	assert_false(heavy.has_power())
	bank.battery = 1.0
	assert_true(tether.attach(heavy.identity,bank.identity))
	var midpoint: Vector3 = (bank.position+heavy.position)*0.5
	load("res://scripts/world/surface_kit.gd").box(world.get_node("Surface"),"CableWall",Vector3(5,3,0.3),midpoint+Vector3(0,1.5,0),"rock")
	await wait_physics_frames(2)
	tether.advance(0.1)
	assert_false(heavy.has_power(),"A physical wall interrupts the cable")

func test_convoy_save_manual_gate_solar_and_gantry_payment() -> void:
	var pair := _convoy()
	var heavy: Node = pair[0]
	var bank: Node = pair[1]
	var tether: Node = world.get_node("PowerTether")
	assert_true(tether.attach(heavy.identity,bank.identity))
	var schema = load("res://scripts/persistence/save_schema.gd")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(schema.capture(world)))
	assert_eq(schema.validate(saved),"")
	schema.restore(world,saved)
	heavy = world.get_node("Fleet").drone("heavy_test")
	bank = world.get_node("Fleet").drone("bank_test")
	assert_true(heavy.has_power())
	var c: Node = world.get_node("FleetControl")
	c.select(heavy.identity)
	c.panel_open = true
	c.piloting = true
	InputContext.set_context(InputContext.Context.TERMINAL)
	c._physics_process(0.016)
	assert_false(c.piloting,"Heavy chassis remains scripted until neural artifact")
	assert_true(bank.install("utility_b","solar_panel"))
	var power: Node = world.get_node("DronePower")
	world.get_node("Weather").force("overcast")
	assert_eq(power.solar_kw(bank),1.0)
	world.get_node("Weather").force("sunlight")
	assert_eq(power.solar_kw(bank),1.75)
	tether.release(heavy.identity)
	heavy.position = Vector3(4,0.02,-20)
	var cargo: Node = world.get_node("Salvage").items.scrap_01
	cargo.state = "carried"
	cargo.carrier_id = heavy.identity
	heavy.cargo_kg = 24.0
	var stock: int = world.get_node("Inventory").scrap
	assert_true(c.request_machine_transfer(heavy,false))
	var life: Node = world.get_node("LifeSupport")
	life.set_physics_process(false)
	life.generator_on = false
	life.battery = 0.0
	life.advance(10.0)
	assert_eq(c.transfer.remaining,8.0,"No gantry work during blackout")
	assert_eq(world.get_node("Inventory").scrap,stock)
	life.generator_on = true
	life.advance(8.0)
	assert_true(c.transfer.is_empty())
	assert_true(heavy.deployed,"Heavy hull remains outside")
	assert_eq(world.get_node("Inventory").scrap,stock+16)
	assert_eq(heavy.cargo_kg,0.0)
	assert_eq(world.get_node("Salvage").deliver(heavy,true),0)
	world.get_node("Inventory").hulls.goliath = 1
	await wait_physics_frames(2) # Synchronize the fixture's earlier pose change.
	assert_false(world.get_node("Workshop").assemble("goliath"),"Occupied external bay blocks assembly")
	heavy.position = Vector3(10,0.02,-40)
	await wait_physics_frames(2)
	assert_true(world.get_node("Workshop").assemble("goliath"))
	assert_eq(world.get_node("Fleet").drone("goliath_01").battery,0.0)
	assert_true(world.get_node("Fleet").drone("goliath_01").deployed)
	saved.power_tethers.heavy_test = "missing_bank"
	assert_ne(schema.validate(saved),"")
	var ui: Node = world.get_node("ConvoyPanel")
	ui.open()
	ui._process(0.01)
	assert_false("%s" in ui.info.text,"Status includes actual values")
	assert_true(ui.panel.get_theme_stylebox("panel").bg_color.a > 0.99,"Opaque terminal")
