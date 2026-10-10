extends GutTest

const Schema = preload("res://scripts/persistence/save_schema.gd")
var session: Node
var world: Node
var inventory: Node
var workshop: Node
var queue: Node


func before_each() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	session = load("res://scenes/ui/main_menu.tscn").instantiate()
	session.save_path = "user://tests/workshop_%d/save.json" % Time.get_ticks_usec()
	add_child_autofree(session)
	session.new_game()
	world = session.world
	inventory = world.get_node("Inventory")
	workshop = world.get_node("Workshop")
	queue = world.get_node("Fabrication")
	queue.set_physics_process(false)
	await wait_physics_frames(3)


func after_each() -> void:
	get_tree().paused = false
	await wait_process_frames(2)
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(session.save_path + suffix):
			DirAccess.remove_absolute(session.save_path + suffix)
	DirAccess.remove_absolute(session.save_path.get_base_dir())


func test_fitting_removal_and_repair_conserve_stock_and_condition() -> void:
	var mule: Node = world.get_node("Fleet").drone("mule_01")
	var count: int = inventory.parts.size()
	assert_false(workshop.fit("mule_01","tool",1),"Occupied/wrong-category socket consumes nothing")
	assert_eq(inventory.parts.size(),count)
	assert_true(workshop.remove("mule_01","sensor_b"))
	assert_eq(inventory.parts.size(),count + 1)
	assert_true(workshop.fit("mule_01","sensor_b",2))
	assert_eq(mule.condition.sensor_b,85.0)
	assert_eq(inventory.parts.size(),count)
	assert_false(workshop.fit("mule_01","sensor_b",2),"Used stock item cannot fit twice")
	var scrap: int = inventory.scrap
	assert_true(workshop.repair("mule_01","sensor_b"))
	assert_eq(inventory.scrap,scrap - 3)
	assert_eq(mule.condition.sensor_b,100.0)
	assert_false(workshop.repair("mule_01","sensor_b"),"No charge for a full-condition part")
	assert_eq(inventory.scrap,scrap - 3)
	await wait_process_frames(2)


func test_fabrication_debits_once_and_completes_once() -> void:
	var count: int = inventory.parts.size()
	assert_false(queue.start("ccd"),"First camera must be scavenged")
	assert_eq(inventory.scrap,80)
	assert_true(queue.start("retrace"))
	assert_eq(inventory.scrap,68)
	assert_false(queue.start("sonar"),"Busy queue rejects a second job without debit")
	assert_eq(inventory.scrap,68)
	assert_eq(world.get_node("LifeSupport").external_load_kw,0.6)
	queue.advance(29.0)
	assert_eq(inventory.parts.size(),count)
	queue.advance(1.0)
	assert_eq(inventory.parts.size(),count + 1)
	assert_eq(inventory.parts.back().id,"retrace")
	assert_eq(world.get_node("LifeSupport").external_load_kw,0.0)
	queue.advance(100.0)
	assert_eq(inventory.parts.size(),count + 1)
	inventory.scrap = 0
	assert_false(queue.start("sonar"))
	assert_true(queue.job.is_empty())


func test_save_mid_job_preserves_payment_and_remaining_time() -> void:
	queue.start("sonar")
	queue.advance(6.5)
	var scrap: int = inventory.scrap
	var count: int = inventory.parts.size()
	assert_true(session.save_current())
	assert_true(session.continue_game())
	InputContext.set_context(InputContext.Context.MENU)
	var restored: Node = session.world.get_node("Fabrication")
	restored.set_physics_process(false)
	assert_almost_eq(restored.job.remaining,8.5,0.000001)
	assert_eq(session.world.get_node("Inventory").scrap,scrap)
	assert_eq(session.world.get_node("LifeSupport").external_load_kw,0.6)
	restored.advance(8.5)
	assert_eq(session.world.get_node("Inventory").parts.size(),count + 1)
	assert_eq(session.world.get_node("Inventory").scrap,scrap)


func test_blackout_holds_fabrication_and_pause_holds_queue() -> void:
	queue.start("sonar")
	world.get_node("LifeSupport").supplied_fraction = 0.0
	queue.advance(5.0)
	assert_eq(queue.job.remaining,15.0)
	world.get_node("LifeSupport").supplied_fraction = 1.0
	queue.advance(5.0)
	assert_eq(queue.job.remaining,10.0)
	queue.set_physics_process(true)
	InputContext.set_context(InputContext.Context.MENU)
	await wait_process_frames(5)
	assert_eq(queue.job.remaining,10.0)


func test_hull_assembly_and_supplies_do_not_duplicate_resources() -> void:
	assert_true(queue.start("mule_frame"))
	queue.advance(120.0)
	assert_eq(inventory.hulls.mule,1)
	assert_true(workshop.assemble("mule"),"Clear workshop bay accepts completed hull")
	assert_eq(world.get_node("Fleet").get_child_count(),3)
	assert_eq(inventory.hulls.mule,0)
	assert_false(workshop.assemble("mule"))
	var life: Node = world.get_node("LifeSupport")
	life.set_physics_process(false)
	life.fuel = 118.0
	life.rations = 7.5
	assert_true(workshop.resupply("fuel"))
	assert_eq(life.fuel,120.0)
	assert_eq(inventory.fuel,58.0)
	assert_true(workshop.resupply("rations"))
	assert_eq(life.rations,8.0)
	assert_eq(inventory.rations,3.5)
	assert_false(workshop.resupply("fuel"))
	assert_false(workshop.resupply("rations"))


func test_workbench_opens_panel_and_invalid_save_state_is_rejected() -> void:
	world.get_node("Bunker/WorkshopBench/Interaction").use()
	assert_true(world.get_node("WorkshopPanel").panel.visible)
	assert_eq(InputContext.active,InputContext.Context.TERMINAL)
	var data: Dictionary = Schema.capture(world)
	assert_eq(Schema.validate(JSON.parse_string(JSON.stringify(data))),"")
	data.inventory.parts.append(data.inventory.parts[0])
	assert_eq(Schema.validate(data),"Invalid workshop state.")
	data = Schema.capture(world)
	data.fabrication = {"recipe":"free_camera","remaining":1.0}
	assert_eq(Schema.validate(data),"Invalid workshop state.")
