extends GutTest
const Schema = preload("res://scripts/persistence/save_schema.gd")
var world: Node
var research: Node
var life: Node
var stock: Node
var session: Node

func before_each() -> void:
	InputContext.menu_locked = false
	InputContext.set_context(InputContext.Context.WALK)
	process_mode = Node.PROCESS_MODE_ALWAYS
	session = load("res://scenes/ui/main_menu.tscn").instantiate()
	session.save_path = "user://tests/research_%d.json" % Time.get_ticks_usec()
	add_child_autofree(session)
	session.new_game()
	world = session.world
	research = world.get_node("Research")
	life = world.get_node("LifeSupport")
	stock = world.get_node("Inventory")
	life.set_physics_process(false)
	await wait_physics_frames(2)

func after_each() -> void:
	InputContext.menu_locked = false
	get_tree().paused = false
	InputContext.set_context(InputContext.Context.WALK)
	await wait_process_frames(2)

func retrieve(id: String) -> Node:
	var drone: Node = world.get_node("Fleet").drone("mule_01")
	drone.deployed = true
	drone.position = research.TREE.topics[id].at + Vector3(0,0,2.2)
	await wait_physics_frames(2)
	assert_true(research.recover_nearest(drone))
	return drone

func unload(drone: Node) -> void:
	drone.position = Vector3(-2,0.02,-14)
	await wait_physics_frames(2)
	assert_true(world.get_node("FleetControl").request_machine_transfer(drone,false))
	world.get_node("FleetControl").advance_transfer(8)
	assert_false(drone.deployed)

func test_archive_is_real_paid_cargo_and_loader_unloads_once() -> void:
	assert_false(research.start("recovery"))
	assert_false(world.get_node("Fabrication").start("tracked_frame"))
	assert_eq(stock.scrap,80,"Locked recipe costs nothing")
	var drone: Node = await retrieve("recovery")
	assert_eq(drone.cargo_kg,1.0)
	assert_eq(research.archives.recovery.state,"carried")
	assert_false(research.start("recovery"),"Carry is not knowledge")
	assert_false(research.recover_nearest(drone))
	assert_eq(Schema.validate(Schema.capture(world)),"")
	await unload(drone)
	assert_eq(drone.cargo_kg,0.0)
	assert_eq(research.archives.recovery.state,"delivered")
	assert_eq(research.deliver(drone),0,"Repeated unload does not duplicate knowledge")
	assert_true(research.start("recovery"))
	assert_eq(stock.scrap,60)
	assert_false(research.start("recovery"))
	life.advance(180)
	assert_true(research.has_technology("recovery"))
	assert_true(research.permits_recipe("tracked_frame"))
	assert_false(research.permits_recipe("goliath_frame"))
	assert_eq(life.research_load_kw,0.0)
	assert_false(research.start("recovery"),"Completed research cannot be bought twice")
	assert_eq(stock.scrap,60)

func test_grid_blackout_partial_supply_and_prerequisites_are_real() -> void:
	var drone: Node = await retrieve("network")
	await unload(drone)
	assert_false(research.start("network"))
	assert_eq(stock.scrap,80)
	drone = await retrieve("recovery")
	await unload(drone)
	var baseline_draw: float = life.load_kw()
	assert_true(research.start("recovery"))
	assert_almost_eq(life.load_kw() - baseline_draw,0.35,0.000001,"Research adds paid demand alongside the home charger")
	life.generator_on = false
	life.battery = 0.0
	life.advance(30)
	assert_eq(research.job.remaining,180.0,"Blackout provides no research time")
	life.battery = life.load_kw() / 3600.0 * 0.5
	life.advance(1)
	assert_almost_eq(research.job.remaining,179.5,0.000001,"Half-paid second gives half progress")
	life.generator_on = true
	life.advance(180)
	assert_true(research.has_technology("recovery"))
	assert_true(research.start("network"))
	assert_eq(stock.scrap,36)
	life.advance(240)
	assert_true(research.has_technology("network"))
	assert_false(research.has_technology("defense"))

func test_carried_archive_and_paid_research_survive_reload_without_refund() -> void:
	var drone: Node = await retrieve("recovery")
	var carried := JSON.parse_string(JSON.stringify(Schema.capture(world))) as Dictionary
	assert_eq(Schema.validate(carried),"")
	Schema.restore(world,carried)
	drone = world.get_node("Fleet").drone("mule_01")
	assert_eq(drone.cargo_kg,1.0)
	assert_eq(research.archives.recovery.carrier,drone.identity)
	await unload(drone)
	assert_true(research.start("recovery"))
	life.advance(45)
	var paid := JSON.parse_string(JSON.stringify(Schema.capture(world))) as Dictionary
	Schema.restore(world,paid)
	assert_eq(research.job.remaining,135.0)
	assert_eq(stock.scrap,60)
	assert_eq(life.research_load_kw,0.35)
	life.advance(135)
	assert_true(research.has_technology("recovery"))
	assert_eq(stock.scrap,60)
	var malformed := paid.duplicate(true)
	malformed.research.job.topic = "network"
	assert_ne(Schema.validate(malformed),"")
	malformed = carried.duplicate(true)
	malformed.fleet[0].cargo_kg = 0.0
	assert_ne(Schema.validate(malformed),"","Archive carrier mass is conserved")

func test_old_save_retains_existing_recipes_but_not_new_technologies() -> void:
	var data := Schema.capture(world)
	data.version = 22
	data.erase("research")
	data.fabrication = {"recipe":"goliath_frame","remaining":100.0}
	assert_eq(Schema.validate(data),"")
	Schema.restore(world,data)
	assert_true(research.permits_recipe("goliath_frame"))
	assert_true(research.permits_recipe("drill"))
	assert_false(research.has_technology("network"))
	assert_false(research.has_technology("optics"))
	assert_eq(world.get_node("Fabrication").job.remaining,100.0)
	assert_eq(stock.scrap,80)
	assert_eq(Schema.validate(Schema.capture(world)),"")

func test_research_panel_navigation_and_pause_hold_work() -> void:
	var drone: Node = await retrieve("recovery")
	await unload(drone)
	assert_true(research.start("recovery"))
	var panel: Node = world.get_node("ResearchPanel")
	panel.open()
	assert_true(panel.readings.text.contains("ARCHIVE / DELIVERED"))
	assert_false(panel.readings.text.contains("-72"),"Panel does not reveal undiscovered world coordinates")
	await wait_process_frames(2)
	assert_lte(panel.panel.get_combined_minimum_size().y,480.0)
	var buttons: Array = panel.panel.find_children("*","Button",true,false)
	buttons.back().pressed.emit()
	assert_true(world.get_node("WorkshopPanel").panel.visible)
	life.set_physics_process(true)
	InputContext.set_context(InputContext.Context.MENU)
	var remaining: float = research.job.remaining
	await wait_process_frames(5)
	assert_eq(research.job.remaining,remaining)
	assert_true(get_tree().paused)
	session.resume()
	await wait_physics_frames(65)
	assert_lt(research.job.remaining,remaining,"Resume advances real paid research")
