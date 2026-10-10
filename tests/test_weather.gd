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
