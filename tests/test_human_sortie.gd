extends GutTest
var world: Node
var sortie: Node
const Schema = preload("res://scripts/persistence/save_schema.gd")
func before_each() -> void:
	world = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(world)
	sortie = world.get_node("HumanSortie")
	await wait_physics_frames(2)
func after_each() -> void:
	Input.action_release("move_forward")
	InputContext.menu_locked = false
	InputContext.set_context(InputContext.Context.MENU)
	await wait_process_frames(2)
func strand() -> void:
	for drone in world.get_node("Fleet").get_children():
		drone.deployed = true
		drone.position = Vector3(-2 if drone.hull_id == "mule" else 2,0.02,-25)
		drone.battery = 0.0

func test_trigger_paid_suit_movement_escort_and_return() -> void:
	assert_false(sortie.suit_up(),"Working fleet does not unlock sortie")
	strand()
	assert_true(sortie.fleet_unavailable())
	var life: Node = world.get_node("LifeSupport")
	var stock: Node = world.get_node("Inventory")
	life.set_physics_process(false)
	var energy: float = life.battery
	assert_true(sortie.suit_up())
	assert_eq(stock.scrap,75)
	assert_almost_eq(life.battery,energy - 0.30,0.000001)
	assert_almost_eq(life.oxygen,98.0,0.000001)
	assert_true(world.get_node("Bunker/Airlock").outer_authorized)
	assert_false(sortie.suit_up(),"No double payment")
	var op: CharacterBody3D = world.get_node("Operator")
	op.position = Vector3(0,0.02,-15)
	InputContext.set_context(InputContext.Context.WALK)
	Input.action_press("move_forward")
	await wait_physics_frames(60)
	Input.action_release("move_forward")
	assert_between(-op.position.z,16.0,16.3,"Suit movement is slow")
	assert_lt(sortie.oxygen,480.0)
	assert_lt(sortie.filter,300.0)
	var mule: Node = world.get_node("Fleet").drone("mule_01")
	op.position = mule.position + Vector3(0,0,2.5)
	await wait_physics_frames(2)
	assert_true(sortie.revive(mule))
	assert_almost_eq(sortie.jumper,0.05,0.000001)
	assert_almost_eq(mule.battery,0.225,0.002)
	assert_false(sortie.revive(mule),"Cannot recharge a live escort")
	var before: Vector3 = mule.position
	op.position.z += 4
	await wait_physics_frames(160)
	assert_gt(mule.position.distance_to(before),0.2,"Escort actually drives")
	assert_false(sortie.finish(),"Cannot stow outside")
	op.position = Vector3(0,0.02,-5)
	mule.position = Vector3(-2,0.02,-14)
	assert_true(sortie.finish())
	assert_eq(op.walk_speed,2.6)
	assert_false(world.get_node("Bunker/Airlock").outer_authorized)
	assert_eq(sortie.escort_id,"")

func test_save_mid_sortie_preserves_gauges_and_dead_state_never_overwrites_slot() -> void:
	strand()
	sortie.suit_up()
	world.get_node("Operator").position = Vector3(0,0.02,-20)
	sortie.advance(50)
	var data: Dictionary = JSON.parse_string(JSON.stringify(Schema.capture(world)))
	assert_eq(Schema.validate(data),"")
	Schema.restore(world,data)
	assert_eq(sortie.oxygen,430.0)
	assert_eq(sortie.filter,250.0)
	assert_eq(world.get_node("Operator").walk_speed,1.15)
	watch_signals(sortie)
	sortie.advance(250)
	assert_true(sortie.dead)
	assert_signal_emit_count(sortie,"died",1)
	sortie.advance(100)
	assert_signal_emit_count(sortie,"died",1)
	var session = load("res://scenes/ui/main_menu.tscn").instantiate()
	session.save_path = "user://tests/human_sortie.json"
	add_child_autofree(session)
	session.new_game()
	assert_true(session.save_current())
	var committed := FileAccess.get_file_as_string(session.save_path)
	var human: Node = session.world.get_node("HumanSortie")
	human.active = true
	human.kill("Suit filter failed.")
	assert_true(get_tree().paused)
	assert_true(InputContext.menu_locked)
	assert_eq(session.menu.heading.text,"BUNKER QUIET")
	assert_false(session.save_current())
	assert_eq(FileAccess.get_file_as_string(session.save_path),committed)
	assert_true(session.continue_game())
	assert_false(session.world.get_node("HumanSortie").dead)

func test_wall_blocks_jumper_and_invalid_saved_escort_rejected() -> void:
	strand()
	sortie.suit_up()
	var mule: Node = world.get_node("Fleet").drone("mule_01")
	world.get_node("Operator").position = mule.position + Vector3(0,0,2.5)
	var wall = load("res://scripts/world/surface_kit.gd").box(world.get_node("Surface"),"JumperWall",Vector3(4,2,0.3),mule.position + Vector3(0,1,1.3))
	await wait_physics_frames(2)
	assert_false(sortie.revive(mule))
	assert_eq(sortie.jumper,0.30)
	var data: Dictionary = Schema.capture(world)
	data.human_sortie.escort = "ghost"
	assert_ne(Schema.validate(data),"")
	data.human_sortie.escort = ""
	data.human_sortie.oxygen = -1.0
	assert_ne(Schema.validate(data),"")
	wall.queue_free()
