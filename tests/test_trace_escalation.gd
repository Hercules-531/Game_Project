extends GutTest
const Schema = preload("res://scripts/persistence/save_schema.gd")
const Kit = preload("res://scripts/world/surface_kit.gd")
var world: Node
var sectors: Node
var events: Node

func before_each() -> void:
	InputContext.menu_locked = false
	InputContext.set_context(InputContext.Context.WALK)
	world = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(world)
	sectors = world.get_node("Trace")
	events = world.get_node("Emissions")
	await wait_physics_frames(2)
	sectors.set_physics_process(false)
	events.set_physics_process(false)
	sectors.tick = 0.0
	sectors.clock = 0.0

func after_each() -> void:
	InputContext.menu_locked = false
	InputContext.set_context(InputContext.Context.MENU)
	await wait_process_frames(2)

func test_real_emissions_shielding_silent_motion_and_sector_boundaries() -> void:
	var mule: Node = world.get_node("Fleet").drone("mule_01")
	mule.deployed = true
	mule.position = Vector3(-42,0.02,-40)
	mule.get_node("Controller").set_physics_process(false)
	await wait_physics_frames(2)
	sectors.advance(1)
	assert_gt(sectors.trace[0],1.0,"Deployment plus real cell heat")
	assert_eq(sectors.trace[1],0.0,"No trace from static warm vent")
	sectors.trace[0] = 0.0
	events.advance(2)
	assert_almost_eq(sectors.trace[0],0.16,0.000001)
	assert_true(mule.install("utility","signal_shield"))
	sectors.trace[0] = 0.0
	events.advance(2)
	assert_almost_eq(sectors.trace[0],0.032,0.000001,"Shield cuts radio trace and detection reach")
	assert_eq(events.pulses.back().reach,8.0)
	mule.velocity = Vector3(1,0,0)
	var loud: float = events.sound_reach(mule)
	mule.silent_running = true
	assert_almost_eq(events.sound_reach(mule),loud * 0.25,0.000001)
	sectors._pulse("sound",Vector3(0,0,-110.01),60,"fixture")
	assert_eq(sectors.trace[1],0.6)
	sectors._pulse("radio",Vector3(0,0,0),40,"fixture")
	assert_almost_eq(sectors.trace[0],0.032,0.000001,"Bunker emission does not raise surface trace")

func test_independent_nest_clocks_and_trace_recruit_real_patrols() -> void:
	var south: Node = sectors.nests[0]
	var north: Node = sectors.nests[5]
	south.remaining = 7.0
	north.remaining = 11.0
	sectors.advance(8)
	assert_eq(south.growth,1)
	assert_eq(north.growth,3)
	assert_almost_eq(north.remaining,3.0,0.000001)
	assert_gt(south.remaining,3500.0)
	sectors.advance(3)
	assert_eq(north.growth,4)
	assert_true(north.home_known,"A quiet nest can eventually threaten home")
	sectors.trace[0] = 80.1
	south.growth = 2
	south.reinforce_remaining = 1.0
	sectors.advance(1)
	assert_true(south.home_known)
	assert_eq(south.active_count(),4)
	var patrol: CharacterBody3D = world.get_node("Threats").actors[south.population[0]]
	assert_eq(patrol.home,Vector3(0,0.02,-18))
	assert_eq(patrol.shelter,south.position + Vector3(-5,0,0))
	var start := patrol.position
	await wait_physics_frames(90)
	assert_gt(patrol.position.distance_to(start),0.5,"Recruitment creates a real walking body")

func test_clearing_stops_growth_and_dead_patrols_do_not_duplicate() -> void:
	var nest: Node = sectors.nests[0]
	nest.growth = 2
	nest.advance(60,0)
	assert_eq(nest.active_count(),2)
	var first: String = nest.population[0]
	world.get_node("Threats").actors[first].apply_damage(1000)
	nest.advance(60,0)
	assert_eq(nest.active_count(),2)
	assert_false(first in nest.population)
	assert_false(world.get_node("Threats").actors.has(first))
	assert_eq(nest.serial,3)
	nest.apply_damage(1000)
	var remaining: float = nest.remaining
	nest.advance(10000,100)
	assert_eq(nest.state,"cleared")
	assert_eq(nest.remaining,remaining)
	assert_eq(nest.serial,3,"Cleared nest never recruits again")
	assert_eq(nest.active_count(),2,"Clearing does not erase surviving patrols")

func test_optical_survey_is_local_occluded_and_stale_when_link_lost() -> void:
	var nest: Node = sectors.nests[0]
	var mule: Node = world.get_node("Fleet").drone("mule_01")
	mule.deployed = true
	mule.position = nest.position + Vector3(4,0,4)
	await wait_physics_frames(2)
	assert_false(nest.survey(mule,10),"Blind sonar/IR cannot classify the colony")
	var hover: Node = world.get_node("Fleet").drone("hover_01")
	hover.deployed = true
	hover.position = nest.position + Vector3(0,0,7)
	await wait_physics_frames(2)
	assert_true(nest.survey(hover,10))
	assert_eq(nest.surveyed_at,10.0)
	hover.rotation.y = PI
	assert_false(nest.survey(hover,10.5),"Camera facing away does not create survey data")
	hover.rotation.y = 0.0
	var known: Dictionary = nest.intel.duplicate()
	world.get_node("Radio").drops[hover.identity] = 2.0
	nest.growth = 3
	assert_false(nest.survey(hover,11))
	assert_eq(nest.intel,known,"No remote fresh population data during loss")
	world.get_node("Radio").drops.clear()
	var wall := Kit.box(world.get_node("Surface"),"SurveyWall",Vector3(5,3,0.3),nest.position + Vector3(0,1.5,3))
	await wait_physics_frames(2)
	assert_false(nest.survey(hover,12))
	wall.queue_free()

func test_trace_nest_clocks_patrols_and_intel_survive_reload() -> void:
	sectors.trace[0] = 65.0
	sectors.nests[0].growth = 2
	sectors.advance(60.25)
	var saved := JSON.parse_string(JSON.stringify(Schema.capture(world))) as Dictionary
	assert_eq(Schema.validate(saved),"")
	var serial: int = sectors.nests[0].serial
	var population: Array = sectors.nests[0].population.duplicate()
	Schema.restore(world,saved)
	assert_eq(sectors.tick,0.25)
	assert_almost_eq(sectors.trace[0],64.1,0.000001)
	assert_eq(sectors.nests[0].serial,serial)
	assert_eq(sectors.nests[0].population,population)
	assert_eq(world.get_node("Threats").actors.size(),saved.threats.size())
	var bad := saved.duplicate(true)
	bad.trace.nests[0].population[0] = "nest_0_patrol_ghost"
	assert_ne(Schema.validate(bad),"")
	bad = saved.duplicate(true)
	bad.trace.nests[1].remaining = -1.0
	assert_ne(Schema.validate(bad),"")
	bad = saved.duplicate(true)
	bad.trace.trace[0] = NAN
	assert_ne(Schema.validate(bad),"")
	saved.version = 21
	saved.erase("trace")
	assert_eq(Schema.validate(saved),"","Older saves migrate to initial nest state")

func test_trace_panel_hides_unknown_nests_and_shield_is_paid_hardware() -> void:
	var panel: Node = world.get_node("TracePanel")
	panel.open()
	assert_true(panel.readings.text.contains("No linked optical survey."))
	assert_false(panel.readings.text.contains("growth"),"Unknown nest clocks are not shown")
	await wait_process_frames(2)
	assert_lte(panel.panel.get_combined_minimum_size().y,480.0,"All surveys and exit fit the internal screen")
	var back: Button = panel.panel.find_children("*","Button",true,false)[0]
	back.pressed.emit()
	assert_false(panel.panel.visible)
	assert_true(world.get_node("FleetPanel").panel.visible)
	var stock: Node = world.get_node("Inventory")
	var queue: Node = world.get_node("Fabrication")
	assert_true(queue.start("signal_shield"))
	assert_eq(stock.scrap,62)
	world.get_node("LifeSupport").supplied_fraction = 1.0
	queue.advance(60)
	assert_eq(stock.parts.back().id,"signal_shield")
	assert_eq(stock.parts.back().condition,100.0)
