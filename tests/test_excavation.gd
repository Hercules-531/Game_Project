extends GutTest
const Schema = preload("res://scripts/persistence/save_schema.gd")
const Scene = preload("res://scenes/drones/drone.tscn")
const Plan = preload("res://scripts/excavation/excavation_plan.gd")
var session: Node
var w: Node
var dig: Node
var g: Node
var bank: Node
func before_each() -> void:
	InputContext.menu_locked = false
	InputContext.set_context(InputContext.Context.WALK)
	process_mode = Node.PROCESS_MODE_ALWAYS
	session = load("res://scenes/ui/main_menu.tscn").instantiate()
	session.save_path = "user://tests/excavation_%d.json" % Time.get_ticks_usec()
	add_child_autofree(session)
	session.new_game()
	w = session.world
	dig = w.get_node("Excavation")
	for node in [dig,dig.get_node("PaidWork"),w.get_node("PowerTether"),w.get_node("Territory"),w.get_node("DronePower"),w.get_node("Conditions"),w.get_node("LifeSupport"),w.get_node("Trace"),w.get_node("Weather")]: node.set_physics_process(false)
	w.get_node("Radio").dropout_chance = 0
	w.get_node("Inventory").scrap = 1000
	for id in ["recovery","network","heavy","excavation"]:
		w.get_node("Research").completed.append(id)
		w.get_node("Research").archives[id] = {"state":"delivered","carrier":""}
	g = Scene.instantiate()
	g.identity = "excavator"
	g.hull_id = "goliath"
	g.battery = 0.2
	g.deployed = true
	g.position = Vector3(-4,0.02,-17)
	assert_true(g.install("tool","drill"))
	w.get_node("Fleet").add_child(g)
	bank = Scene.instantiate()
	bank.identity = "excavation_tender"
	bank.hull_id = "tender"
	bank.battery = 12
	bank.deployed = true
	bank.position = Vector3(-4,0.02,-20)
	assert_true(bank.install("utility","power_coupler"))
	w.get_node("Fleet").add_child(bank)
	await wait_physics_frames(2)
	assert_true(w.get_node("PowerTether").attach(g.identity,bank.identity))
func after_each() -> void:
	InputContext.menu_locked = false
	get_tree().paused = false
	InputContext.set_context(InputContext.Context.WALK)
	await wait_process_frames(2)
func room(width: float = 6, depth: float = 6, height: float = 3.2) -> bool:
	return dig.request(g.identity,"room",0,0,width,depth,height)
func tick(seconds: float) -> void:
	dig.prepare()
	w.get_node("PowerTether").advance(seconds)
	w.get_node("Territory")._power_heavy(seconds)
	dig.advance(seconds)
func finish_job() -> void:
	var guard := 0
	while not dig.jobs.is_empty() and guard<2000:
		tick(1)
		guard += 1
	assert_true(dig.jobs.is_empty(),"Paid work must actually finish")
func hold_bands(count: int) -> void:
	var state: Dictionary = w.get_node("Territory").snapshot()
	for i in range(1,count+1):
		state.sites[i].held = true
		state.sites[i].pylon = true
		state.sites[i].battery = 1.0
	w.get_node("Territory").restore(state)
	await wait_physics_frames(2)
func test_reject_unknown_skip_backwards_overheight_missing_tool_and_overlap() -> void:
	var before: int = w.get_node("Inventory").scrap
	assert_false(dig.request(g.identity,"tunnel",0,1,6,6,3.2))
	await hold_bands(2)
	assert_false(dig.request(g.identity,"tunnel",0,2,6,6,3.2),"Cannot skip northward hubs")
	assert_false(dig.request(g.identity,"tunnel",1,2,6,6,3.2),"Tunnel starts at connected underground ground")
	assert_false(dig.request(g.identity,"tunnel",1,0,6,6,3.2))
	assert_false(room(6,6,3.4),"Drill reach is a hard height cap")
	assert_false(room(5,6,3.2))
	assert_false(dig.request("mule_01","room",0,0,6,6,3.2))
	assert_eq(w.get_node("Inventory").scrap,before,"Rejected plans consume nothing")
	assert_true(room())
	assert_false(room(),"A hull cannot reserve a second job")
	assert_false(w.get_node("Workshop").remove(g.identity,"tool"))
	assert_false(w.get_node("FleetControl").request_machine_transfer(g,false))
	assert_false(w.get_node("Territory").construct(g.identity,1))
func test_only_fresh_paid_time_advances_and_partial_energy_is_fractional() -> void:
	assert_true(room())
	var job: Dictionary = dig.jobs.values()[0]
	var initial: float = job.remaining
	dig.advance(10)
	assert_eq(job.remaining,initial,"No supply credit, no work")
	tick(1)
	assert_almost_eq(job.remaining,initial-1.2,0.000001)
	var after: float = job.remaining
	dig.advance(1)
	assert_eq(job.remaining,after,"Cannot replay a paid second")
	dig.prepare()
	var kw: float = w.get_node("DronePower").required_kw(g)
	bank.battery = kw*2/(3600.0*0.9)*0.5
	w.get_node("PowerTether").advance(2)
	dig.advance(2)
	assert_almost_eq(job.remaining,after-1.2,0.000001,"Half-paid interval gives half the work")
	assert_eq(bank.battery,0.0)
	assert_false(g.has_power())
	var held: float = job.remaining
	tick(3)
	assert_eq(job.remaining,held)
func test_link_staging_tool_and_cancel_hold_without_refund() -> void:
	assert_true(room())
	var paid_scrap: int = w.get_node("Inventory").scrap
	var job: Dictionary = dig.jobs.values()[0]
	var remaining: float = job.remaining
	w.get_node("Radio").drops[g.identity] = 2
	tick(1)
	assert_eq(job.remaining,remaining)
	assert_false(dig.controls(g.identity),"Failsafe may own a held hull")
	w.get_node("Radio").drops.clear()
	g.faults.tool = 8
	tick(1)
	assert_eq(job.remaining,remaining)
	g.faults.clear()
	g.position += Vector3(10,0,0)
	bank.position = g.position+Vector3(0,0,3)
	tick(1)
	assert_eq(job.remaining,remaining,"Assigned location is physical")
	g.position = Vector3(-4,0.02,-17)
	bank.position = Vector3(-4,0.02,-20)
	assert_true(dig.cancel(g.identity))
	assert_eq(w.get_node("Inventory").scrap,paid_scrap)
	assert_true(g.get_node("Controller").available)
	assert_eq(g.work_noise,0.0)
	assert_true(dig.rooms.is_empty())
func test_mid_job_reload_drops_old_credit_and_completes_once() -> void:
	assert_true(room())
	tick(5)
	var remaining: float = dig.jobs.values()[0].remaining
	var stock: int = w.get_node("Inventory").scrap
	w.get_node("PowerTether").advance(2)
	var saved := JSON.parse_string(JSON.stringify(Schema.capture(w))) as Dictionary
	assert_eq(Schema.validate(saved),"")
	Schema.restore(w,saved)
	g = w.get_node("Fleet").drone("excavator")
	bank = w.get_node("Fleet").drone("excavation_tender")
	dig.advance(2)
	assert_eq(dig.jobs.values()[0].remaining,remaining,"Reload cannot replay old power")
	assert_eq(w.get_node("Inventory").scrap,stock)
	await wait_physics_frames(2)
	finish_job()
	assert_true(dig.rooms.has("0"))
	assert_eq(dig.grid.size(),36)
	assert_eq(g.work_noise,0.0)
	assert_true(g.get_node("Controller").available)
	assert_false(room(),"Finished volume cannot be bought/completed twice")
	assert_eq(w.get_node("Inventory").scrap,stock)
	assert_eq(Schema.validate(Schema.capture(w)),"")
func test_room_and_route_geometry_have_real_floor_roof_wall_and_open_join() -> void:
	assert_true(room(6,10,3.2))
	finish_job()
	await hold_bands(1)
	assert_true(dig.request(g.identity,"tunnel",0,1,6,6,3.2))
	finish_job()
	await wait_physics_frames(2)
	var physics = dig.get_world_3d().direct_space_state
	var floor_hit: Dictionary = physics.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0.2,-4,-13.2),Vector3(0.2,-7,-13.2)))
	assert_false(floor_hit.is_empty())
	assert_almost_eq(floor_hit.position.y,-6.0,0.0001)
	var roof: Dictionary = physics.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0.2,-4,-13.2),Vector3(0.2,-1,-13.2)))
	assert_almost_eq(roof.position.y,-2.8,0.0001)
	var wall: Dictionary = physics.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0.2,-4,-13.2),Vector3(-8,-4,-13.2)))
	assert_false(wall.is_empty())
	var join: Dictionary = physics.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0.2,-4,-14),Vector3(0.2,-4,-24)))
	assert_true(join.is_empty(),"Joined room/tunnel has no internal end wall")
	assert_eq(dig.segments.size(),1)
	var saved := JSON.parse_string(JSON.stringify(Schema.capture(w))) as Dictionary
	assert_eq(Schema.validate(saved),"")
	Schema.restore(w,saved)
	assert_eq(dig.segments.size(),1)
	assert_true(dig.rooms.has("0"))
func test_preloaded_aurora_works_without_storing_energy_and_pause_freezes() -> void:
	assert_true(room())
	var initial: float = dig.jobs.values()[0].remaining
	var old_cell: float = g.battery
	w.get_node("Orders").local_field_power = true
	w.get_node("Radio").range_multiplier = 0
	dig.prepare()
	dig.advance(2)
	assert_almost_eq(dig.jobs.values()[0].remaining,initial-2.4,0.000001)
	assert_eq(g.battery,old_cell)
	w.get_node("Orders").local_field_power = false
	w.get_node("Radio").range_multiplier = 1
	dig.set_physics_process(true)
	dig.get_node("PaidWork").set_physics_process(true)
	w.get_node("PowerTether").set_physics_process(true)
	InputContext.set_context(InputContext.Context.MENU)
	var remaining: float = dig.jobs.values()[0].remaining
	await wait_process_frames(5)
	assert_eq(dig.jobs.values()[0].remaining,remaining)
	assert_true(get_tree().paused)
	session.resume()
	await wait_physics_frames(5)
	assert_lt(dig.jobs.values()[0].remaining,remaining)
func test_invalid_saves_migration_and_terminal_map_fit() -> void:
	assert_true(room())
	var data := Schema.capture(w)
	data.excavation.jobs.values()[0].plan.height = 4
	assert_ne(Schema.validate(data),"")
	data = Schema.capture(w)
	data.excavation.jobs.values()[0].worker = "missing_hull"
	assert_ne(Schema.validate(data),"")
	var old := Schema.capture(w)
	old.version = 28
	old.erase("excavation")
	assert_eq(Schema.validate(old),"")
	var panel: Node = w.get_node("ExcavationPanel")
	panel.open()
	panel.workers.select(0)
	panel.workers.item_selected.emit(0)
	panel.kind.select(1)
	panel.kind.item_selected.emit(1)
	panel.width.value = 20
	assert_eq(panel.plan().width,20.0,"Room mode expands the limit immediately, not on a later UI frame")
	panel.kind.select(0)
	panel.kind.item_selected.emit(0)
	assert_lte(panel.plan().width,10.0)
	assert_eq(panel.plan().depth,6.0,"A tunnel's length comes from its endpoints")
	await wait_process_frames(2)
	assert_lte(panel.panel.get_combined_minimum_size().x,640.0)
	assert_lte(panel.panel.get_combined_minimum_size().y,480.0)
	var buttons: Array = panel.panel.find_children("*","Button",true,false)
	assert_lte(buttons.back().global_position.y+buttons.back().size.y,480.0)
	buttons.back().pressed.emit()
	assert_true(w.get_node("FleetPanel").panel.visible)
func test_two_workers_reject_overlapping_footprints_and_pay_distinct_jobs() -> void:
	await hold_bands(1)
	# A completed route is this concurrency scenario's starting state.
	dig.segments = [{"kind":"tunnel","source":0,"target":1,"width":6.0,"depth":6.0,"height":3.2}]
	dig.grid = Plan.grid(dig.segments,dig.rooms)
	dig.geometry.rebuild(dig.grid)
	var second: Node = Scene.instantiate()
	second.identity = "excavator_second"
	second.hull_id = "goliath"
	second.battery = 0.2
	second.deployed = true
	second.position = Vector3(-2,0.02,-17)
	assert_true(second.install("tool","drill"))
	g.position.x = -6
	bank.position.x = -6
	w.get_node("Fleet").add_child(second)
	var supply: Node = Scene.instantiate()
	supply.identity = "tender_second"
	supply.hull_id = "tender"
	supply.battery = 12
	supply.deployed = true
	supply.position = Vector3(-2,0.02,-20)
	assert_true(supply.install("utility","power_coupler"))
	w.get_node("Fleet").add_child(supply)
	await wait_physics_frames(2)
	assert_true(w.get_node("PowerTether").attach(second.identity,supply.identity))
	assert_true(room())
	var stock: int = w.get_node("Inventory").scrap
	assert_false(dig.request(second.identity,"room",0,0,8,8,3.2))
	assert_eq(w.get_node("Inventory").scrap,stock,"Overlap rejection charges nothing")
	second.position = w.get_node("Territory").pad(1)+Vector3(-4,0,-4)
	supply.position = second.position+Vector3(0,0,3)
	await wait_physics_frames(2)
	assert_true(dig.request(second.identity,"room",1,1,6,6,3.2))
	assert_eq(dig.jobs.size(),2)
	var first: float = dig.jobs.values()[0].remaining
	var other: float = dig.jobs.values()[1].remaining
	tick(1)
	assert_almost_eq(dig.jobs.values()[0].remaining,first-1.2,0.000001)
	assert_almost_eq(dig.jobs.values()[1].remaining,other-1.2,0.000001)
	assert_eq(Schema.validate(Schema.capture(w)),"")
func test_destroyed_worker_abandons_work_without_refund_or_free_geometry() -> void:
	assert_true(room())
	var paid: int = w.get_node("Inventory").scrap
	tick(3)
	g.apply_damage(10000)
	dig.prepare()
	assert_true(dig.jobs.is_empty())
	assert_eq(w.get_node("Inventory").scrap,paid)
	assert_true(dig.rooms.is_empty())
	assert_true(dig.grid.is_empty())
	assert_eq(g.work_noise,0.0)
	assert_false(g.has_power())
	assert_eq(Schema.validate(Schema.capture(w)),"")
func test_drill_vibration_requires_paid_work_and_preserves_partial_clock_on_reload() -> void:
	w.get_node("Emissions").set_physics_process(false)
	w.get_node("Breaches").set_physics_process(false)
	assert_true(room(10,10,3.2))
	var remaining: float = dig.jobs.values()[0].remaining
	dig.advance(5)
	assert_eq(dig.jobs.values()[0].remaining,remaining)
	assert_true(w.get_node("Emissions").pulses.filter(func(p): return p.kind=="drill").is_empty())
	tick(4)
	assert_almost_eq(dig.jobs.values()[0].noise_clock,4.0,0.000001)
	assert_true(w.get_node("Emissions").pulses.filter(func(p): return p.kind=="drill").is_empty())
	assert_true(session.save_current())
	assert_true(session.continue_game())
	w = session.world
	dig = w.get_node("Excavation")
	g = w.get_node("Fleet").drone("excavator")
	bank = w.get_node("Fleet").drone("excavation_tender")
	for node in [dig,dig.get_node("PaidWork"),w.get_node("PowerTether"),w.get_node("Territory"),w.get_node("DronePower"),w.get_node("Conditions"),w.get_node("LifeSupport"),w.get_node("Trace"),w.get_node("Weather"),w.get_node("Emissions"),w.get_node("Breaches")]: node.set_physics_process(false)
	await wait_physics_frames(2)
	assert_almost_eq(dig.jobs.values()[0].noise_clock,4.0,0.000001)
	var before: float = w.get_node("Trace").trace[0]
	tick(1)
	var pulses: Array = w.get_node("Emissions").pulses.filter(func(p): return p.kind=="drill")
	assert_eq(pulses.size(),1)
	assert_eq(pulses[0].at[1],-4.5)
	assert_almost_eq(w.get_node("Trace").trace[0]-before,1.8,0.000001)
