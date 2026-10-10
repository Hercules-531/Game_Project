extends GutTest
const Senses = preload("res://scripts/threats/mutant_senses.gd")
const Schema = preload("res://scripts/persistence/save_schema.gd")
const Kit = preload("res://scripts/world/surface_kit.gd")
var world: Node
var actor: CharacterBody3D
var emissions: Node

func before_each() -> void:
	InputContext.menu_locked = false
	InputContext.set_context(InputContext.Context.WALK)
	world = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(world)
	actor = world.get_node("Threats").actors.approach_scout
	emissions = world.get_node("Emissions")
	await wait_physics_frames(2)

func after_each() -> void:
	InputContext.menu_locked = false
	InputContext.set_context(InputContext.Context.MENU)
	await wait_process_frames(2)

func test_sensory_boundaries_cover_and_smog() -> void:
	assert_true(Senses.detects("sound",35,35,true))
	assert_false(Senses.detects("sound",35.1,35,true))
	assert_true(Senses.detects("radio",14,40,false))
	assert_false(Senses.detects("radio",14.1,40,false))
	assert_false(Senses.detects("heat",1,45,false),"Heat does not see through walls")
	assert_true(Senses.detects("heat",12,24,true,0.5))
	assert_false(Senses.detects("heat",12.1,24,true,0.5))
	world.get_node("Weather").force("smog")
	assert_eq(world.get_node("Weather").mutant_sense_multiplier,0.5)
	var mule: Node = world.get_node("Fleet").drone("mule_01")
	mule.deployed = true
	mule.velocity = Vector3(1,0,0)
	assert_eq(emissions.sound_reach(mule),8.0)
	mule.silent_running = true
	assert_eq(emissions.sound_reach(mule),2.0)
	mule.silent_running = false
	mule.hull_id = "goliath"
	mule.integrity = 500.0
	world.get_node("Orders").local_field_power = true
	world.get_node("Orders").programs[mule.identity] = {"mode":"running"}
	assert_eq(emissions.sound_reach(mule),240.0)
	world.get_node("Orders").programs.clear()

func test_real_cover_blocks_heat_but_acoustics_can_cross() -> void:
	actor.set_physics_process(false)
	actor.position = Vector3(-42,0.02,-40)
	var wall := Kit.box(world.get_node("Surface"),"SensingWall",Vector3(4,2,0.3),Vector3(-42,1,-43))
	await wait_physics_frames(2)
	var source := {"kind":"heat","at":[-42,0.02,-46],"reach":24.0,"source":""}
	assert_true(Senses.strongest(actor,world,[source]).is_empty())
	source.kind = "sound"
	assert_eq(Senses.strongest(actor,world,[source]).kind,"sound")
	source.kind = "radio"
	assert_eq(Senses.strongest(actor,world,[source]).kind,"radio")
	source.kind = "light"
	assert_true(Senses.strongest(actor,world,[source]).is_empty())
	wall.queue_free()
	await wait_physics_frames(2)
	source.kind = "heat"
	assert_eq(Senses.strongest(actor,world,[source]).kind,"heat")

func test_physical_patrol_rain_shelter_and_flash_avoidance() -> void:
	var before := actor.position
	await wait_physics_frames(60)
	assert_gt(actor.position.distance_to(before),0.6,"Patrol actually walks")
	world.get_node("Weather").force("rain")
	await wait_physics_frames(240)
	assert_eq(actor.mode,"shelter")
	assert_lt(Vector2(actor.position.x - actor.shelter.x,actor.position.z - actor.shelter.z).length(),0.8)
	var roof := PhysicsRayQueryParameters3D.create(actor.global_position + Vector3(0,1.3,0),actor.global_position + Vector3(0,4,0),1,[actor.get_rid()])
	assert_false(actor.get_world_3d().direct_space_state.intersect_ray(roof).is_empty(),"Rain shelter is actual roof geometry")
	world.get_node("Weather").force("overcast")
	before = actor.position
	emissions.pulse("light",actor.position + Vector3(0,0,2),12,"",1.0)
	await wait_physics_frames(15)
	assert_eq(actor.mode,"avoid_light")
	assert_lt(actor.position.z,before.z,"Light response moves away")

func test_physical_hunt_serious_hit_and_destroyed_cell_cannot_revive() -> void:
	var mule: Node = world.get_node("Fleet").drone("mule_01")
	mule.position = Vector3(-40,0.02,-40)
	mule.deployed = true
	actor.position = Vector3(-40,0.02,-48)
	await wait_physics_frames(210)
	assert_true(mule.destroyed(),"One serious hit destroys fragile Mule")
	assert_eq(mule.battery,0.0)
	assert_false(mule.has_power())
	assert_lt(actor.position.distance_to(mule.position),2.0,"Hunt reaches real frame")
	world.get_node("Fleet").drone("hover_01").apply_damage(100)
	var human: Node = world.get_node("HumanSortie")
	assert_true(human.fleet_unavailable())
	assert_true(human.suit_up(),"Destroyed home frame does not prevent emergency sortie")
	world.get_node("Operator").position = mule.position + Vector3(0,0,2)
	assert_false(human.revive(mule))

func test_suit_flash_is_paid_limited_and_derelict_can_escort() -> void:
	actor.set_physics_process(false)
	for drone in world.get_node("Fleet").get_children(): drone.apply_damage(1000)
	var human: Node = world.get_node("HumanSortie")
	assert_true(human.suit_up())
	var op: Node3D = world.get_node("Operator")
	op.position = Vector3(-42,0.02,-40)
	actor.position = Vector3(-42,0.02,-41.9)
	await wait_physics_frames(2)
	assert_true(human.emergency_flash(actor))
	assert_almost_eq(human.jumper,0.275,0.000001)
	assert_eq(actor.stun_remaining,3.0)
	assert_false(human.emergency_flash(actor),"Cooldown blocks repeated flash")
	var data := Schema.capture(world)
	assert_eq(Schema.validate(JSON.parse_string(JSON.stringify(data))),"")
	Schema.restore(world,data)
	assert_eq(human.flash_remaining,10.0)
	actor = world.get_node("Threats").actors.approach_scout
	actor.set_physics_process(false)
	assert_eq(actor.stun_remaining,3.0)
	var frame: Node = world.get_node("Recovery").bodies.derelict_01
	op.position = frame.position + Vector3(0,0,2.5)
	await wait_physics_frames(2)
	assert_true(human.revive(frame))
	assert_eq(world.get_node("Recovery").records.derelict_01.state,"awake")
	assert_eq(human.escort_id,"derelict_01")
	assert_almost_eq(human.jumper,0.025,0.000001)
	assert_eq(Schema.validate(Schema.capture(world)),"")

func test_memory_damage_pending_pulses_and_migration_survive_reload() -> void:
	actor.set_physics_process(false)
	actor.mode = "investigate"
	actor.memory = 8.0
	actor.target_id = "mule_01"
	actor.last_known = Vector3(42,0.02,-102)
	actor.strike_remaining = 0.8
	actor.apply_damage(30)
	emissions.pulse("sound",Vector3(42,0.02,-102),60,"mule_01",0.75)
	var data := JSON.parse_string(JSON.stringify(Schema.capture(world))) as Dictionary
	assert_eq(Schema.validate(data),"")
	Schema.restore(world,data)
	var restored: Node = world.get_node("Threats").actors.approach_scout
	assert_eq(restored.memory,8.0)
	assert_eq(restored.integrity,70.0)
	assert_eq(restored.last_known,Vector3(42,0.02,-102))
	assert_eq(emissions.pulses[0].remaining,0.75)
	var bad := data.duplicate(true)
	bad.threats[0].memory = 100.0
	assert_ne(Schema.validate(bad),"")
	bad = data.duplicate(true)
	bad.fleet[0].integrity = -1.0
	assert_ne(Schema.validate(bad),"")
	data.version = 20
	data.erase("threats")
	data.erase("emissions")
	data.human_sortie.erase("flash")
	for machine in data.fleet: machine.erase("integrity")
	assert_eq(Schema.validate(data),"")
	Schema.restore(world,data)
	assert_eq(world.get_node("Fleet").drone("mule_01").integrity,30.0)
