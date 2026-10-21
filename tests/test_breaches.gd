extends GutTest
const Schema = preload("res://scripts/persistence/save_schema.gd")
var session: Node
var w: Node
var b: Node
var worker: Node
func before_each() -> void:
	InputContext.menu_locked = false
	InputContext.set_context(InputContext.Context.WALK)
	process_mode = Node.PROCESS_MODE_ALWAYS
	session = load("res://scenes/ui/main_menu.tscn").instantiate()
	session.save_path = "user://tests/breaches_%d.json" % Time.get_ticks_usec()
	add_child_autofree(session)
	session.new_game()
	bind_world()
	w.get_node("Weather").current = "sunlight"
	w.get_node("Inventory").scrap = 300
	worker.remove_module("tool")
	assert_true(worker.install("tool","torch"))
	for topic in ["recovery","network","defense"]:
		w.get_node("Research").completed.append(topic)
		w.get_node("Research").archives[topic] = {"state":"delivered","carrier":""}
	await wait_physics_frames(2)
func bind_world() -> void:
	w = session.world
	for n in w.get_children(): n.set_physics_process(false)
	for actor in w.get_node("Threats").actors.values(): actor.set_physics_process(false)
	b = w.get_node("Breaches")
	worker = w.get_node("Fleet").drone("mule_01")
func after_each() -> void:
	InputContext.menu_locked = false
	get_tree().paused = false
	InputContext.set_context(InputContext.Context.WALK)
	await wait_process_frames(2)
func actor(at: Vector3 = Vector3(0,0.02,-11.5)) -> Node:
	var created: Node = w.get_node("Threats").spawn("breach_fixture",at,Vector3(0,0.02,-30))
	created.set_physics_process(false)
	return created
func force_contact(id: String) -> void:
	for _i in 100:
		if b.entrances[id].forced: return
		b.advance(10)
	assert_true(false,"A seeded contact scenario must actually force its seal")
func test_risk_requires_trace_and_reinforcement_never_reaches_zero() -> void:
	var state: Dictionary = b.State.initial()
	assert_eq(b.State.risk(state,39.999),0.0)
	var initial: float = b.State.risk(state,100)
	assert_almost_eq(initial,0.15,0.000001)
	state.tier = 3
	var plated: float = b.State.risk(state,100)
	assert_gt(plated,0.0)
	assert_lt(plated,initial)
	assert_gt(b.State.risk(state,40,0.6),0.0)
	assert_lt(b.State.risk(state,100,0.6),plated)
	state.condition = 0.0
	assert_gt(b.State.risk(state,100),plated)
func test_no_remote_or_stunned_force_and_cover_blocks_contact() -> void:
	w.get_node("Trace").trace[0] = 100.0
	var a := actor(Vector3(0,0.02,-20))
	await wait_physics_frames(2)
	b.advance(1000)
	assert_false(b.entrances.airlock_outer.forced)
	a.position = Vector3(0,0.02,-11.5)
	a.stun_remaining = 3
	await wait_physics_frames(2)
	b.advance(1000)
	assert_false(b.entrances.airlock_outer.forced)
	a.stun_remaining = 0
	var cover: Node = preload("res://scripts/world/surface_kit.gd").box(w.get_node("Surface"),"ContactCover",Vector3(2,2,0.1),Vector3(0,1,-10.8),"metal")
	await wait_physics_frames(2)
	assert_false(b.contact(a,"airlock_outer"))
	b.advance(1000)
	assert_false(b.entrances.airlock_outer.forced)
	cover.get_parent().remove_child(cover)
	cover.queue_free()
	await wait_physics_frames(2)
	assert_true(b.contact(a,"airlock_outer"))
func test_existing_body_crosses_outer_but_inner_remains_a_real_barrier() -> void:
	w.get_node("Trace").trace[0] = 100.0
	var a := actor()
	await wait_physics_frames(2)
	var count: int = w.get_node("Threats").actors.size()
	force_contact("airlock_outer")
	assert_eq(w.get_node("Threats").actors.size(),count)
	assert_true(w.get_node("Bunker/Airlock/OuterDoor/Collision").disabled)
	assert_false(w.get_node("Bunker/Airlock/InnerDoor/Collision").disabled)
	w.get_node("Emissions").set_physics_process(true)
	a.set_physics_process(true)
	await wait_physics_frames(240)
	a.set_physics_process(false)
	assert_gt(a.position.z,-10.0)
	assert_lt(a.position.z,-6.0,"One failed seal does not bypass the second collider")
	assert_true(b.is_intruder(a.identity))
	force_contact("airlock_inner")
	a.set_physics_process(true)
	await wait_physics_frames(120)
	a.set_physics_process(false)
	assert_gt(a.position.z,-6.0)
func test_intruder_can_kill_bare_operator_without_overwriting_last_save() -> void:
	w.get_node("Trace").trace[0] = 100.0
	var a := actor()
	w.get_node("Operator").position = Vector3(0,0.02,-3)
	await wait_physics_frames(2)
	assert_true(session.save_current())
	var saved := FileAccess.get_file_as_string(session.save_path)
	force_contact("airlock_outer")
	w.get_node("Emissions").set_physics_process(true)
	a.set_physics_process(true)
	await wait_physics_frames(210)
	a.set_physics_process(false)
	force_contact("airlock_inner")
	a.set_physics_process(true)
	await wait_physics_frames(240)
	assert_true(w.get_node("HumanSortie").dead)
	assert_false(session.save_current())
	assert_true(session.menu.subtitle.text.contains("mutant"),"A blocked death save preserves the actual cause")
	assert_eq(FileAccess.get_file_as_string(session.save_path),saved)
func test_plating_and_repair_pay_real_scrap_energy_and_reject_occupied_aperture() -> void:
	var before: float = worker.battery
	assert_true(b.service("airlock_outer",worker.identity,true))
	assert_eq(w.get_node("Inventory").scrap,276)
	assert_almost_eq(worker.battery,before-0.02,0.000001)
	assert_false(b.service("airlock_outer",worker.identity,true))
	b.advance(13)
	worker.battery = 0.001
	assert_false(b.service("airlock_outer",worker.identity,true))
	assert_eq(w.get_node("Inventory").scrap,276)
	worker.battery = 0.5
	b._force("airlock_outer")
	var a := actor(Vector3(0,0.02,-10))
	await wait_physics_frames(2)
	assert_false(b.service("airlock_outer",worker.identity,false))
	a.apply_damage(100)
	await wait_physics_frames(2)
	var cost: int = b.repair_cost("airlock_outer")
	assert_true(b.service("airlock_outer",worker.identity,false))
	assert_eq(w.get_node("Inventory").scrap,276-cost)
	assert_false(b.entrances.airlock_outer.forced)
	assert_eq(b.entrances.airlock_outer.condition,100.0)
	assert_eq(b.entrances.airlock_outer.tier,1)
func test_rail_noise_uses_actual_paid_metres_and_persists_partial_cadence() -> void:
	w.get_node("Territory").sites[1].held = true
	w.get_node("Excavation").restore({"segments":[{"kind":"tunnel","source":0,"target":1,"width":6.0,"depth":6.0,"height":3.2}],"rooms":{},"jobs":{},"next_serial":1})
	var r: Node = w.get_node("Rail")
	r.car_built = true
	r.sync()
	assert_true(r.freight.add_rule(0,1,"scrap",10,10))
	r.freight.advance(1)
	assert_eq(b.rail_clocks["0"],0.0)
	assert_eq(w.get_node("Trace").trace[0],0.0)
	r.prepare()
	w.get_node("LifeSupport").advance(1)
	for _i in 2:
		r.freight.advance(1)
		r.prepare()
		w.get_node("LifeSupport").advance(1)
	assert_eq(b.rail_clocks["0"],4.0)
	assert_true(session.save_current())
	assert_true(session.continue_game())
	bind_world()
	r = w.get_node("Rail")
	assert_eq(b.rail_clocks["0"],4.0)
	for _i in 3:
		r.freight.advance(1)
		r.prepare()
		w.get_node("LifeSupport").advance(1)
	assert_almost_eq(b.rail_clocks["0"],0.0,0.000001)
	assert_almost_eq(w.get_node("Trace").trace[0],0.82,0.000001)
func test_contact_rng_route_plating_reload_and_v33_migration() -> void:
	w.get_node("Trace").trace[0] = 100.0
	var a := actor()
	await wait_physics_frames(2)
	b.goal(a,false)
	b.entrances.airlock_outer.tier = 2
	b.advance(5)
	assert_true(session.save_current())
	var random_state: String = str(b.rng.state)
	assert_true(session.continue_game())
	bind_world()
	assert_eq(b.entrances.airlock_outer.tier,2)
	assert_eq(b.entrances.airlock_outer.contact,5.0)
	assert_eq(str(b.rng.state),random_state)
	assert_true(b.routes.has("breach_fixture"))
	var data := Schema.capture(w)
	assert_eq(Schema.validate(data),"")
	var bad := data.duplicate(true)
	bad.breaches.routes.missing = {"stage":1,"patrol":0}
	assert_false(Schema.validate(bad).is_empty())
	data.version = 33
	data.erase("breaches")
	Schema.restore(w,data)
	assert_eq(b.entrances.airlock_outer.tier,0)
	assert_true(b.routes.is_empty())
	assert_false(w.get_node("Bunker/Airlock").forced_sides.outer)
func test_surface_exposure_requires_breached_access_and_terminal_fits() -> void:
	w.get_node("Operator").position = Vector3(0,0.02,-13)
	b.advance(10)
	assert_false(w.get_node("HumanSortie").dead)
	b._force("airlock_outer")
	b.advance(4)
	assert_false(w.get_node("HumanSortie").dead)
	w.get_node("Operator").position.y = -5.4
	b.advance(2)
	assert_eq(b.exposure,0.0)
	var ui: Node = w.get_node("HardeningPanel")
	ui.open()
	await wait_process_frames(3)
	assert_lte(ui.panel.get_combined_minimum_size().x,640.0)
	assert_lte(ui.panel.get_combined_minimum_size().y,480.0)
	assert_lte(ui.panel.get_child(0).get_child(0).get_child(-1).get_global_rect().end.y,480.0)
func test_paid_plating_caps_at_three_and_forced_other_door_blocks_normal_opening() -> void:
	w.get_node("Trace").trace[0] = 100.0
	var original: float = b.probability("airlock_outer")
	for _i in 3:
		assert_true(b.service("airlock_outer",worker.identity,true))
		b.advance(13)
	assert_eq(b.entrances.airlock_outer.tier,3)
	assert_eq(w.get_node("Inventory").scrap,228)
	assert_almost_eq(worker.battery,0.94,0.000001)
	assert_gt(b.probability("airlock_outer"),0.0)
	assert_lt(b.probability("airlock_outer"),original)
	assert_false(b.service("airlock_outer",worker.identity,true))
	b._force("airlock_outer")
	assert_false(w.get_node("Bunker/Airlock").request_open(&"inner"))
func test_heavy_service_energy_comes_from_the_finite_tender() -> void:
	var scene = load("res://scenes/drones/drone.tscn")
	var g: Node = scene.instantiate()
	g.identity = "hardening_heavy"
	g.hull_id = "goliath"
	g.battery = 0.2
	g.deployed = true
	g.position = Vector3(-4,0.02,-17)
	assert_true(g.install("tool","torch"))
	w.get_node("Fleet").add_child(g)
	var donor: Node = scene.instantiate()
	donor.identity = "hardening_tender"
	donor.hull_id = "tender"
	donor.battery = 1.0
	donor.deployed = true
	donor.position = Vector3(-4,0.02,-20)
	assert_true(donor.install("utility","power_coupler"))
	w.get_node("Fleet").add_child(donor)
	await wait_physics_frames(2)
	assert_true(w.get_node("PowerTether").attach(g.identity,donor.identity))
	assert_true(b.service("airlock_outer",g.identity,true))
	assert_almost_eq(donor.battery,1.0-0.02/0.9,0.000001)
	assert_eq(g.battery,0.2)
func test_static_defense_discount_requires_actual_fresh_electricity() -> void:
	w.get_node("Trace").trace[0] = 100.0
	var defense: Node = w.get_node("Defense")
	w.get_node("Territory").sites[0].perimeter = true
	defense.install_perimeter(0)
	assert_almost_eq(b.probability("airlock_outer"),0.15*0.8,0.000001)
	assert_true(defense.set_fence(0,true))
	assert_almost_eq(b.probability("airlock_outer"),0.15*0.8,0.000001,"An unpaid switch position is only a physical barrier")
	w.get_node("LifeSupport").advance(1)
	assert_almost_eq(b.probability("airlock_outer"),0.15*0.6,0.000001)
	defense.restore(defense.snapshot())
	assert_almost_eq(b.probability("airlock_outer"),0.15*0.8,0.000001,"Restore grants no free energized protection")
	w.get_node("LifeSupport").generator_on = false
	w.get_node("LifeSupport").battery = 0
	w.get_node("LifeSupport").advance(1)
	assert_almost_eq(b.probability("airlock_outer"),0.15*0.8,0.000001)
