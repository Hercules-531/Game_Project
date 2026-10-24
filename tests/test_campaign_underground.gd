extends GutTest
## Live underground operations from declared, provisioned campaign prerequisites.
const Scene = preload("res://scenes/drones/drone.tscn")
var session: Node
var w: Node
var dig: Node
var rail: Node
var heavy: Node
var tender: Node
var guard: Node

func before_each() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = 1
	InputContext.menu_locked = false
	InputContext.set_context(InputContext.Context.WALK)
	session = load("res://scenes/ui/main_menu.tscn").instantiate()
	session.save_path = "user://tests/campaign_underground_%d.json" % Time.get_ticks_usec()
	add_child_autofree(session)
	session.new_game()
	bind_world()
	for id in ["recovery","network","heavy","excavation","defense"]:
		w.get_node("Research").completed.append(id)
		w.get_node("Research").archives[id] = {"state":"delivered","carrier":""}
	w.get_node("Inventory").scrap = 1000
	w.get_node("Weather").force("sunlight")
	w.get_node("Weather").set_physics_process(false)
	w.get_node("Territory").sites[1].held = true
	w.get_node("Territory").sites[1].pylon = true
	w.get_node("Territory").sites[1].battery = 1.0
	w.get_node("Territory").sites[1].perimeter = true
	w.get_node("Defense").install_perimeter(1)
	w.get_node("Defense").set_fence(1,true)
	w.get_node("Territory").sites[0].perimeter = true
	w.get_node("Defense").install_perimeter(0)
	w.get_node("Defense").set_fence(0,true)
	await wait_physics_frames(2)

func bind_world() -> void:
	w = session.world
	dig = w.get_node("Excavation")
	rail = w.get_node("Rail")
	heavy = w.get_node("Fleet").drone("campaign_digger")
	tender = w.get_node("Fleet").drone("campaign_bank")

func after_each() -> void:
	Engine.time_scale = 1
	get_tree().paused = false
	InputContext.menu_locked = false
	InputContext.set_context(InputContext.Context.WALK)
	await wait_process_frames(2)

func convoy(tool: String) -> void:
	heavy = Scene.instantiate()
	heavy.identity = "campaign_digger"
	heavy.hull_id = "goliath"
	heavy.deployed = true
	heavy.battery = 0.2
	heavy.position = Vector3(-4,0.02,-17)
	assert_true(heavy.install("tool",tool))
	w.get_node("Fleet").add_child(heavy)
	tender = Scene.instantiate()
	tender.identity = "campaign_bank"
	tender.hull_id = "tender"
	tender.deployed = true
	tender.battery = 12.0
	tender.position = Vector3(-4,0.02,-20.8)
	assert_true(tender.install("utility","power_coupler"))
	w.get_node("Fleet").add_child(tender)
	await wait_physics_frames(2)
	assert_true(w.get_node("PowerTether").attach(heavy.identity,tender.identity))

func finish_dig() -> bool:
	for _frame in 6000:
		if dig.jobs.is_empty(): return true
		if heavy.destroyed() or tender.destroyed(): return false
		await live_frame()
	return false

func live_frame() -> void:
	if is_instance_valid(guard) and not guard.destroyed():
		var sonar: Node = guard.get_node("Sonar")
		if sonar.clock-sonar.last_ping>1.0: sonar.ping()
		for target in w.get_node("Defense").contacts(guard.identity):
			if not target.id.begins_with("nest:") and w.get_node("Defense").fire(guard.identity,target.id): break
	await wait_physics_frames(1)

func guard_fixture() -> void:
	guard = Scene.instantiate()
	guard.identity = "campaign_guard"
	guard.hull_id = "tracked"
	guard.battery = 2.0
	guard.position = Vector3(8,0.02,-122)
	guard.rotation.y = -PI/2 # Guard the forward rail mouth and eastern approach.
	assert_true(guard.install("sensor_a","sonar"))
	assert_true(guard.install("sensor_b","ccd"))
	assert_true(guard.install("tool","sentry_mount"))
	w.get_node("Fleet").add_child(guard)
	assert_true(w.get_node("Defense").reload_ammo(guard.identity))
	assert_true(w.get_node("Defense").reload_ammo(guard.identity))
	guard.deployed = true

func test_live_excavation_freight_maintenance_and_passenger_trip_keep_paid_costs() -> void:
	await underground_route(false)

func test_unsafe_active_nests_can_breach_during_aurora_and_reload_keeps_last_save() -> void:
	await underground_route(true)

func underground_route(unsafe: bool) -> void:
	# Compare a declared secured-territory midpoint with the same operation
	# under active nest recruitment. Residual actors keep their live controllers.
	if not unsafe:
		for band in [0,1]: w.get_node("Trace").nests[band].apply_damage(1000)
	await convoy("drill")
	await guard_fixture()
	assert_false(dig.request(heavy.identity,"tunnel",0,2,4,6,2.4))
	assert_true(dig.request(heavy.identity,"room",0,0,6,6,3.2))
	var paid: int = w.get_node("Inventory").scrap
	assert_lt(paid,1000)
	Engine.time_scale = 8
	var finished: bool = await finish_dig()
	assert_true(finished)
	if not finished: return
	assert_true(dig.rooms.has("0"))
	assert_true(dig.request(heavy.identity,"tunnel",0,1,4,6,2.4))
	finished = await finish_dig()
	assert_true(finished)
	if not finished: return
	assert_eq(dig.segments.size(),1)
	assert_eq(rail.hub_count(),2)
	assert_lt(tender.battery,12.0)
	assert_true(rail.construct_car())
	for _frame in 1800:
		if rail.car_built: break
		await live_frame()
	assert_true(rail.car_built)
	if not rail.car_built: return
	var inv: Node = w.get_node("Inventory")
	paid = inv.scrap
	assert_true(rail.freight.add_rule(0,1,"scrap",10,10))
	# Actual aurora disables wireless while healthy wired freight keeps moving.
	w.get_node("Weather").force("aurora")
	for _frame in 1800:
		if rail.stock(1).scrap==10: break
		await live_frame()
	assert_eq(rail.stock(1).scrap,10)
	assert_eq(inv.scrap,paid-10)
	assert_lt(rail.conditions["0"],100.0,"Actual freight metres wear this track")
	assert_eq(w.get_node("Radio").range_multiplier,0.0)
	assert_true(rail.connected(1))
	var worker: Node = w.get_node("Fleet").drone("mule_01")
	worker.remove_module("tool")
	assert_true(worker.install("tool","torch"))
	paid = inv.scrap
	assert_true(rail.infrastructure.request("rail",0,worker.identity))
	assert_lt(inv.scrap,paid)
	for _frame in 1800:
		if rail.infrastructure.jobs.is_empty(): break
		await live_frame()
	assert_true(rail.infrastructure.jobs.is_empty())
	assert_eq(rail.conditions["0"],100.0)
	var passenger: Node = w.get_node("Passenger")
	assert_true(passenger.construct())
	for _frame in 1800:
		if passenger.installed: break
		await live_frame()
	assert_true(passenger.installed)
	assert_true(session.save_current(),session.menu.subtitle.text)
	print("UNDERGROUND_BEFORE_BOARDING / ",session.save_path)
	# Fixture arrival at the home station excludes access-passage walking.
	w.get_node("Operator").position = rail.at(0)+Vector3(1.05,0.03,1.25)
	await wait_physics_frames(2)
	assert_true(passenger.call_car(0))
	for _frame in 1800:
		if passenger.phase=="waiting": break
		if get_tree().paused: break
		await live_frame()
	if unsafe:
		assert_true(w.get_node("HumanSortie").dead,"Active nests plus an unsealed rail mouth are a real operator risk")
		assert_true(get_tree().paused)
		assert_true(session.continue_game(),"Death retains the valid pre-boarding save")
		bind_world()
		assert_false(w.get_node("HumanSortie").dead)
		assert_false(w.get_node("LifeSupport").dead)
		return
	assert_eq(passenger.phase,"waiting")
	if passenger.phase!="waiting":
		print("PASSENGER_DIAGNOSTIC / ",{"operator":w.get_node("Operator").position,"coordinate":rail.freight.coordinate,"credit":rail.freight.credit,"status":passenger.status,"menu":session.menu.subtitle.text,"human_reason":w.get_node("HumanSortie").reason,"life":w.get_node("LifeSupport").snapshot()})
		return
	assert_true(passenger.board())
	assert_true(passenger.travel(1))
	for _frame in 1800:
		if passenger.phase=="arrived": break
		await live_frame()
	assert_eq(passenger.phase,"arrived")
	assert_lt(w.get_node("Operator").position.y,-5.0)
	assert_false(w.get_node("HumanSortie").active)
	assert_true(passenger.disembark())
	assert_false(w.get_node("Operator").transport_locked)
	Engine.time_scale = 1
	assert_true(session.save_current())
	paid = inv.scrap
	var fuel: float = w.get_node("LifeSupport").fuel
	assert_true(session.continue_game())
	bind_world()
	assert_eq(w.get_node("Inventory").scrap,paid)
	assert_eq(rail.stock(1).scrap,10)
	assert_true(rail.car_built)
	assert_true(w.get_node("Passenger").installed)
	assert_eq(dig.segments.size(),1)
	assert_almost_eq(w.get_node("LifeSupport").fuel,fuel,0.000001)

func test_final_paid_perimeter_repair_rolls_and_persists_credits_once() -> void:
	await convoy("prefab_winch")
	for band in 6:
		w.get_node("Territory").sites[band].held = true
		w.get_node("Territory").sites[band].perimeter = true
		w.get_node("Defense").install_perimeter(band)
		w.get_node("Trace").nests[band].apply_damage(1000)
	for actor in w.get_node("Threats").actors.values(): actor.apply_damage(1000)
	var defense: Node = w.get_node("Defense")
	defense.perimeters["0"].health[0] = 0.0
	var tracker: Node = w.get_node("Restoration")
	assert_false(tracker.evaluate(),"One open section prevents restoration")
	var paid: int = w.get_node("Inventory").scrap
	assert_true(defense.repair_perimeter(heavy.identity,0))
	assert_eq(w.get_node("Inventory").scrap,paid-20)
	assert_true(tracker.evaluate())
	assert_true(session.ending_open)
	assert_true(get_tree().paused)
	assert_true(tracker.credits_seen)
	assert_eq(session.get_node("Credits").automatic_presentations,1)
	session._resume_after_credits()
	assert_true(session.continue_game())
	bind_world()
	assert_true(w.get_node("Restoration").completed)
	assert_true(w.get_node("Restoration").credits_seen)
	assert_false(session.ending_open)
	assert_eq(session.get_node("Credits").automatic_presentations,1)
	assert_eq(w.get_node("Inventory").scrap,paid-20)
