extends GutTest
const Schema = preload("res://scripts/persistence/save_schema.gd")
const Kit = preload("res://scripts/world/surface_kit.gd")
var session: Node
var w: Node
var p: Node
var r: Node
var f: Node
var life: Node
var operator: CharacterBody3D
func before_each() -> void:
	InputContext.menu_locked = false
	InputContext.set_context(InputContext.Context.WALK)
	process_mode = Node.PROCESS_MODE_ALWAYS
	session = load("res://scenes/ui/main_menu.tscn").instantiate()
	session.save_path = "user://tests/passenger_%d.json" % Time.get_ticks_usec()
	add_child_autofree(session)
	session.new_game()
	bind_world()
	for i in [1,2]:
		w.get_node("Territory").sites[i].held = true
		w.get_node("Territory").sites[i].pylon = true
	var segments: Array = []
	for i in 2: segments.append({"kind":"tunnel","source":i,"target":i+1,"width":4.0,"depth":6.0,"height":2.4})
	w.get_node("Excavation").restore({"segments":segments,"rooms":{},"jobs":{},"next_serial":1})
	r.car_built = true
	r.sync()
	w.get_node("Inventory").scrap = 100
	life.generator_on = false
	life.fuel = 0
	life.battery = 2
	await wait_physics_frames(2)
func bind_world() -> void:
	w = session.world
	for n in w.get_children(): n.set_physics_process(false)
	p = w.get_node("Passenger")
	r = w.get_node("Rail")
	f = r.freight
	life = w.get_node("LifeSupport")
	operator = w.get_node("Operator")
func after_each() -> void:
	InputContext.menu_locked = false
	get_tree().paused = false
	InputContext.set_context(InputContext.Context.WALK)
	await wait_process_frames(2)
func retrofit() -> void:
	assert_true(p.construct())
	life.advance(90)
	assert_true(p.installed)
	await wait_physics_frames(2)
func at_station(hub: int) -> void:
	operator.position = r.at(hub)+Vector3(1.05,0.03,1.25)
	await wait_physics_frames(2)
func board_home() -> void:
	await at_station(0)
	assert_true(p.call_car(0))
	f.advance(0.1)
	assert_eq(p.phase,"waiting")
	assert_true(p.board())
func tick(count: int = 1) -> void:
	for _i in count:
		f.advance(1)
		r.prepare()
		life.advance(1)
func arrive() -> void:
	for _i in 300:
		if p.phase in ["arrived","waiting"]: return
		tick()
	assert_true(false,"Passenger must actually reach its destination")
func test_retrofit_requires_existing_car_and_exact_fresh_payment() -> void:
	r.car_built = false
	assert_false(p.construct())
	assert_eq(w.get_node("Inventory").scrap,100)
	r.car_built = true
	assert_true(p.construct())
	assert_false(p.construct())
	assert_eq(w.get_node("Inventory").scrap,75)
	life.battery = 0
	life.supplied_fraction = 1
	life.advance(5)
	assert_eq(p.remaining,90.0)
	life.battery = life.load_kw()/3600.0*0.5
	life.advance(1)
	assert_almost_eq(p.remaining,89.5,0.000001)
	life.battery = 2
	life.advance(90)
	assert_true(p.installed)
	assert_eq(p.remaining,0.0)
	assert_eq(w.get_node("Inventory").scrap,75)
	assert_almost_eq(life.passenger_load_kw,0.04,0.000001)
	assert_not_null(r.car_view.get_node("PassengerSeat/CarCollision"))
func test_sealed_access_climb_has_real_floor_join_and_safe_bunker_return() -> void:
	await retrofit()
	operator.position = Vector3(0,0,6.5)
	assert_true(p.start_climb(true))
	assert_true(operator.transport_locked)
	p.advance_climb(5)
	assert_almost_eq(operator.position.y,-2.5,0.00001)
	assert_eq(operator.position.z,8.0)
	assert_eq(Schema.validate(Schema.capture(w)),"")
	p.advance_climb(10)
	assert_eq(operator.position,Vector3(0,-6,6.5))
	assert_false(operator.transport_locked)
	assert_eq(p.climb,-1.0)
	var floor := operator.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(operator.position+Vector3(0,0.3,0),operator.position-Vector3(0,0.3,0),1,[operator.get_rid()]))
	assert_false(floor.is_empty())
	var join := operator.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,-4.5,6.5),Vector3(0,-4.5,-14),1,[operator.get_rid()]))
	assert_true(join.is_empty(),"No hidden collision wall between access passage and actual rail hub")
	assert_true(p.start_climb(false))
	p.advance_climb(12)
	assert_eq(operator.position,Vector3(0,0,6.5))
	assert_false(operator.transport_locked)
	operator.set_physics_process(true)
	await wait_physics_frames(5)
	assert_true(operator.is_on_floor())
	assert_almost_eq(operator.position.y,0.0,0.01)
	assert_true(w.get_node("Bunker/Airlock").opened_side.is_empty())
func test_two_hub_trip_preserves_camera_collision_and_no_surface_costs() -> void:
	await retrofit()
	var suit: Dictionary = w.get_node("HumanSortie").snapshot()
	await board_home()
	var layer := operator.collision_layer
	var mask := operator.collision_mask
	var camera: Node = operator.get_node("Head")
	camera.apply_look(Vector2(24,-12))
	var pitch: float = camera.rotation.x
	var yaw: float = operator.rotation.y
	var car_yaw: float = r.car_view.rotation.y
	assert_true(p.travel(1))
	tick(2)
	assert_gt(f.coordinate,0.0)
	assert_lt(operator.position.y,-5.0)
	assert_true(operator.position.is_equal_approx(p.seat_position()))
	assert_false(p.disembark())
	arrive()
	assert_eq(p.phase,"arrived")
	assert_almost_eq(wrapf(operator.rotation.y-r.car_view.rotation.y,-PI,PI),wrapf(yaw-car_yaw,-PI,PI),0.0001,"Track turns preserve the rider's look offset")
	assert_eq(camera.rotation.x,pitch)
	assert_true(p.disembark())
	assert_eq(operator.collision_layer,layer)
	assert_eq(operator.collision_mask,mask)
	assert_false(operator.transport_locked)
	assert_eq(w.get_node("HumanSortie").snapshot(),suit)
	assert_false(w.get_node("Bunker/Airlock").outer_authorized)
	assert_eq(Schema.validate(Schema.capture(w)),"")
func test_loaded_freight_finishes_before_call_then_waits_for_local_boarding() -> void:
	await retrofit()
	assert_true(f.add_rule(0,1,"scrap",10,10))
	tick()
	assert_eq(f.job.cargo.amount,10.0)
	await at_station(0)
	assert_true(p.call_car(0))
	assert_false(p.board())
	assert_eq(f.job.cargo.amount,10.0)
	arrive()
	assert_eq(r.stock(1).scrap,10)
	assert_eq(p.phase,"waiting")
	assert_almost_eq(f.coordinate,0.0,0.000001)
	assert_true(p.board())
	assert_true(f.job.is_empty())
	assert_true(p.disembark())
	assert_eq(p.phase,"idle")
func test_station_occupancy_holds_rider_and_clearance_restores_disembarkation() -> void:
	await retrofit()
	await board_home()
	assert_true(p.travel(1))
	arrive()
	var blockers: Array = []
	for offset in [Vector3(1.05,0,-1.25),Vector3(-1.05,0,-1.25),Vector3(1.05,0,1.25),Vector3(-1.05,0,1.25)]:
		blockers.append(Kit.box(w.get_node("Surface"),"OccupiedExit",Vector3(0.7,1.8,0.7),r.at(1)+offset+Vector3(0,0.9,0),"metal"))
	await wait_physics_frames(2)
	assert_false(p.disembark())
	assert_true(p.aboard)
	assert_true(operator.transport_locked)
	var first: Node = blockers.pop_front()
	first.get_parent().remove_child(first)
	first.queue_free()
	await wait_physics_frames(2)
	assert_true(p.disembark())
	assert_false(operator.transport_locked)
func test_blackout_pauses_ride_after_actual_reserve_and_weather_does_not_cut_wire() -> void:
	await retrofit()
	await board_home()
	assert_true(p.travel(1))
	tick()
	life.battery = 0
	f.advance(1)
	r.prepare()
	life.advance(3)
	var at: float = f.coordinate
	f.advance(5)
	assert_eq(f.coordinate,at)
	assert_true(p.aboard)
	life.battery = 2
	w.get_node("Weather").current = "aurora"
	w.get_node("Radio").drops = {"pylon_1":100.0}
	arrive()
	assert_eq(p.phase,"arrived")
	assert_true(p.disembark())
func test_save_riding_and_climbing_restores_pose_credit_and_no_duplicate_freight() -> void:
	await retrofit()
	await board_home()
	assert_true(p.travel(1))
	tick(10)
	operator.get_node("Head").apply_look(Vector2(18,9))
	var at: Vector3 = operator.position
	var credit: float = f.credit
	var yaw: float = operator.rotation.y
	var pitch: float = operator.get_node("Head").rotation.x
	assert_true(session.save_current(),session.menu.subtitle.text)
	assert_true(session.continue_game())
	bind_world()
	assert_true(p.aboard)
	assert_true(operator.transport_locked)
	assert_true(operator.position.is_equal_approx(at))
	assert_almost_eq(f.credit,credit,0.00000001)
	assert_almost_eq(operator.rotation.y,yaw,0.000001)
	assert_almost_eq(operator.get_node("Head").rotation.x,pitch,0.000001)
	assert_true(f.job.is_empty())
	arrive()
	assert_true(p.disembark())
	operator.position = Vector3(0,0,6.5)
	assert_true(p.start_climb(true))
	p.advance_climb(4)
	var progress: float = p.climb
	assert_true(session.save_current())
	assert_true(session.continue_game())
	bind_world()
	assert_almost_eq(p.climb,progress,0.000001)
	assert_true(operator.transport_locked)
	p.advance_climb(10)
	assert_false(operator.transport_locked)
	assert_eq(operator.position,Vector3(0,-6,6.5))
func test_malformed_pose_suit_unknown_hub_and_legacy_save_receive_no_free_ride() -> void:
	await retrofit()
	await board_home()
	assert_false(p.travel(3))
	var data := Schema.capture(w)
	assert_eq(Schema.validate(data),"")
	var bad := data.duplicate(true)
	bad.operator.position[2] += 30
	assert_false(Schema.validate(bad).is_empty())
	bad = data.duplicate(true)
	bad.human_sortie.active = true
	bad.airlock.outer_authorized = true
	assert_false(Schema.validate(bad).is_empty())
	bad = data.duplicate(true)
	bad.passenger.goal = 5
	assert_false(Schema.validate(bad).is_empty())
	var old := data.duplicate(true)
	old.version = 31
	old.erase("passenger")
	old.operator.position = [0,0,6.5]
	assert_eq(Schema.validate(old),"")
	Schema.restore(w,old)
	assert_false(p.installed)
	assert_false(p.aboard)
	assert_false(operator.transport_locked)
	assert_null(p.access)
	assert_eq(w.get_node("Inventory").scrap,75)
func test_local_controls_reject_remote_use_and_panels_fit_actual_framebuffer() -> void:
	await retrofit()
	assert_false(p.call_car(1))
	await at_station(0)
	var control: Node3D = r.stations[0].get_node("PassengerPlatform/RideControl")
	operator.get_node("Head").look_at(control.global_position)
	await wait_physics_frames(2)
	var interaction: Node = operator.get_node("Interactor")
	assert_true(interaction.use_target())
	var ui: Node = w.get_node("PassengerPanel")
	assert_true(ui.panel.visible)
	await wait_process_frames(3)
	assert_lte(ui.panel.get_combined_minimum_size().x,640.0)
	assert_lte(ui.panel.get_combined_minimum_size().y,480.0)
	assert_lte(ui.panel.get_child(0).get_child(0).get_child(-1).get_global_rect().end.y,480.0)
func test_swept_car_clearance_holds_before_track_obstacle_without_spending_reserve() -> void:
	await retrofit()
	await board_home()
	var block: Node = Kit.box(w.get_node("Surface"),"TrackObstruction",Vector3(3,2,1),f.position_at(4.5)+Vector3(0,1,0),"metal")
	await wait_physics_frames(2)
	assert_true(p.travel(1))
	tick(4)
	assert_lt(f.coordinate,4.5)
	var at: float = f.coordinate
	var credit: float = f.credit
	tick(3)
	assert_eq(f.coordinate,at)
	assert_eq(f.credit,credit)
	block.get_parent().remove_child(block)
	block.queue_free()
	await wait_physics_frames(2)
	arrive()
	assert_true(p.disembark())
func test_menu_pause_stops_real_rail_and_ladder_motion() -> void:
	await retrofit()
	await board_home()
	assert_true(p.travel(1))
	tick()
	r.set_physics_process(true)
	p.set_physics_process(true)
	life.set_physics_process(true)
	InputContext.set_context(InputContext.Context.MENU)
	var at: float = f.coordinate
	var credit: float = f.credit
	await wait_physics_frames(4)
	assert_eq(f.coordinate,at)
	assert_eq(f.credit,credit)
	InputContext.set_context(InputContext.Context.WALK)
	await wait_physics_frames(4)
	assert_gt(f.coordinate,at)
	r.set_physics_process(false)
	p.set_physics_process(false)
	life.set_physics_process(false)
	f.coordinate = f.distance_to_hub(1)
	f.update_view()
	p.phase = "arrived"
	p._sync_rider()
	assert_true(p.disembark())
	operator.position = Vector3(0,0,6.5)
	assert_true(p.start_climb(true))
	p.set_physics_process(true)
	InputContext.set_context(InputContext.Context.MENU)
	var progress: float = p.climb
	await wait_physics_frames(4)
	assert_eq(p.climb,progress)
	InputContext.set_context(InputContext.Context.WALK)
	await wait_physics_frames(4)
	assert_gt(p.climb,progress)
func test_underground_camera_and_rain_stay_inside_the_sealed_environment() -> void:
	await retrofit()
	await board_home()
	operator.position = Vector3(8,-5.4,-125)
	w.get_node("Weather").current = "rain"
	var environment: Node = w.get_node("SurfaceEnvironment")
	environment._update()
	environment._physics_process(0)
	assert_null(operator.get_node("Head/Camera").environment)
	var duration: float = environment.rain.lifetime
	assert_gte(environment.rain.global_position.y-environment.rain.initial_velocity_max*duration+0.5*environment.rain.gravity.y*duration*duration,0.0,"Include gravity when bounding streaks above sealed rooms")
	operator.position.y = 0
	environment._physics_process(0)
	assert_not_null(operator.get_node("Head/Camera").environment,"The same northern position is exterior only when actually above ground")
	operator.position = Vector3(0,0,8)
	environment._physics_process(0)
	var drift: float = sin(deg_to_rad(environment.rain.spread))*environment.rain.initial_velocity_max*duration
	assert_lt(environment.rain.global_position.z+environment.rain.emission_box_extents.z+drift,-10.0,"The rain volume and its horizontal drift remain outside the bunker roof")
	assert_null(operator.get_node("Head/Camera").environment)
func test_passenger_headlamp_requires_fresh_fractional_grid_power() -> void:
	await retrofit()
	await board_home()
	var lamp: Node = r.car_view.get_node("PassengerSeat/Headlamp")
	assert_eq(lamp.light_energy,0.0)
	assert_almost_eq(life.passenger_load_kw,0.09,0.000001)
	life.battery = 0
	life.supplied_fraction = 1
	life.advance(2)
	assert_eq(lamp.light_energy,0.0)
	life.battery = life.load_kw()/3600.0*0.5
	life.advance(1)
	assert_almost_eq(lamp.light_energy,2.0,0.000001)
	life.battery = 2
	life.advance(1)
	assert_eq(lamp.light_energy,4.0)
	assert_true(p.disembark())
	assert_eq(lamp.light_energy,0.0)
	assert_almost_eq(life.passenger_load_kw,0.04,0.000001)
func test_access_volume_is_not_billed_twice_and_saved_job_uses_its_paid_baseline() -> void:
	await retrofit()
	var dig: Node = w.get_node("Excavation")
	var plan := {"kind":"room","source":0,"target":0,"width":20.0,"depth":20.0,"height":3.2}
	var raw: Dictionary = dig.Plan.quote(plan,dig.grid)
	var quoted: Dictionary = dig.preview(plan)
	var expected: Dictionary = dig.Plan.quote(plan,p.Access.corridor(dig.grid))
	assert_lt(quoted.volume,raw.volume,"Already commissioned access is cleared volume")
	assert_eq(quoted,expected)
	var worker: Node = load("res://scenes/drones/drone.tscn").instantiate()
	worker.identity = "access_quote_worker"
	worker.hull_id = "goliath"
	worker.battery = 0.2
	worker.deployed = true
	worker.position = Vector3(-4,0.02,-17)
	assert_true(worker.install("tool","drill"))
	w.get_node("Fleet").add_child(worker)
	# A valid paid-job snapshot fixture isolates the pricing/save baseline.
	dig.jobs["dig_000001"] = {"serial":1,"worker":worker.identity,"plan":plan,"seconds":quoted.seconds,"remaining":quoted.seconds,"scrap":quoted.scrap}
	dig.next_serial = 2
	assert_true(dig.validate(dig.snapshot(),true))
	assert_false(dig.validate(dig.snapshot(),false))
	assert_eq(Schema.validate(Schema.capture(w)),"")
	assert_true(session.save_current())
	assert_true(session.continue_game())
	bind_world()
	dig = w.get_node("Excavation")
	assert_eq(dig.preview(plan),expected)
	assert_almost_eq(dig.jobs.dig_000001.remaining,quoted.seconds,0.000001)
	assert_eq(Schema.validate(Schema.capture(w)),"")
func test_access_commissioning_excludes_overlapping_jobs_but_allows_field_jobs() -> void:
	var dig: Node = w.get_node("Excavation")
	var home := {"kind":"room","source":0,"target":0,"width":6.0,"depth":6.0,"height":3.2}
	dig.jobs = {"fixture":{"plan":home,"worker":"fixture_worker"}}
	assert_false(p.construct())
	assert_eq(w.get_node("Inventory").scrap,100)
	var field := home.duplicate()
	field.source = 1
	field.target = 1
	dig.jobs.fixture.plan = field
	assert_true(p.construct(),"A non-overlapping field job does not block home access")
	dig.jobs.clear()
	assert_false(dig.request("no_worker","room",0,0,6,6,3.2))
	assert_true("commissioned" in dig.status)
	assert_eq(w.get_node("Inventory").scrap,75)
func test_headlamp_follows_both_travel_directions_with_one_paid_light() -> void:
	await retrofit()
	await board_home()
	assert_true(p.travel(1))
	var lamp: Node3D = r.car_view.get_node("PassengerSeat/Headlamp")
	assert_lt(lamp.position.z,0.0)
	arrive()
	assert_true(p.travel(0))
	assert_gt(lamp.position.z,0.0)
	assert_almost_eq(absf(lamp.rotation.y),PI,0.000001)
	assert_almost_eq(life.passenger_load_kw,0.09,0.000001,"Only one 50W travelling beam is powered")
	arrive()
	assert_true(p.disembark())
