extends GutTest
const Schema = preload("res://scripts/persistence/save_schema.gd")
var w: Node
var siege: Node
var nest: Node
var defense: Node
func before_each() -> void:
	InputContext.menu_locked = false
	InputContext.set_context(InputContext.Context.WALK)
	w = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(w)
	siege = w.get_node("Siege")
	nest = w.get_node("Trace").nests[0]
	defense = w.get_node("Defense")
	for node in [siege,w.get_node("Trace"),w.get_node("Weather"),w.get_node("LifeSupport")]: node.set_physics_process(false)
	w.get_node("Weather").current = "sunlight"
	await wait_physics_frames(2)
func after_each() -> void:
	InputContext.menu_locked = false
	InputContext.set_context(InputContext.Context.MENU)
	await wait_process_frames(2)
func pack(at_z: float = -42) -> void:
	nest.growth = 2
	nest.home_known = true
	nest.serial = 2
	for i in 2:
		var id := "nest_0_patrol_%d" % (i+1)
		var actor: Node = w.get_node("Threats").spawn(id,Vector3(-1.25 if i==0 else 1.25,0.02,at_z),nest.position+Vector3(-5,0,0))
		actor.home = nest.position
		nest.population.append(id)
	await wait_physics_frames(2)
func fence() -> void:
	w.get_node("Territory").sites[0].perimeter = true
	defense.install_perimeter(0)
	await wait_physics_frames(2)
func test_knowledge_and_existing_population_gate_real_formation() -> void:
	siege.advance(100)
	assert_eq(siege.phase,"idle")
	await pack(-60)
	nest.home_known = false
	siege.advance(1)
	assert_eq(siege.phase,"idle","No pinpointed bunker, no coordinated attack")
	nest.home_known = true
	var count: int = w.get_node("Threats").actors.size()
	siege.advance(1)
	assert_eq(siege.phase,"forming")
	assert_eq(siege.roster.size(),2)
	assert_eq(w.get_node("Threats").actors.size(),count,"Orders create no free enemy reinforcements")
	var actor: Node = w.get_node("Threats").actors[siege.roster[0]]
	var before: Vector3 = actor.position
	siege.advance(12)
	assert_eq(siege.phase,"forming","Timer alone cannot teleport the pack into formation")
	await wait_physics_frames(120)
	assert_gt(actor.position.distance_to(before),3.0)
	assert_eq(actor.mode,"siege")
	assert_ne(siege.goal(siege.roster[0]).at,siege.goal(siege.roster[1]).at,"Separate physical rally slots")
func test_unpowered_barrier_is_struck_destroyed_and_crossed() -> void:
	await fence()
	await pack(-36)
	siege.advance(1)
	siege.advance(12)
	assert_eq(siege.phase,"attacking")
	await wait_physics_frames(600)
	assert_eq(defense.perimeters["0"].health[0],0.0,"Actual pack strikes destroy neglected fence")
	var crossed := false
	for id in siege.roster: crossed = crossed or w.get_node("Threats").actors[id].position.z>-30
	assert_true(crossed,"Actual bodies advance through the broken north barrier")
	assert_true(defense.status.contains("SECTION 1 STRUCK"))
	assert_eq(w.get_node("LifeSupport").defense_load_kw,0.0)
func test_paid_fence_defeats_same_pack_without_free_power() -> void:
	await fence()
	await pack(-36)
	siege.advance(1)
	siege.advance(12)
	defense.set_fence(0,true)
	var life: Node = w.get_node("LifeSupport")
	life.set_physics_process(true)
	var battery: float = life.battery
	await wait_physics_frames(480)
	siege.advance(0.01)
	assert_eq(siege.phase,"idle","No surviving pack, siege finishes")
	assert_gt(defense.perimeters["0"].health[0],0.0)
	assert_lt(life.battery,battery,"Finite grid energy pays for the defended result")
	assert_gt(siege.cooldowns[0],0.0)
	assert_eq(w.get_node("Threats").actors.size(),3,"Corpses retained until nest's ordinary recruitment cycle")
func test_rain_clear_loss_and_saved_coordination_restore() -> void:
	await pack(-36)
	siege.advance(1)
	siege.advance(12)
	var data := JSON.parse_string(JSON.stringify(Schema.capture(w))) as Dictionary
	assert_eq(Schema.validate(data),"")
	Schema.restore(w,data)
	assert_eq(siege.phase,"attacking")
	assert_eq(siege.remaining,180.0)
	assert_eq(siege.roster,nest.population)
	var first: String = siege.roster[0]
	assert_eq(w.get_node("Threats").actors[first].home,nest.position)
	w.get_node("Weather").current = "rain"
	siege.advance(1)
	assert_eq(siege.phase,"retreat")
	assert_eq(siege.goal(first).at.z,nest.position.z+3)
	siege.advance(45)
	assert_eq(siege.phase,"idle")
	assert_eq(siege.cooldowns[0],300.0)
	siege.advance(100)
	assert_eq(siege.phase,"idle","Per-nest cooldown prevents repeated instant raids")
	w.get_node("Weather").current = "sunlight"
	siege.advance(201)
	assert_eq(siege.phase,"forming")
	nest.apply_damage(10000)
	siege.advance(1)
	assert_eq(siege.phase,"retreat","Clearing the source interrupts its coordinated pressure")
func test_old_home_target_migrates_and_invalid_roster_rejected() -> void:
	await pack(-36)
	siege.advance(1)
	var old := Schema.capture(w)
	old.version = 25
	old.erase("siege")
	for record in old.threats:
		if record.id in nest.population: record.home = [0,0.02,-18]
	assert_eq(Schema.validate(old),"")
	Schema.restore(w,old)
	for id in nest.population: assert_eq(w.get_node("Threats").actors[id].home,nest.position)
	var bad := Schema.capture(w)
	bad.siege.roster = ["missing_patrol"]
	assert_ne(Schema.validate(bad),"")
	bad = Schema.capture(w)
	bad.siege.roster.append(bad.siege.roster[0])
	assert_ne(Schema.validate(bad),"")
func test_pack_losses_retreat_and_saved_cooldown_survives() -> void:
	await pack(-36)
	siege.advance(1)
	siege.advance(12)
	w.get_node("Threats").actors[siege.roster[0]].apply_damage(1000)
	siege.advance(1)
	assert_eq(siege.phase,"retreat")
	assert_eq(siege.roster.size(),1)
	var data := JSON.parse_string(JSON.stringify(Schema.capture(w))) as Dictionary
	assert_eq(Schema.validate(data),"")
	Schema.restore(w,data)
	assert_eq(siege.phase,"retreat")
	assert_eq(siege.remaining,45.0)
	siege.advance(45)
	var cooldown: float = siege.cooldowns[0]
	data = JSON.parse_string(JSON.stringify(Schema.capture(w))) as Dictionary
	Schema.restore(w,data)
	assert_eq(siege.cooldowns[0],cooldown)
	assert_eq(siege.phase,"idle")
	siege.advance(1)
	assert_eq(siege.phase,"idle","Reload does not create a new attack")
