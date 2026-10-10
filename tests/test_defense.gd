extends GutTest
const Schema = preload("res://scripts/persistence/save_schema.gd")
const Scene = preload("res://scenes/drones/drone.tscn")
var session: Node
var w: Node
var defense: Node
var life: Node
var mule: Node
func before_each() -> void:
	InputContext.menu_locked = false
	InputContext.set_context(InputContext.Context.WALK)
	session = load("res://scenes/ui/main_menu.tscn").instantiate()
	session.save_path = "user://tests/defense_%d.json" % Time.get_ticks_usec()
	add_child_autofree(session)
	session.new_game()
	w = session.world
	defense = w.get_node("Defense")
	life = w.get_node("LifeSupport")
	mule = w.get_node("Fleet").drone("mule_01")
	for node in [defense,life,w.get_node("Territory"),w.get_node("DronePower")]: node.set_physics_process(false)
	w.get_node("Radio").dropout_chance = 0.0
	for actor in w.get_node("Threats").actors.values(): actor.set_physics_process(false)
	await wait_physics_frames(2)
func after_each() -> void:
	InputContext.menu_locked = false
	get_tree().paused = false
	InputContext.set_context(InputContext.Context.WALK)
	await wait_process_frames(2)
func gun() -> void:
	mule.remove_module("tool")
	assert_true(mule.install("tool","sentry_mount"))
	assert_true(defense.reload_ammo(mule.identity))
	mule.deployed = true
	mule.position = Vector3(20,0.02,-40)
	await wait_physics_frames(2)
func target(at: Vector3) -> Node:
	var actor: Node = w.get_node("Threats").actors.approach_scout
	actor.position = at
	await wait_physics_frames(2)
	return actor
func test_paid_rounds_latency_damage_cooldown_and_save_conserve() -> void:
	await gun()
	var actor: Node = await target(Vector3(20,0.02,-46))
	assert_eq(w.get_node("Inventory").scrap,70)
	assert_almost_eq(mule.cargo_kg,0.4,0.0000001)
	var before: float = mule.battery
	assert_true(defense.fire(mule.identity,actor.identity))
	assert_eq(actor.integrity,100.0,"Transmission is not immediate damage")
	assert_false(defense.fire(mule.identity,actor.identity),"Only one pending order")
	defense.advance(0.05)
	assert_eq(actor.integrity,100.0)
	var paid := JSON.parse_string(JSON.stringify(Schema.capture(w))) as Dictionary
	assert_eq(Schema.validate(paid),"")
	Schema.restore(w,paid)
	mule = w.get_node("Fleet").drone("mule_01")
	actor = w.get_node("Threats").actors.approach_scout
	actor.set_physics_process(false)
	await wait_physics_frames(2)
	defense.advance(1)
	assert_eq(actor.integrity,52.0,"Fresh module gets its +20% efficiency")
	assert_eq(int(defense.ammo[mule.identity]),19)
	assert_almost_eq(mule.cargo_kg,0.38,0.0000001)
	assert_almost_eq(mule.battery,before-0.002,0.0000001)
	assert_false(defense.fire(mule.identity,actor.identity),"Cooldown blocks rapid repeat")
	defense.advance(2)
	assert_true(defense.fire(mule.identity,actor.identity))
	defense.advance(1)
	defense.advance(2)
	assert_true(defense.fire(mule.identity,actor.identity))
	defense.advance(1)
	assert_eq(actor.integrity,0.0)
	assert_eq(int(defense.ammo[mule.identity]),17)
	assert_false(defense.fire(mule.identity,actor.identity),"Cannot spend rounds on a corpse")
	assert_eq(w.get_node("Inventory").scrap,70)
	assert_eq(Schema.validate(Schema.capture(w)),"")
func test_unseen_wall_and_lost_link_prevent_free_fire() -> void:
	await gun()
	var actor: Node = await target(Vector3(20,0.02,-46))
	mule.rotation.y = PI
	assert_false(defense.observed(mule,actor))
	assert_true(defense.contacts(mule.identity).is_empty())
	assert_false(defense.fire(mule.identity,actor.identity))
	mule.rotation.y = 0
	var wall := preload("res://scripts/world/surface_kit.gd").box(w.get_node("Surface"),"FireBlock",Vector3(4,3,0.3),Vector3(20,1.5,-43))
	await wait_physics_frames(2)
	assert_false(defense.fire(mule.identity,actor.identity))
	wall.queue_free()
	await wait_physics_frames(2)
	assert_true(defense.fire(mule.identity,actor.identity))
	w.get_node("Radio").drops[mule.identity] = 2
	defense.advance(3)
	assert_eq(actor.integrity,100.0)
	assert_eq(int(defense.ammo[mule.identity]),20,"Lost packet spends neither shot nor mass")
	assert_almost_eq(mule.cargo_kg,0.4,0.0000001)
	assert_false(defense.reload_ammo(mule.identity),"Cannot buy remote ammunition")
	w.get_node("Radio").drops.clear()
	mule.remove_module("sensor_a")
	mule.remove_module("sensor_b")
	assert_false(defense.fire(mule.identity,actor.identity),"A gun does not grant vision")
func test_carried_trap_is_once_only_saved_and_blocked_by_wall() -> void:
	assert_true(mule.install("utility","trap_layer"))
	assert_true(defense.load_trap(mule.identity))
	assert_eq(mule.cargo_kg,1.0)
	assert_eq(w.get_node("Inventory").scrap,74)
	mule.deployed = true
	mule.position = Vector3(20,0.02,-40)
	await wait_physics_frames(2)
	assert_true(defense.lay_trap(mule.identity))
	assert_eq(mule.cargo_kg,0.0)
	assert_false(defense.lay_trap(mule.identity))
	var actor: Node = await target(Vector3(20,0.02,-43.5))
	var wall := preload("res://scripts/world/surface_kit.gd").box(w.get_node("Surface"),"TrapBlock",Vector3(4,2,0.2),Vector3(20,1,-42.7))
	await wait_physics_frames(2)
	defense.advance(1)
	assert_false(defense.traps[0].spent)
	assert_eq(actor.integrity,100.0)
	wall.queue_free()
	await wait_physics_frames(2)
	defense.advance(1)
	assert_eq(actor.integrity,0.0)
	assert_true(defense.traps[0].spent)
	var state := JSON.parse_string(JSON.stringify(Schema.capture(w))) as Dictionary
	assert_eq(Schema.validate(state),"")
	Schema.restore(w,state)
	var next: Node = w.get_node("Threats").spawn("trap_survivor",Vector3(20,0.02,-42.5),Vector3(20,0.02,-50))
	next.set_physics_process(false)
	defense.advance(1)
	assert_eq(next.integrity,100.0,"Spent trap cannot fire again after reload")
func perimeter_fixture(band: int) -> void:
	w.get_node("Territory").sites[band].held = true
	w.get_node("Territory").sites[band].perimeter = true
	if band>0:
		w.get_node("Territory").sites[band].pylon = true
		w.get_node("Territory")._refresh_visual(band)
	defense.install_perimeter(band)
	await wait_physics_frames(2)
func test_fence_paid_power_blackout_physical_destruction_and_field_bank() -> void:
	await perimeter_fixture(0)
	var actor: Node = await target(Vector3(0,0.02,-30.5))
	assert_true(defense.set_fence(0,true))
	assert_eq(life.defense_load_kw,2.0)
	life.generator_on = false
	life.battery = 0
	life.advance(1)
	assert_eq(actor.integrity,100.0,"Blackout fences cannot deal damage")
	assert_false(defense.fence_live(0))
	life.battery = life.load_kw()/3600.0*0.5
	life.advance(1)
	assert_almost_eq(actor.integrity,80.0,0.000001,"Only half the contact energy was paid")
	assert_true(actor.test_move(actor.global_transform,Vector3(0,0,2)),"Actual fence blocks mutant")
	assert_true(defense.attack_near(actor,200))
	assert_eq(defense.perimeters["0"].health[0],0.0)
	await wait_physics_frames(2)
	assert_false(actor.test_move(actor.global_transform,Vector3(0,0,2)),"Destroyed section no longer blocks")
	await perimeter_fixture(1)
	actor.position = defense.center(1)+Vector3(0,0,-8.5)
	await wait_physics_frames(2)
	defense.perimeters["1"].on = true
	w.get_node("Territory").sites[1].battery = 2.0/3600.0*0.25
	var before: float = actor.integrity
	defense.advance(1)
	assert_almost_eq(actor.integrity,before-10,0.000001)
	assert_eq(w.get_node("Territory").sites[1].battery,0.0)
	defense.advance(1)
	assert_almost_eq(actor.integrity,before-10,0.000001)
func heavy() -> Node:
	var g: Node = Scene.instantiate()
	g.identity = "fence_builder"
	g.hull_id = "goliath"
	g.battery = 0.2
	g.deployed = true
	g.position = Vector3(-4,0.02,-17)
	assert_true(g.install("tool","prefab_winch"))
	w.get_node("Fleet").add_child(g)
	var t: Node = Scene.instantiate()
	t.identity = "fence_tender"
	t.hull_id = "tender"
	t.battery = 12
	t.deployed = true
	t.position = Vector3(-4,0.02,-20)
	assert_true(t.install("utility","power_coupler"))
	w.get_node("Fleet").add_child(t)
	await wait_physics_frames(2)
	assert_true(w.get_node("PowerTether").attach(g.identity,t.identity))
	return g
func test_home_prefab_build_and_paid_repair_survive_save() -> void:
	var g: Node = await heavy()
	for id in ["recovery","network","heavy","defense"]:
		w.get_node("Research").completed.append(id)
		w.get_node("Research").archives[id] = {"state":"delivered","carrier":""}
	var net: Node = w.get_node("Territory")
	assert_true(net.load_prefab(g.identity,"perimeter"))
	assert_eq(g.cargo_kg,800.0)
	assert_eq(w.get_node("Inventory").scrap,20)
	assert_true(net.construct(g.identity,0))
	w.get_node("PowerTether").advance(240)
	net.advance(240)
	assert_true(net.sites[0].perimeter)
	assert_true(defense.perimeters.has("0"))
	assert_eq(g.cargo_kg,0.0)
	defense.damage_section(0,0,150)
	assert_true(defense.repair_perimeter(g.identity,0))
	assert_eq(w.get_node("Inventory").scrap,5)
	assert_eq(defense.perimeters["0"].health[0],200.0)
	assert_false(defense.repair_perimeter(g.identity,0))
	defense.damage_section(0,1,30)
	defense.set_fence(0,true)
	var state := JSON.parse_string(JSON.stringify(Schema.capture(w))) as Dictionary
	assert_eq(Schema.validate(state),"")
	Schema.restore(w,state)
	assert_eq(defense.perimeters["0"].health[1],170.0)
	assert_eq(life.defense_load_kw,2.0)
	assert_eq(w.get_node("Inventory").scrap,5)
func test_floodlight_decoy_and_panel_sensor_limits() -> void:
	assert_true(mule.install("utility","floodlight"))
	mule.deployed = true
	mule.position = Vector3(20,0.02,-40)
	await wait_physics_frames(2)
	defense.advance(0.1)
	var beam: Node = mule.get_node("Visual").find_children("FloodBeam","SpotLight3D",true,false)[0]
	assert_true(beam.visible)
	var actor: Node = await target(Vector3(20,0.02,-46))
	var senses = preload("res://scripts/threats/mutant_senses.gd")
	assert_eq(senses.strongest(actor,w,w.get_node("Emissions").sources()).kind,"light")
	actor.position = Vector3(20,0.02,-34)
	await wait_physics_frames(2)
	assert_ne(senses.strongest(actor,w,w.get_node("Emissions").sources()).get("kind",""),"light","The rear of a spot beam does not illuminate a mutant")
	mule.silent_running = true
	defense.advance(0.1)
	assert_false(beam.visible)
	mule.remove_module("utility")
	assert_true(mule.install("utility","noise_decoy"))
	mule.silent_running = false
	assert_true(defense.toggle_decoy(mule.identity))
	var trace: float = w.get_node("Trace").trace[0]
	defense.advance(2)
	assert_gt(w.get_node("Trace").trace[0],trace)
	mule.silent_running = true
	w.get_node("Emissions").pulses.clear()
	defense.advance(2)
	assert_true(w.get_node("Emissions").pulses.is_empty())
	var panel: Node = w.get_node("DefensePanel")
	panel.open()
	await wait_process_frames(2)
	assert_lte(panel.panel.get_combined_minimum_size().x,640.0)
	assert_lte(panel.panel.get_combined_minimum_size().y,480.0)
	var buttons: Array = panel.panel.find_children("*","Button",true,false)
	assert_lte(buttons.back().global_position.y+buttons.back().size.y,480.0)
	assert_false(panel.readings.text.contains("integrity"),"No unobserved enemy health")
	buttons.back().pressed.emit()
	assert_true(w.get_node("FleetPanel").panel.visible)
func test_migration_and_invalid_ammo_cargo_or_unbuilt_fence_rejected() -> void:
	var old := Schema.capture(w)
	old.version = 24
	old.erase("defense")
	for site in old.territory.sites: site.erase("perimeter")
	assert_eq(Schema.validate(old),"")
	Schema.restore(w,old)
	assert_true(defense.ammo.is_empty())
	assert_false(w.get_node("Territory").sites[0].perimeter)
	var bad := Schema.capture(w)
	bad.defense.ammo.mule_01 = 1
	assert_ne(Schema.validate(bad),"","Saved rounds require their physical cargo mass")
	bad = Schema.capture(w)
	bad.defense.perimeters["0"] = {"health":[200,200,200,200,200],"on":true}
	assert_ne(Schema.validate(bad),"")
