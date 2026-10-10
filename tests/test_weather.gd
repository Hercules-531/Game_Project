extends GutTest
var world: Node
var weather: Node
func before_each() -> void:
	world = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(world)
	weather = world.get_node("Weather")
	weather.set_physics_process(false)
	await wait_process_frames(2)
func after_each() -> void:
	InputContext.set_context(InputContext.Context.MENU)
	await wait_process_frames(2)
func test_forecast_transitions_match_and_saved_schedule_does_not_reroll() -> void:
	var first: Dictionary = weather.forecast[0].duplicate(true)
	weather.advance(300.0)
	assert_eq(weather.current,first.id)
	assert_eq(weather.remaining,first.duration)
	var schema = load("res://scripts/persistence/save_schema.gd")
	var data: Dictionary = JSON.parse_string(JSON.stringify(schema.capture(world)))
	assert_eq(schema.validate(data),"")
	var before: Dictionary = weather.snapshot()
	schema.restore(world,data)
	assert_eq(weather.snapshot(),before)
	var next: Dictionary = weather.forecast[0].duplicate(true)
	weather.advance(weather.remaining + 10.0)
	assert_eq(weather.current,next.id)
	assert_eq(weather.remaining,next.duration - 10.0)
	assert_false(weather.force("imaginary"))
	data.weather.remaining = -1.0
	assert_ne(schema.validate(data),"")
func test_partitioned_clock_produces_the_same_forecast() -> void:
	var initial: Dictionary = weather.snapshot()
	weather.advance(4200.5)
	var combined: Dictionary = weather.snapshot()
	weather.restore(initial)
	for i in 4200: weather.advance(1.0)
	weather.advance(0.5)
	assert_eq(weather.snapshot(),combined)

func test_paid_solar_construction_and_sunlight_feed_charge_real_cells() -> void:
	var solar: Node = world.get_node("Solar")
	var life: Node = world.get_node("LifeSupport")
	life.set_physics_process(false)
	assert_true(solar.construct())
	assert_eq(world.get_node("Inventory").scrap,56)
	assert_false(solar.construct())
	life.generator_on = false
	life.battery = 0.0
	life.advance(10.0)
	assert_eq(solar.remaining,60.0,"Blackout cannot finish paid construction")
	life.generator_on = true
	life.advance(60.0)
	assert_true(solar.installed)
	assert_eq(life.solar_load_kw,0.0)
	var drone: Node = world.get_node("Fleet").drone("mule_01")
	var power: Node = world.get_node("DronePower")
	drone.battery = 0.0
	life.battery = 0.0
	life.generator_on = false
	life.oxygen_on = false
	life.heater_on = false
	power._update_charge_request()
	weather.force("overcast")
	life.advance(10.0)
	var baseline: float = drone.battery
	assert_gt(baseline,0.0)
	drone.battery = 0.0
	life.battery = 0.0
	power._update_charge_request()
	weather.force("sunlight")
	life.advance(10.0)
	assert_almost_eq(drone.battery / baseline,1.75,0.00001,"75% boost reaches the cell through the paid grid")
	assert_eq(life.aux_generation_kw,1.75)
	solar.toggle()
	assert_eq(life.aux_generation_kw,0.0)
	var schema = load("res://scripts/persistence/save_schema.gd")
	var data: Dictionary = JSON.parse_string(JSON.stringify(schema.capture(world)))
	assert_eq(schema.validate(data),"")
	schema.restore(world,data)
	assert_true(solar.installed)
	assert_false(solar.enabled)

func test_smog_cuts_real_link_preserves_ir_and_restores_clean_state() -> void:
	var radio: Node = world.get_node("Radio")
	var drone: Node = world.get_node("Fleet").drone("hover_01")
	drone.deployed = true
	drone.position = Vector3(0,0.02,-115)
	weather.force("overcast")
	assert_gt(radio.quality(drone),0.0)
	weather.force("smog")
	assert_eq(radio.range_multiplier,0.6)
	assert_eq(radio.quality(drone),0.0,"A previously reachable machine loses contact")
	assert_between(radio.weather_latency,1.0,2.0)
	assert_eq(weather.mutant_sense_multiplier,0.5)
	assert_true(world.get_node("SurfaceEnvironment").environment.fog_enabled)
	assert_false(world.get_node("Bunker/Environment").environment.fog_enabled,"Bunker stays sealed")
	var mule: Node = world.get_node("Fleet").drone("mule_01")
	mule.deployed = true
	mule.position = Vector3(9,0.02,-40)
	await wait_physics_frames(2)
	assert_gt(mule.get_node("Thermal").sample().size(),0,"IR can see the local warm vent in smog")
	weather.force("overcast")
	assert_eq(radio.range_multiplier,1.0)
	assert_eq(weather.optical_static,0.0)
	assert_eq(weather.mutant_sense_multiplier,1.0)
	assert_false(world.get_node("SurfaceEnvironment").environment.fog_enabled)

func test_ash_scours_parts_and_exposes_once_deliverable_persistent_cache() -> void:
	var hazards: Node = world.get_node("EnvironmentHazards")
	hazards.set_physics_process(false)
	var parts: Node = world.get_node("Conditions")
	parts.set_physics_process(false)
	var drone: Node = world.get_node("Fleet").drone("hover_01")
	drone.deployed = true
	var armor: float = drone.components.armor
	weather.force("overcast")
	parts.advance(10.0)
	var normal: float = armor - drone.components.armor
	drone.components.armor = armor
	weather.force("ash")
	parts.advance(10.0)
	assert_almost_eq(armor - drone.components.armor,normal * 2.0,0.000001)
	assert_eq(parts.fault_multiplier,2.0)
	var cache: Node3D = world.get_node("Salvage").items.ash_cache
	assert_eq(cache.state,"buried")
	hazards.advance(29.0)
	assert_false(cache.visible)
	hazards.advance(1.0)
	assert_eq(cache.state,"available")
	assert_true(cache.visible)
	drone.position = cache.position
	assert_true(world.get_node("Salvage").recover_nearest(drone))
	var schema = load("res://scripts/persistence/save_schema.gd")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(schema.capture(world)))
	assert_eq(schema.validate(saved),"")
	schema.restore(world,saved)
	assert_eq(cache.state,"carried")
	drone.deployed = false
	drone.position = Vector3(0,0.02,-4)
	var stock: int = world.get_node("Inventory").scrap
	assert_eq(world.get_node("Salvage").deliver(drone),1)
	hazards.advance(90.0)
	assert_eq(world.get_node("Salvage").deliver(drone),0)
	assert_eq(world.get_node("Inventory").scrap,stock + 24)
	assert_eq(cache.state,"delivered")
	weather.force("overcast")
	assert_eq(parts.wear_multiplier,1.0)
	assert_eq(parts.fault_multiplier,1.0)

func test_v16_save_migrates_buried_cache_without_recrediting_old_salvage() -> void:
	var schema = load("res://scripts/persistence/save_schema.gd")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(schema.capture(world)))
	saved.version = 16
	saved.salvage.pop_back()
	saved.erase("hazards")
	saved.salvage[0].state = "delivered"
	assert_eq(schema.validate(saved),"")
	schema.restore(world,saved)
	assert_eq(world.get_node("Salvage").items.scrap_01.state,"delivered")
	assert_eq(world.get_node("Salvage").items.ash_cache.state,"buried")

func test_rain_shorts_corrosion_hotspot_and_saved_hazard_cycles() -> void:
	var hazards: Node = world.get_node("EnvironmentHazards")
	hazards.set_physics_process(false)
	var drone: Node = world.get_node("Fleet").drone("mule_01")
	drone.deployed = true
	weather.force("rain")
	var armor: float = drone.components.armor
	hazards.advance(20.0)
	assert_almost_eq(armor - drone.components.armor,0.06,0.000001)
	assert_eq(hazards.contamination,99.0)
	assert_eq(hazards.radiation(hazards.HOTSPOT),0.99)
	assert_eq(hazards.radiation(Vector3.ZERO),0.0)
	var shorts := 0
	for i in 100:
		if hazards.sample_exposure(drone):
			shorts += 1
			assert_eq(drone.faults.cell,8.0)
	assert_between(shorts,1,30,"Seeded weather can short even pristine hardware")
	var schema = load("res://scripts/persistence/save_schema.gd")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(schema.capture(world)))
	assert_eq(schema.validate(saved),"")
	var expected: Dictionary = hazards.snapshot()
	schema.restore(world,saved)
	assert_eq(hazards.snapshot(),expected)
	hazards.advance(1980.0)
	assert_eq(hazards.contamination,0.0)
	assert_eq(hazards.radiation(hazards.HOTSPOT),0.0)
	weather.force("overcast")
	assert_false(hazards.sample_exposure(drone))
	saved.hazards.contamination = -1.0
	assert_ne(schema.validate(saved),"")

func test_rain_accelerates_real_suit_filter_and_v17_migrates() -> void:
	var human: Node = world.get_node("HumanSortie")
	human.set_physics_process(false)
	human.active = true
	world.get_node("Operator").position = Vector3(0,0.02,-20)
	weather.force("rain")
	human.advance(10.0)
	assert_eq(human.filter,280.0)
	human.active = false
	var schema = load("res://scripts/persistence/save_schema.gd")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(schema.capture(world)))
	saved.version = 17
	saved.hazards = {"ash_seconds":12.0}
	assert_eq(schema.validate(saved),"")
	schema.restore(world,saved)
	assert_eq(world.get_node("EnvironmentHazards").contamination,100.0)

func test_geothermal_removes_only_cold_and_retains_vent_risk_across_reload() -> void:
	var hazards: Node = world.get_node("EnvironmentHazards")
	hazards.set_physics_process(false)
	var drone: Node = world.get_node("Fleet").drone("mule_01")
	drone.deployed = true
	var power: Node = world.get_node("DronePower")
	drone.position = Vector3(9,0.02,-40)
	var outside: float = power.draw_kw(drone)
	drone.position = Vector3(9,0.02,-43)
	var inside: float = power.draw_kw(drone)
	assert_almost_eq(outside-inside,power.BALANCE.cold_kw / drone.component_efficiency("cell"),0.000001)
	assert_gt(inside,0.0,"Pocket removes cold, not motor or module draw")
	drone.position = Vector3(11,0.02,-48)
	hazards.advance(59.0)
	assert_eq(drone.terrain_multiplier,0.55)
	var armor: float = drone.components.armor
	var schema = load("res://scripts/persistence/save_schema.gd")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(schema.capture(world)))
	assert_eq(schema.validate(saved),"")
	schema.restore(world,saved)
	drone = world.get_node("Fleet").drone("mule_01")
	hazards.advance(1.0)
	assert_eq(drone.components.armor,armor - 5.0)
	assert_eq(drone.faults.joints,8.0)
	drone.position = Vector3(9,0.02,-40)
	drone.faults.clear()
	hazards.advance(0.1)
	assert_eq(drone.terrain_multiplier,1.0)
	assert_almost_eq(power.draw_kw(drone),outside,0.000001)
	assert_eq(hazards.cold_multiplier(Vector3.ZERO),1.0)
	saved.hazards.vent_cycles.mule_01 = -1.0
	assert_ne(schema.validate(saved),"")

func test_aurora_powers_preloaded_script_not_wireless_or_permanent_charge() -> void:
	var orders: Node = world.get_node("Orders")
	var drone: Node = world.get_node("Fleet").drone("mule_01")
	drone.deployed = true
	drone.position = Vector3(-3,0.02,-40)
	assert_true(orders.submit(drone.identity,[{"kind":"waypoint","x":-3.0,"north":55.0},{"kind":"scrap_collect"},{"kind":"battery_abort"}]))
	var control: Node = world.get_node("FleetControl")
	control.link.send(drone.identity,Vector2(0,-1),0.5)
	control.link.send_action(drone.identity,"ping",0.5)
	weather.force("aurora")
	assert_true(control.link.packets.is_empty())
	assert_true(control.link.actions.is_empty())
	drone.battery = 0.42
	world.get_node("DronePower").advance(10.0)
	assert_eq(drone.battery,0.42,"Ambient power supplies work without charging cells")
	drone.battery = 0.0
	var initial: float = drone.position.z
	assert_true(drone.has_power())
	assert_eq(world.get_node("Radio").quality(drone),0.0)
	assert_false(world.get_node("FleetControl").request_action("ping"))
	assert_false(orders.submit(drone.identity,[{"kind":"waypoint","x":0.0,"north":20.0}]))
	orders.stop(drone.identity)
	assert_eq(orders.programs[drone.identity].mode,"running","Wireless stop also needs a link")
	var unprogrammed: Node = world.get_node("Fleet").drone("hover_01")
	unprogrammed.deployed = true
	unprogrammed.battery = 0.0
	unprogrammed.position = Vector3(3,0.02,-40)
	assert_false(unprogrammed.has_power())
	await wait_physics_frames(120)
	assert_lt(drone.position.z,initial - 2.0)
	assert_eq(drone.battery,0.0)
	assert_eq(drone.cargo_kg,24.0,"Local pickup can work without a radio/cell")
	var schema = load("res://scripts/persistence/save_schema.gd")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(schema.capture(world)))
	assert_eq(schema.validate(saved),"")
	schema.restore(world,saved)
	drone = world.get_node("Fleet").drone("mule_01")
	assert_true(drone.has_power())
	var before: float = drone.position.z
	await wait_physics_frames(30)
	assert_lt(drone.position.z,before)
	weather.force("overcast")
	assert_false(drone.has_power())
	before = drone.position.z
	await wait_physics_frames(10)
	assert_eq(drone.position.z,before)
	assert_eq(drone.battery,0.0)
