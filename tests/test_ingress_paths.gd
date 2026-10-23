extends GutTest
const Schema = preload("res://scripts/persistence/save_schema.gd")
var session: Node
var w: Node
var b: Node
var r: Node
func before_each() -> void:
	Engine.time_scale = 1
	InputContext.menu_locked = false
	InputContext.set_context(InputContext.Context.WALK)
	process_mode = Node.PROCESS_MODE_ALWAYS
	session = load("res://scenes/ui/main_menu.tscn").instantiate()
	session.save_path = "user://tests/ingress_%d.json" % Time.get_ticks_usec()
	add_child_autofree(session)
	session.new_game()
	bind_world()
	w.get_node("Weather").current = "sunlight"
	w.get_node("Territory").sites[1].held = true
	w.get_node("Territory").sites[1].pylon = true
	w.get_node("Territory").sites[1].fob = true
	w.get_node("Excavation").restore({"segments":[{"kind":"tunnel","source":0,"target":1,"width":6.0,"depth":6.0,"height":3.2}],"rooms":{},"jobs":{},"next_serial":1})
	r.sync()
	await wait_physics_frames(2)
func bind_world() -> void:
	w = session.world
	for n in w.get_children(): n.set_physics_process(false)
	for actor in w.get_node("Threats").actors.values(): actor.set_physics_process(false)
	b = w.get_node("Breaches")
	r = w.get_node("Rail")
func after_each() -> void:
	Engine.time_scale = 1
	InputContext.menu_locked = false
	get_tree().paused = false
	InputContext.set_context(InputContext.Context.WALK)
	await wait_process_frames(2)
func actor_for(id: String) -> Node:
	var at: Vector3 = b.Portal.top(b.portals[id])+Vector3(-1.5,0.02,0)
	var actor: Node = w.get_node("Threats").spawn("ingress_fixture",at,at+Vector3(-5,0,0))
	actor.set_physics_process(false)
	return actor
func force_contact(id: String) -> void:
	for _i in 200:
		if b.entrances[id].forced: return
		b.advance(10)
	assert_true(false,"Existing contact must eventually force its seeded seal")
func test_only_finished_held_segments_get_fixed_chases_and_solid_outside_roofs() -> void:
	assert_eq(b.portals.size(),2)
	assert_eq(b.entrances.wall_0.condition,60.0)
	assert_eq(b.entrances.mouth_1.condition,100.0)
	assert_false(b.portals.has("mouth_2"))
	var layout: Dictionary = b.portals.mouth_1
	var x: float = layout.start+4.5
	var z: float = layout.row+3
	var hit: Dictionary = b.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,4,z),Vector3(x,-6,z),1))
	assert_false(hit.is_empty())
	assert_almost_eq(hit.position.y,1.1+0.12*sqrt(1.0+1.0/9.0),0.01,"A visible solid roof slab closes the outside face")
	var body := RigidBody3D.new()
	body.axis_lock_linear_x = true
	body.axis_lock_linear_z = true
	body.lock_rotation = true
	body.position = Vector3(x,4,z)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE*0.5
	collision.shape = shape
	body.add_child(collision)
	w.get_node("Surface").add_child(body)
	Engine.time_scale = 4
	await wait_physics_frames(45)
	assert_gt(body.position.y,1.2)
	assert_lt(body.position.y,1.65)
func test_mouth_forcing_produces_continuous_two_run_descent_into_owned_tunnel() -> void:
	w.get_node("Trace").trace[1] = 100
	var actor := actor_for("mouth_1")
	await wait_physics_frames(2)
	assert_true(b.contact(actor,"mouth_1"))
	var count: int = w.get_node("Threats").actors.size()
	force_contact("mouth_1")
	Engine.time_scale = 4
	w.get_node("Emissions").set_physics_process(true)
	actor.set_physics_process(true)
	for _i in 420:
		if b.routes.get(actor.identity,{}).get("stage",0)>=2: break
		await wait_physics_frames(1)
	actor.set_physics_process(false)
	assert_eq(w.get_node("Threats").actors.size(),count)
	assert_gte(int(b.routes.get(actor.identity,{}).get("stage",0)),2)
	assert_almost_eq(actor.position.y,-6.0,0.05)
	assert_lt(actor.position.x,float(b.portals.mouth_1.start))
	assert_true(b.network_inside(actor.position))
func test_unsealed_chase_stops_at_weakened_lining_before_forcing_it() -> void:
	w.get_node("Trace").trace[0] = 100
	var actor := actor_for("wall_0")
	await wait_physics_frames(2)
	Engine.time_scale = 4
	w.get_node("Emissions").set_physics_process(true)
	actor.set_physics_process(true)
	await wait_physics_frames(300)
	actor.set_physics_process(false)
	assert_false(b.entrances.wall_0.forced)
	assert_true(b.contact(actor,"wall_0"))
	assert_gt(actor.position.x,float(b.portals.wall_0.start))
	assert_lt(actor.position.y,-5.0)
	force_contact("wall_0")
	actor.set_physics_process(true)
	await wait_physics_frames(45)
	actor.set_physics_process(false)
	assert_true(b.network_inside(actor.position))
	assert_lt(actor.position.x,float(b.portals.wall_0.start))
func test_local_stock_and_port_power_control_field_service_and_lighting() -> void:
	var worker: Node = w.get_node("Fleet").drone("mule_01")
	worker.remove_module("tool")
	assert_true(worker.install("tool","torch"))
	worker.deployed = true
	worker.position = r.territory.pad(1)+Vector3(3,0,2)
	r.stock(1).scrap = 50
	var home: int = w.get_node("Inventory").scrap
	b._force("mouth_1")
	b.entrances.mouth_1.condition = 50
	await wait_physics_frames(2)
	assert_true(b.service("mouth_1",worker.identity,false))
	assert_eq(r.stock(1).scrap,32)
	assert_eq(w.get_node("Inventory").scrap,home)
	assert_almost_eq(worker.battery,0.98,0.000001)
	r.prepare()
	w.get_node("LifeSupport").advance(1)
	assert_gt(b.portal_views.mouth_1.lamp.light_energy,0.0)
	r.infrastructure.wires["0"] = 0
	r.prepare()
	assert_eq(b.portal_views.mouth_1.lamp.light_energy,0.0)
	assert_false(b.service("mouth_1",worker.identity,true))
func test_layout_and_mid_chase_route_reload_without_moving_actor_or_changing_paid_clock() -> void:
	w.get_node("Trace").trace[1] = 100
	var actor := actor_for("mouth_1")
	await wait_physics_frames(2)
	force_contact("mouth_1")
	Engine.time_scale = 4
	w.get_node("Emissions").set_physics_process(true)
	actor.set_physics_process(true)
	await wait_physics_frames(65)
	actor.set_physics_process(false)
	var at: Vector3 = actor.position
	var layouts: Dictionary = b.portals.duplicate(true)
	var route: Dictionary = b.routes[actor.identity].duplicate(true)
	assert_true(session.save_current(),Schema.validate(Schema.capture(w)))
	assert_true(session.continue_game())
	bind_world()
	actor = w.get_node("Threats").actors.ingress_fixture
	assert_true(actor.position.is_equal_approx(at))
	assert_eq(b.portals,layouts)
	assert_eq(int(b.routes[actor.identity].waypoint),int(route.waypoint))
	await wait_physics_frames(2)
	actor.set_physics_process(true)
	w.get_node("Emissions").set_physics_process(true)
	await wait_physics_frames(300)
	actor.set_physics_process(false)
	assert_gte(b.routes[actor.identity].stage,2)
	assert_true(b.network_inside(actor.position))
func test_service_ladder_climb_is_swept_saved_and_hatch_blocks_until_forced() -> void:
	r.car_built = true
	r.sync()
	var passenger: Node = w.get_node("Passenger")
	passenger.installed = true
	passenger.sync()
	b.sync()
	w.get_node("Operator").position = Vector3(4.3,0,1)
	var entry: Vector3 = b.Access.climb_position(9)
	var actor: Node = w.get_node("Threats").spawn("ladder_fixture",entry,entry)
	actor.set_physics_process(false)
	b.routes[actor.identity] = {"entry":"mouth_1","stage":2,"patrol":0,"waypoint":4,"navhub":-1,"climb":9.0}
	await wait_physics_frames(2)
	Engine.time_scale = 4
	w.get_node("Emissions").set_physics_process(true)
	actor.set_physics_process(true)
	await wait_physics_frames(55)
	actor.set_physics_process(false)
	var progress: float = b.routes[actor.identity].climb
	assert_lt(progress,9.0)
	assert_gt(progress,3.0)
	assert_true(session.save_current(),Schema.validate(Schema.capture(w)))
	assert_true(session.continue_game())
	bind_world()
	actor = w.get_node("Threats").actors.ladder_fixture
	assert_almost_eq(b.routes[actor.identity].climb,progress,0.000001)
	w.get_node("Emissions").set_physics_process(true)
	actor.set_physics_process(true)
	await wait_physics_frames(100)
	actor.set_physics_process(false)
	assert_almost_eq(b.routes[actor.identity].climb,3.0,0.02)
	assert_lt(actor.position.y,-1.4)
	w.get_node("Trace").trace[0] = 100
	assert_true(b.contact(actor,"service_hatch"))
	force_contact("service_hatch")
	actor.set_physics_process(true)
	await wait_physics_frames(65)
	actor.set_physics_process(false)
	assert_almost_eq(actor.position.y,0.0,0.05)
	assert_eq(b.routes[actor.identity].stage,3)
func test_local_pressure_roof_bounds_and_legacy_airlock_state_migrate() -> void:
	w.get_node("Trace").trace[0] = 0
	w.get_node("Trace").trace[1] = 100
	assert_gt(b.probability("mouth_1"),0.0)
	assert_eq(b.probability("wall_0"),0.0)
	var environment: Node = w.get_node("SurfaceEnvironment")
	var roof_count := 7
	for band in preload("res://resources/world/campaign.tres").bands: roof_count += band.shelters.size()
	assert_eq(environment.rain.mesh.material.get_shader_parameter("roof_count"),roof_count)
	var portals: Dictionary = b.portals.duplicate(true)
	b.entrances.airlock_outer.tier = 2
	b.entrances.airlock_outer.condition = 66.0
	var data := Schema.capture(w)
	data.version = 34
	data.breaches.erase("portals")
	for id in data.breaches.entrances.keys():
		if id not in b.IDS: data.breaches.entrances.erase(id)
	assert_eq(Schema.validate(data),"")
	Schema.restore(w,data)
	assert_eq(b.entrances.airlock_outer.tier,2)
	assert_eq(b.entrances.airlock_outer.condition,66.0)
	assert_eq(b.portals,portals)
	assert_eq(b.entrances.mouth_1.tier,0)
	assert_eq(b.entrances.wall_0.tier,0)
	assert_eq(Schema.validate(Schema.capture(w)),"")
func test_fixed_chase_volume_is_excluded_from_paid_widening_quotes_and_reload() -> void:
	var dig: Node = w.get_node("Excavation")
	var plan := {"kind":"tunnel","source":0,"target":1,"width":10.0,"depth":6.0,"height":3.2}
	var raw: Dictionary = dig.Plan.quote(plan,dig.grid)
	var quoted: Dictionary = dig.preview(plan)
	assert_lt(quoted.volume,raw.volume)
	assert_eq(quoted,dig.Plan.quote(plan,dig.grid,b.cleared_ranges()))
	var worker: Node = load("res://scenes/drones/drone.tscn").instantiate()
	worker.identity = "portal_quote_worker"
	worker.hull_id = "goliath"
	worker.battery = 0.2
	worker.deployed = true
	worker.position = Vector3(-4,0.02,-17)
	assert_true(worker.install("tool","drill"))
	w.get_node("Fleet").add_child(worker)
	dig.jobs["dig_000001"] = {"serial":1,"worker":worker.identity,"plan":plan,"seconds":quoted.seconds,"remaining":quoted.seconds,"scrap":quoted.scrap}
	dig.next_serial = 2
	var layouts: Dictionary = b.portals.duplicate(true)
	assert_true(dig.validate(dig.snapshot(),false,{},false),str(dig.snapshot()))
	assert_eq(Schema.validate(Schema.capture(w)),"")
	assert_true(session.save_current())
	assert_true(session.continue_game())
	bind_world()
	dig = w.get_node("Excavation")
	assert_eq(b.portals,layouts)
	assert_eq(dig.preview(plan),quoted)
	assert_eq(Schema.validate(Schema.capture(w)),"")
	# A v34 job was paid before chases existed. Keep its original paid time
	# through migration and another v35 save instead of rejecting the next save.
	var legacy := Schema.capture(w)
	legacy.version = 34
	legacy.breaches.erase("portals")
	for id in legacy.breaches.entrances.keys():
		if id not in b.IDS: legacy.breaches.entrances.erase(id)
	var job: Dictionary = legacy.excavation.jobs["dig_000001"]
	job.seconds = raw.seconds
	job.remaining = raw.seconds*0.5
	job.scrap = raw.scrap
	assert_eq(Schema.validate(legacy),"")
	Schema.restore(w,legacy)
	assert_eq(dig.jobs["dig_000001"].remaining,raw.seconds*0.5)
	assert_true(session.save_current())
	assert_true(session.continue_game())
	bind_world()
	dig = w.get_node("Excavation")
	assert_eq(dig.jobs["dig_000001"].seconds,raw.seconds)
	assert_eq(int(dig.jobs["dig_000001"].scrap),int(raw.scrap))
	var invalid: Dictionary = dig.snapshot()
	invalid.jobs["dig_000001"].scrap = 0
	assert_false(dig.validate(invalid,false,b.cleared_ranges()))
