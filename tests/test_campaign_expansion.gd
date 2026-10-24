extends GutTest
## Provisioned mid-campaign fixtures: live timers/costs, not an earned campaign run.
const Scene = preload("res://scenes/drones/drone.tscn")
var session: Node
var w: Node
var net: Node
var heavy: Node
var tender: Node

func before_each() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = 1
	InputContext.menu_locked = false
	InputContext.set_context(InputContext.Context.WALK)
	session = load("res://scenes/ui/main_menu.tscn").instantiate()
	session.save_path = "user://tests/campaign_expansion_%d.json" % Time.get_ticks_usec()
	add_child_autofree(session)
	session.new_game()
	bind_world()
	for id in ["recovery","network","heavy","defense"]:
		w.get_node("Research").archives[id] = {"state":"delivered","carrier":""}
		w.get_node("Research").completed.append(id)
	w.get_node("Inventory").scrap = 1000
	hold_sunlight()
	await wait_physics_frames(2)

func bind_world() -> void:
	w = session.world
	net = w.get_node("Territory")
	heavy = w.get_node("Fleet").drone("expansion_heavy")
	tender = w.get_node("Fleet").drone("expansion_tender")

func hold_sunlight() -> void:
	w.get_node("Weather").force("sunlight")
	w.get_node("Weather").set_physics_process(false)

func after_each() -> void:
	Engine.time_scale = 1
	get_tree().paused = false
	InputContext.menu_locked = false
	InputContext.set_context(InputContext.Context.WALK)
	await wait_process_frames(2)

func make_hull(id: String, hull: String, at: Vector3) -> Node:
	var d: Node = Scene.instantiate()
	d.identity = id
	d.hull_id = hull
	d.battery = 12.0 if hull=="tender" else 0.2
	d.deployed = true
	d.position = at
	w.get_node("Fleet").add_child(d)
	return d

func convoy_fixture() -> void:
	heavy = make_hull("expansion_heavy","goliath",Vector3(-4,0.02,-17))
	tender = make_hull("expansion_tender","tender",Vector3(-4,0.02,-20.8))
	assert_true(heavy.install("tool","prefab_winch"))
	assert_true(tender.install("utility","power_coupler"))
	await wait_physics_frames(2)
	assert_true(w.get_node("PowerTether").attach(heavy.identity,tender.identity))

func at_site_fixture() -> void:
	# Haul geometry is covered by the driven band/convoy suites. This fixture
	# isolates live work and recovery after the convoy has arrived.
	heavy.position = net.pad(1)+Vector3(-4,0,0)
	tender.position = heavy.position+Vector3(0,0,3.8)
	await wait_physics_frames(2)

func finish_job() -> bool:
	for _frame in 5000:
		if net.job.is_empty(): return true
		if heavy.destroyed() or tender.destroyed():
			fail_test("Construction convoy destroyed before work finished")
			return false
		defend_convoy()
		await wait_physics_frames(1)
	return false

func defend_convoy() -> void:
	var relay: Node = w.get_node("Fleet").drone("mule_01")
	var sonar: Node = relay.get_node("Sonar")
	if sonar.clock-sonar.last_ping>1.0: sonar.ping()
	var defense: Node = w.get_node("Defense")
	for contact in defense.contacts(relay.identity):
		if not contact.id.begins_with("nest:") and defense.fire(relay.identity,contact.id): break

func test_live_paid_expansion_holds_on_tender_loss_and_reload_then_funds_fob() -> void:
	var relay: Node = w.get_node("Fleet").drone("mule_01")
	relay.remove_module("utility")
	relay.remove_module("tool")
	assert_true(relay.install("tool","sentry_mount"))
	assert_true(w.get_node("Defense").reload_ammo(relay.identity))
	assert_true(w.get_node("Defense").reload_ammo(relay.identity))
	assert_true(relay.install("utility","high_gain_dish"))
	relay.deployed = true
	relay.position = net.pad(1)+Vector3(0,0,3)
	relay.rotation.y = -PI/2 # Watch the approach scout's eastern patrol, in IR.
	await wait_physics_frames(2)
	assert_false(net.anchor(relay.identity,2))
	assert_true(net.anchor(relay.identity,1))
	await convoy_fixture()
	assert_true(net.load_prefab(heavy.identity,"pylon"))
	assert_eq(w.get_node("Inventory").scrap,900)
	await at_site_fixture()
	assert_true(net.construct(heavy.identity,1))
	Engine.time_scale = 8
	for _frame in 240:
		defend_convoy()
		await wait_physics_frames(1)
	assert_false(relay.destroyed(),"Sentry must survive to retain the forward link")
	assert_false(tender.destroyed(),"A dead tender cannot resume this construction")
	if relay.destroyed() or tender.destroyed(): return
	assert_lt(net.job.remaining,180.0)
	assert_lt(tender.battery,12.0)
	assert_true(w.get_node("PowerTether").release(heavy.identity))
	var remaining: float = net.job.remaining
	for _frame in 60:
		defend_convoy()
		await wait_physics_frames(1)
	assert_eq(net.job.remaining,remaining,"A disconnected convoy buys no construction time")
	Engine.time_scale = 1
	assert_true(session.save_current())
	assert_true(session.continue_game())
	bind_world()
	hold_sunlight()
	assert_almost_eq(float(net.job.remaining),remaining,0.000001)
	assert_eq(w.get_node("Inventory").scrap,900)
	assert_eq(heavy.cargo_kg,600.0)
	await wait_physics_frames(2)
	assert_true(w.get_node("PowerTether").attach(heavy.identity,tender.identity))
	Engine.time_scale = 8
	var finished: bool = await finish_job()
	assert_true(finished)
	if not finished: return
	assert_true(net.sites[1].pylon)
	assert_eq(heavy.cargo_kg,0.0)
	assert_false(net.construct(heavy.identity,1))
	assert_true(net.online(1))
	assert_true(net.wired(1))
	# Buy the second prefab through the home loader, then provision its arrival.
	heavy.position = Vector3(-4,0.02,-17)
	tender.position = Vector3(-4,0.02,-20.8)
	await wait_physics_frames(2)
	assert_true(net.load_prefab(heavy.identity,"fob"))
	assert_eq(w.get_node("Inventory").scrap,750)
	await at_site_fixture()
	assert_true(net.construct(heavy.identity,1))
	finished = await finish_job()
	assert_true(finished)
	if not finished: return
	assert_true(net.sites[1].fob)
	assert_gt(net.sites[1].battery,0.0,"Built banks charge through the paid live grid")
	assert_eq(heavy.cargo_kg,0.0)
	assert_lt(w.get_node("LifeSupport").fuel,120.0)
	Engine.time_scale = 1
	assert_true(session.save_current())
	var bank: float = net.sites[1].battery
	assert_true(session.continue_game())
	bind_world()
	assert_true(net.sites[1].fob)
	assert_almost_eq(float(net.sites[1].battery),bank,0.000001)
	assert_eq(w.get_node("Inventory").scrap,750)

func test_live_siege_paid_fence_preserves_bunker_and_saved_recovery() -> void:
	# Existing known-home pack at its rally: no spawn-rate/pacing assertion.
	net.sites[0].perimeter = true
	var defense: Node = w.get_node("Defense")
	defense.install_perimeter(0)
	var nest: Node = w.get_node("Trace").nests[0]
	nest.growth = 2
	nest.home_known = true
	nest.serial = 2
	for i in 2:
		var id := "nest_0_patrol_%d" % (i+1)
		var actor: Node = w.get_node("Threats").spawn(id,Vector3(-1.25 if i==0 else 1.25,0.02,-36),nest.position+Vector3(-5,0,0))
		actor.home = nest.position
		nest.population.append(id)
	await wait_physics_frames(2)
	assert_true(defense.set_fence(0,true))
	var fuel: float = w.get_node("LifeSupport").fuel
	Engine.time_scale = 4
	var attacked := false
	var siege: Node = w.get_node("Siege")
	for _frame in 1800:
		await wait_physics_frames(1)
		attacked = attacked or siege.phase=="attacking"
		if attacked and siege.phase=="idle": break
	assert_true(attacked)
	assert_eq(siege.phase,"idle")
	assert_gt(siege.cooldowns[0],0.0)
	assert_gt(defense.perimeters["0"].health[0],0.0)
	assert_lt(w.get_node("LifeSupport").fuel,fuel)
	assert_false(w.get_node("HumanSortie").dead)
	assert_false(w.get_node("LifeSupport").dead)
	Engine.time_scale = 1
	assert_true(session.save_current())
	var health: float = defense.perimeters["0"].health[0]
	var cooldown: float = siege.cooldowns[0]
	assert_true(session.continue_game())
	bind_world()
	assert_almost_eq(float(w.get_node("Defense").perimeters["0"].health[0]),health,0.000001)
	assert_almost_eq(float(w.get_node("Siege").cooldowns[0]),cooldown,0.000001)
	assert_eq(w.get_node("Siege").phase,"idle")
