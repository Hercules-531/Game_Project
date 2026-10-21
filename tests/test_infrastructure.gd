extends GutTest
const Schema = preload("res://scripts/persistence/save_schema.gd")
var session: Node
var w: Node
var r: Node
var infra: Node
var life: Node
var worker: Node
func before_each() -> void:
	InputContext.menu_locked = false
	InputContext.set_context(InputContext.Context.WALK)
	process_mode = Node.PROCESS_MODE_ALWAYS
	session = load("res://scenes/ui/main_menu.tscn").instantiate()
	session.save_path = "user://tests/infrastructure_%d.json" % Time.get_ticks_usec()
	add_child_autofree(session)
	session.new_game()
	bind_world()
	for i in [1,2]:
		w.get_node("Territory").sites[i].held = true
		w.get_node("Territory").sites[i].pylon = true
		w.get_node("Territory").sites[i].fob = true
	var segments: Array = []
	for i in 2: segments.append({"kind":"tunnel","source":i,"target":i+1,"width":6.0,"depth":6.0,"height":3.2})
	w.get_node("Excavation").restore({"segments":segments,"rooms":{},"jobs":{},"next_serial":1})
	r.car_built = true
	r.sync()
	w.get_node("Inventory").scrap = 200
	worker.remove_module("tool")
	assert_true(worker.install("tool","torch"))
	life.generator_on = false
	life.fuel = 0
	life.battery = 2
	await wait_physics_frames(2)
func bind_world() -> void:
	w = session.world
	for n in w.get_children(): n.set_physics_process(false)
	r = w.get_node("Rail")
	infra = r.infrastructure
	life = w.get_node("LifeSupport")
	worker = w.get_node("Fleet").drone("mule_01")
func after_each() -> void:
	InputContext.menu_locked = false
	get_tree().paused = false
	InputContext.set_context(InputContext.Context.WALK)
	await wait_process_frames(2)
func test_exact_bands_control_real_speed_and_wire_loss() -> void:
	for pair in [[100.0,2.0],[80.0,2.0/1.2],[20.0,2.0*0.35/1.2],[0.0,0.0]]:
		r.conditions["0"] = pair[0]
		var move: Dictionary = infra.movement(0,10,1)
		assert_almost_eq(move.next,pair[1],0.000001)
	for pair in [[80.0001,1.0],[80.0,1.2],[20.0001,1.2],[20.0,1.2/0.35]]:
		infra.wires["0"] = pair[0]
		infra.begin_demand()
		assert_almost_eq(infra.demand(1,1.0),pair[1],0.000001)
	infra.wires["0"] = 0.0
	assert_false(r.wired(1))
	assert_eq(infra.demand(1,1.0),0.0)
func test_travel_wears_only_crossed_metres_with_actual_payload() -> void:
	infra.record_travel(0,20,10,0)
	assert_almost_eq(r.conditions["0"],99.98,0.000001)
	r.conditions["0"] = 100.0
	infra.record_travel(0,20,10,200)
	assert_almost_eq(r.conditions["0"],99.96,0.000001)
	r.conditions["0"] = 100.0
	infra.cycles.rail0 = 0.0
	var join: float = r.freight.distance_to_hub(1)
	infra.record_travel(join-2,join+3,2.5,0)
	assert_almost_eq(r.conditions["0"],99.998,0.000001)
	assert_almost_eq(r.conditions["1"],99.997,0.000001)
	assert_almost_eq(infra.cycles.rail0,1.0,0.000001)
	assert_almost_eq(infra.cycles.rail1,1.5,0.000001)
func test_extra_grid_draw_is_paid_before_useful_energy_and_wire_wear() -> void:
	infra.wires["0"] = 50.0
	infra.wires["1"] = 50.0
	r.prepare()
	assert_almost_eq(life.rail_load_kw,0.02+0.024+0.0288,0.00000001)
	assert_almost_eq(infra.loss_kw,0.0128,0.00000001)
	var before: float = life.battery
	var demand: float = life.load_kw()
	life.advance(1)
	assert_almost_eq(before-life.battery,demand/3600.0,0.00000001)
	assert_almost_eq(infra.wires["0"],50.0-0.00025-(0.024+0.0288)/3600.0*0.5,0.00000001)
	assert_almost_eq(infra.wires["1"],50.0-0.00025-0.024/3600.0*0.5,0.00000001)
	assert_almost_eq(r.stations[2].get_node("Light").light_energy,1.8,0.000001)
func test_short_costs_real_energy_while_track_jam_keeps_healthy_wire_alive() -> void:
	infra.wire_faults["0"] = 8.0
	r.prepare()
	assert_false(r.wired(1))
	assert_almost_eq(infra.short_kw,2.0,0.000001)
	assert_almost_eq(life.rail_load_kw,2.02,0.000001)
	var before: float = life.battery
	var demand: float = life.load_kw()
	life.advance(1)
	assert_almost_eq(before-life.battery,demand/3600.0,0.00000001)
	assert_eq(infra.wire_faults["0"],7.0)
	assert_eq(r.stations[1].get_node("Light").light_energy,0.0)
	infra.wire_faults.clear()
	infra.rail_faults["0"] = 8.0
	r.prepare()
	assert_true(r.wired(2))
	assert_false(r.connected(2))
	life.advance(1)
	assert_almost_eq(r.stations[2].get_node("Light").light_energy,1.8,0.000001)
	assert_eq(infra.movement(0,10,1).used,0.0)
func test_seeded_cycles_are_partition_invariant_and_independent_of_weather_radio() -> void:
	infra.wires = {"0":20.0,"1":20.0}
	infra.rng.seed = 123
	r.prepare()
	var original: Dictionary = r.snapshot()
	var original_life: Dictionary = life.snapshot()
	for _i in 120: life.advance(1)
	var expected: Dictionary = infra.snapshot()
	r.restore(original)
	life.restore(original_life)
	w.get_node("Weather").current = "aurora"
	w.get_node("Radio").drops = {"pylon_1":1000.0,"pylon_2":1000.0}
	life.advance(120)
	assert_eq(infra.snapshot(),expected)
	assert_lt(infra.wires["0"],20.0)
	assert_lt(infra.cycles.wire1,60.0)
func test_paid_maintenance_reserves_real_hull_holds_on_blackout_and_repairs_once() -> void:
	r.conditions["0"] = 50.0
	assert_true(infra.request("rail",0,worker.identity))
	assert_eq(w.get_node("Inventory").scrap,190)
	assert_true(infra.controls(worker.identity))
	assert_false(infra.request("wire",0,worker.identity))
	assert_false(w.get_node("Workshop").remove(worker.identity,"tool"))
	assert_false(w.get_node("FleetControl").request_machine_transfer(worker,true))
	worker.get_node("Controller").command = Vector2(0,-1)
	w.get_node("Orders").programs[worker.identity] = {"rules":[],"cursor":0,"mode":"running","blocked":0.0,"return_cursor":-1}
	w.get_node("Orders").advance(1)
	assert_eq(worker.get_node("Controller").command,Vector2.ZERO)
	var control: Node = w.get_node("FleetControl")
	control.selected_id = worker.identity
	control.panel_open = true
	control.piloting = true
	InputContext.set_context(InputContext.Context.TERMINAL)
	control.link.send_action("hover_01","ping",0.0)
	control._physics_process(0.1)
	assert_true(control.link.ready_actions().is_empty(),"Reserving one motor must not suspend queued actions for another hull")
	var remaining: float = infra.jobs.rail0.remaining
	var before: float = life.battery
	var demand: float = life.load_kw()
	life.advance(1)
	assert_almost_eq(infra.jobs.rail0.remaining,remaining-1.2,0.000001)
	assert_almost_eq(before-life.battery,demand/3600.0,0.00000001)
	life.battery = 0
	life.supplied_fraction = 1
	remaining = infra.jobs.rail0.remaining
	life.advance(3)
	assert_eq(infra.jobs.rail0.remaining,remaining)
	life.battery = 2
	life.advance(100)
	assert_true(infra.jobs.is_empty())
	assert_eq(r.conditions["0"],100.0)
	assert_eq(w.get_node("Inventory").scrap,190)
	assert_false(infra.busy(worker.identity))
	assert_true(worker.get_node("Controller").available)
func test_field_maintenance_uses_local_scrap_and_waits_for_upstream_conduit() -> void:
	worker.deployed = true
	worker.position = r.territory.pad(1)+Vector3(2,0,0)
	r.stock(1).scrap = 30
	infra.wires["0"] = 50.0
	infra.wires["1"] = 40.0
	r.prepare()
	assert_true(infra.request("wire",1,worker.identity))
	assert_eq(r.stock(1).scrap,18)
	assert_eq(w.get_node("Inventory").scrap,200)
	assert_true(r.wired(1))
	assert_false(r.wired(2))
	assert_gte(infra.loss_kw,0.2)
	life.advance(1)
	var remaining: float = infra.jobs.wire1.remaining
	infra.wires["0"] = 0.0
	r.prepare()
	life.advance(5)
	assert_eq(infra.jobs.wire1.remaining,remaining)
	assert_false(infra.controls(worker.identity))
	infra.wires["0"] = 50.0
	r.prepare()
	for _i in 120:
		if infra.jobs.is_empty(): break
		life.advance(1)
	assert_true(infra.jobs.is_empty())
	assert_eq(infra.wires["1"],100.0)
	assert_eq(r.stock(1).scrap,18)
	life.advance(1)
	assert_lt(infra.wires["1"],100.0,"Energized conduit resumes ordinary wear after service")
func test_cancel_and_hull_loss_release_isolation_without_refunding_materials() -> void:
	r.conditions["0"] = 50.0
	assert_true(infra.request("rail",0,worker.identity))
	assert_true(infra.cancel("rail",0))
	assert_eq(r.conditions["0"],50.0)
	assert_eq(w.get_node("Inventory").scrap,190)
	assert_false(infra.isolated("rail",0))
	infra.wires["0"] = 30.0
	assert_true(infra.request("wire",0,worker.identity))
	worker.apply_damage(1000)
	r.prepare()
	assert_true(infra.jobs.is_empty())
	assert_false(infra.isolated("wire",0))
	assert_eq(w.get_node("Inventory").scrap,176)
	assert_eq(infra.wires["0"],30.0)
func test_reload_keeps_paid_job_fault_clock_rng_and_does_not_recount_travel() -> void:
	r.conditions["0"] = 40.0
	assert_true(infra.request("rail",0,worker.identity))
	life.advance(3)
	infra.wire_faults["1"] = 5.0
	r.prepare()
	var data := Schema.capture(w)
	assert_eq(Schema.validate(data),"")
	var bad := data.duplicate(true)
	bad.rail.infrastructure.wires["0"] = NAN
	assert_false(Schema.validate(bad).is_empty())
	bad = data.duplicate(true)
	bad.rail.infrastructure.jobs.rail0.worker = "missing"
	assert_false(Schema.validate(bad).is_empty())
	bad = data.duplicate(true)
	bad.rail.infrastructure.jobs.wire0 = bad.rail.infrastructure.jobs.rail0.duplicate(true)
	bad.rail.infrastructure.jobs.wire0.kind = "wire"
	assert_false(Schema.validate(bad).is_empty())
	var remaining: float = infra.jobs.rail0.remaining
	var random_state: String = str(infra.rng.state)
	assert_true(session.save_current())
	assert_true(session.continue_game())
	bind_world()
	assert_almost_eq(infra.jobs.rail0.remaining,remaining,0.000001)
	assert_eq(str(infra.rng.state),random_state)
	assert_eq(infra.wire_faults["1"],5.0)
	assert_eq(r.conditions["0"],40.0)
	assert_eq(w.get_node("Inventory").scrap,188)
	life.generator_on = false
	life.battery = 0
	life.advance(2)
	assert_almost_eq(infra.jobs.rail0.remaining,remaining,0.000001)
	life.battery = 2
	for _i in 200:
		if infra.jobs.is_empty(): break
		life.advance(1)
	assert_true(infra.jobs.is_empty())
	assert_eq(r.conditions["0"],100.0,"Completion of a JSON-restored job updates the original line key")
	assert_eq(r.conditions.size(),r.dig.segments.size())
	assert_eq(Schema.validate(Schema.capture(w)),"")
	assert_true(session.save_current())
	infra.wires["0"] = 50.0
	assert_true(infra.request("wire",0,worker.identity))
	assert_true(session.save_current())
	assert_true(session.continue_game())
	bind_world()
	for _i in 200:
		if infra.jobs.is_empty(): break
		life.advance(1)
	assert_true(infra.jobs.is_empty())
	assert_eq(infra.wires["0"],100.0)
	assert_eq(infra.wires.size(),r.dig.segments.size())
	assert_eq(Schema.validate(Schema.capture(w)),"")
	assert_true(session.save_current())
func test_v32_migration_preserves_old_rail_condition_and_terminal_fits() -> void:
	r.conditions["0"] = 65.0
	var data := Schema.capture(w)
	data.version = 32
	data.rail.erase("infrastructure")
	assert_eq(Schema.validate(data),"")
	Schema.restore(w,data)
	assert_eq(r.conditions["0"],65.0)
	assert_eq(infra.wires["0"],100.0)
	assert_true(infra.jobs.is_empty())
	assert_true(infra.rail_faults.is_empty())
	var ui: Node = w.get_node("MaintenancePanel")
	ui.open()
	await wait_process_frames(3)
	assert_lte(ui.panel.get_combined_minimum_size().x,640.0)
	assert_lte(ui.panel.get_combined_minimum_size().y,480.0)
	assert_lte(ui.panel.get_child(0).get_child(0).get_child(-1).get_global_rect().end.y,480.0)
func test_real_freight_slows_jams_and_resumes_with_the_same_paid_reserve() -> void:
	assert_true(r.freight.add_rule(0,1,"scrap",10,10))
	r.freight.advance(1)
	r.prepare()
	life.advance(1)
	r.conditions["0"] = 20.0
	r.freight.advance(1)
	assert_almost_eq(r.freight.coordinate,2.0*0.35/1.2,0.000001)
	r.prepare()
	life.advance(1)
	var at: float = r.freight.coordinate
	var credit: float = r.freight.credit
	infra.rail_faults["0"] = 8.0
	r.prepare()
	r.freight.advance(1)
	assert_eq(r.freight.coordinate,at)
	assert_eq(r.freight.credit,credit)
	life.advance(8)
	assert_false(infra.rail_faults.has("0"))
	r.freight.advance(1)
	assert_gt(r.freight.coordinate,at)
	assert_eq(r.freight.credit,0.0)
func test_partial_lossy_motor_payment_credits_only_paid_useful_seconds() -> void:
	assert_true(r.freight.add_rule(0,1,"scrap",10,10))
	r.freight.advance(1)
	r.prepare()
	life.advance(1)
	r.freight.advance(1)
	assert_eq(r.freight.coordinate,2.0)
	infra.wires["0"] = 50.0
	r.prepare()
	assert_almost_eq(infra.edge_requests["0"],1.8+0.024+0.024,0.000001)
	life.battery = life.load_kw()/3600.0*0.5
	life.advance(1)
	assert_almost_eq(r.freight.credit,0.5,0.00000001)
	r.freight.advance(1)
	assert_almost_eq(r.freight.coordinate,3.0,0.000001)
	assert_almost_eq(r.freight.credit,0.0,0.00000001)
func test_parallel_components_need_distinct_hulls_and_each_pay_for_their_work() -> void:
	r.conditions["0"] = 50.0
	infra.wires["0"] = 50.0
	var second: Node = load("res://scenes/drones/drone.tscn").instantiate()
	second.identity = "maintenance_second"
	second.hull_id = "tracked"
	second.battery = 0.5
	second.deployed = true
	second.position = r.territory.pad(0)+Vector3(3,0,0)
	assert_true(second.install("tool","torch"))
	w.get_node("Fleet").add_child(second)
	assert_true(infra.request("rail",0,worker.identity))
	assert_false(infra.request("wire",0,worker.identity))
	assert_true(infra.request("wire",0,second.identity))
	assert_eq(infra.jobs.size(),2)
	assert_eq(w.get_node("Inventory").scrap,180)
	assert_almost_eq(life.rail_load_kw,2.02,0.000001)
	var rail_time: float = infra.jobs.rail0.remaining
	var wire_time: float = infra.jobs.wire0.remaining
	life.advance(1)
	assert_almost_eq(infra.jobs.rail0.remaining,rail_time-1.2,0.000001)
	assert_almost_eq(infra.jobs.wire0.remaining,wire_time-1.2,0.000001)
	assert_eq(Schema.validate(Schema.capture(w)),"")
func test_source_breaker_stops_short_draw_and_far_outage_does_not_cut_upstream_station() -> void:
	infra.wire_faults["0"] = 8.0
	r.prepare()
	assert_eq(infra.short_kw,2.0)
	assert_true(infra.toggle_isolation(0))
	assert_eq(infra.short_kw,0.0)
	assert_almost_eq(life.rail_load_kw,0.02,0.000001)
	assert_true(infra.isolations["0"])
	assert_eq(Schema.validate(Schema.capture(w)),"")
	assert_true(session.save_current())
	assert_true(session.continue_game())
	bind_world()
	assert_true(infra.isolations["0"])
	assert_eq(infra.short_kw,0.0)
	assert_true(infra.toggle_isolation(0))
	assert_eq(infra.short_kw,2.0)
	infra.wire_faults.clear()
	infra.wires["1"] = 0.0
	r.prepare()
	var first: float = r.freight.distance_to_hub(1)
	assert_eq(infra.coordinate_hub(first),1)
	assert_true(r.wired(1))
	assert_false(r.wired(2))
	assert_true(r.freight.path_ready(0,first))
	assert_gt(infra.movement(0,first,1).next,0.0)
