extends Node3D
const BALANCE = preload("res://resources/balance/escalation.tres")
const Drone = preload("res://scripts/drones/drone.gd")
const Events = preload("res://scripts/simulation/emission_events.gd")
const Kit = preload("res://scripts/world/surface_kit.gd")
const Senses = preload("res://scripts/threats/mutant_senses.gd")
const POSITIONS = [Vector3(48,0.02,-99),Vector3(-43,0.02,-180),Vector3(43,0.02,-278),Vector3(-42,0.02,-370),Vector3(40,0.02,-470),Vector3(-40,0.02,-578)]
var band := 0
var growth := 0
var remaining := 3600.0
var reinforce_remaining := 60.0
var integrity := 200.0
var state := "active"
var home_known := false
var serial := 0
var population: Array = []
var surveyed_at := -1.0
var intel: Dictionary = {}

func _ready() -> void:
	growth = BALANCE.initial_growth[band]
	remaining = BALANCE.growth_intervals[band]
	integrity = 200.0 + 100.0 * band
	position = POSITIONS[band]
	add_to_group("sensor_landmarks")
	set_meta("thermal",0.15)
	set_meta("classification","Organic colony")
	Kit.box(self,"RainCover",Vector3(6,0.25,8),Vector3(-5,2.6,0),"rock")
	for at in [Vector3(-7.8,1.25,-3.8),Vector3(-2.2,1.25,-3.8)]:
		Kit.box(self,"CoverPost",Vector3(0.25,2.5,0.25),at,"rock")
	get_node("Body/Collision").shape = get_node("Body/Collision").shape.duplicate()
	_appearance()

func active_count() -> int:
	var threats: Node = get_parent().get_parent().get_node("Threats")
	var count := 0
	for id in population:
		if threats.actors.has(id) and threats.actors[id].integrity > 0.0: count += 1
	return count

func advance(seconds: float, trace: float) -> void:
	if state != "active": return
	remaining -= seconds
	while remaining <= 0.0:
		remaining += BALANCE.growth_intervals[band]
		growth = mini(6,growth + 1)
		_appearance()
	if growth >= 4 or (growth >= 2 and trace >= 80.0): home_known = true
	reinforce_remaining -= seconds
	if reinforce_remaining <= 0.0:
		while reinforce_remaining <= 0.0: reinforce_remaining += BALANCE.reinforce_seconds
		_recruit(mini(6,growth + (2 if trace >= 60.0 else (1 if trace >= 30.0 else 0))))

func _recruit(desired: int) -> void:
	var threats: Node = get_parent().get_parent().get_node("Threats")
	for id in population.duplicate():
		if not threats.actors.has(id) or threats.actors[id].integrity <= 0.0:
			if threats.actors.has(id):
				var spent: Node = threats.actors[id]
				threats.remove_child(spent)
				spent.queue_free()
				threats.actors.erase(id)
			population.erase(id)
	for slot in 6:
		if active_count() >= desired: break
		var at := global_position + Vector3(sin(slot * TAU/6),0,cos(slot * TAU/6)) * 4.5
		var shape := CapsuleShape3D.new()
		shape.radius = 0.4
		shape.height = 1.2
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform.origin = at + Vector3(0,0.6,0)
		query.collision_mask = 1
		if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): continue
		serial += 1
		var id := "nest_%d_patrol_%d" % [band,serial]
		var body: Node = threats.spawn(id,at,global_position + Vector3(-5,0,0))
		if body != null: population.append(id)

func survey(drone: Node, clock: float) -> bool:
	if not drone.deployed or not drone.has_power() or (drone.module_efficiency("ccd") <= 0.0 and not preload("res://scripts/sensors/sensor_router.gd").neural(drone)) or get_parent().get_parent().get_node("Radio").quality(drone) <= 0.0 or global_position.distance_to(drone.global_position) > 8.0: return false
	if not drone.get_node("CCD").in_frustum(global_position + Vector3(0,0.7,0)): return false
	var ray := PhysicsRayQueryParameters3D.create(drone.global_position + Vector3(0,0.7,0),global_position + Vector3(0,0.7,0),1,[drone.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty() and hit.position.distance_to(global_position + Vector3(0,0.7,0)) > 2.0: return false
	surveyed_at = clock
	var seen := 0
	var threats: Node = get_parent().get_parent().get_node("Threats")
	for id in population:
		if not threats.actors.has(id): continue
		var actor: Node = threats.actors[id]
		if actor.integrity > 0.0 and drone.get_node("CCD").in_frustum(actor.global_position + Vector3(0,0.7,0)) and Senses.clear_reach(drone,actor.global_position,actor): seen += 1
	intel = {"growth":growth,"integrity":integrity,"state":state,"patrols":seen}
	return true

func apply_damage(amount: float) -> void:
	if state != "active" or not is_finite(amount) or amount <= 0.0: return
	integrity = maxf(0.0,integrity - amount)
	if integrity <= 0.0:
		state = "cleared"
		_appearance()

func _appearance() -> void:
	var size := 0.8 + growth * 0.08
	get_node("Visual").scale = Vector3.ONE * size
	if state == "cleared": get_node("Visual").scale.y *= 0.25
	var collision: CollisionShape3D = get_node("Body/Collision")
	collision.shape.radius = 1.5 * size
	collision.shape.height = 1.4 * size
	collision.position.y = 0.7 * size

func snapshot() -> Dictionary:
	return {"band":band,"growth":growth,"remaining":remaining,"reinforce":reinforce_remaining,"integrity":integrity,"state":state,"home_known":home_known,"serial":serial,"population":population.duplicate(),"surveyed_at":surveyed_at,"intel":intel.duplicate()}

static func validate(data: Variant) -> bool:
	if not data is Dictionary or not Drone._range(data.get("band"),0,5) or data.band != int(data.band): return false
	if data.get("state") not in ["active","cleared","suppressed"] or not data.get("home_known") is bool or not data.get("population") is Array or data.population.size() > 6 or not data.get("intel") is Dictionary: return false
	var limits := {"growth":6.0,"remaining":BALANCE.growth_intervals[int(data.band)],"reinforce":60.0,"integrity":200.0 + 100.0 * data.band,"serial":1000000000.0,"surveyed_at":1000000000.0}
	for key in limits:
		if not Drone._range(data.get(key),-1.0 if key == "surveyed_at" else 0.0,limits[key]): return false
	if data.remaining <= 0.0 or data.growth != int(data.growth) or data.serial != int(data.serial): return false
	if (data.state == "cleared") != (data.integrity == 0.0): return false
	var seen := {}
	for id in data.population:
		if not id is String or not id.begins_with("nest_%d_patrol_" % int(data.band)) or id.length() > 80 or seen.has(id): return false
		seen[id] = true
	if data.surveyed_at < 0.0: return data.intel.is_empty()
	var known: Dictionary = data.intel
	return Drone._range(known.get("growth"),0,6) and Drone._range(known.get("integrity"),0,200 + 100 * data.band) and known.get("state") in ["active","cleared","suppressed"] and Drone._range(known.get("patrols"),0,6)

func restore(data: Dictionary) -> void:
	assert(validate(data))
	growth = int(data.growth)
	remaining = data.remaining
	reinforce_remaining = data.reinforce
	integrity = data.integrity
	state = data.state
	home_known = data.home_known
	serial = int(data.serial)
	population = data.population.duplicate()
	surveyed_at = data.surveyed_at
	intel = data.intel.duplicate()
	_appearance()
