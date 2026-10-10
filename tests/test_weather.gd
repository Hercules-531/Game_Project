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
