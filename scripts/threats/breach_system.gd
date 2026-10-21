extends Node3D
signal changed
const State = preload("res://scripts/infrastructure/entrance_state.gd")
const Inventory = preload("res://scripts/simulation/inventory.gd")
const Power = preload("res://scripts/drones/action_power.gd")
const Work = preload("res://scripts/drones/work_reservations.gd")
const Kit = preload("res://scripts/world/surface_kit.gd")
const IDS = ["airlock_outer","airlock_inner"]
var entrances: Dictionary = {}
var rail_clocks: Dictionary = {}
var cooldowns: Dictionary = {}
var routes: Dictionary = {}
var exposure := 0.0
var rng := RandomNumberGenerator.new()
var status := "Inspect owned seals. Reinforcement reduces forcing risk, never to zero."
@onready var airlock: Node3D = get_parent().get_node("Bunker/Airlock")
@onready var threats: Node = get_parent().get_node("Threats")
@onready var trace: Node = get_parent().get_node("Trace")
func _ready() -> void:
	rng.seed = 140540
	for id in IDS: entrances[id] = State.initial()
	get_parent().get_node("Rail").changed.connect(sync)
	sync()
func sync() -> void:
	for edge in get_parent().get_node("Excavation").segments.size(): rail_clocks.get_or_add(str(edge),0.0)
func door(id: String) -> Node3D: return airlock.get_node("OuterDoor" if id=="airlock_outer" else "InnerDoor")
func point(id: String) -> Vector3:
	return airlock.global_transform*Vector3(0,1.15,-2 if id=="airlock_outer" else 2)
func approach(id: String) -> Vector3: return point(id)+Vector3(0,-1.13,-0.95)
func opened(id: String) -> bool:
	return entrances[id].forced or String(airlock.opened_side)==id.trim_prefix("airlock_")
func defense_factor() -> float:
	var defense: Node = get_parent().get_node("Defense")
	var fence: Dictionary = defense.perimeters.get("0",{})
	if fence.is_empty(): return 1.0
	var intact := false
	for health in fence.health: intact = intact or health>0
	return (0.6 if defense.paid_home_fraction>0 else 0.8) if intact else 1.0
func probability(id: String) -> float: return State.risk(entrances[id],trace.trace[0],defense_factor())
func _active(actor: Node) -> bool:
	if actor.integrity<=0 or actor.stun_remaining>0 or actor.mode in ["avoid_light","shelter","stunned","dead"]: return false
	var siege: Node = get_parent().get_node("Siege")
	return not (actor.identity in siege.roster and siege.phase in ["forming","retreat"] and not is_intruder(actor.identity))
func contact(actor: Node, id: String) -> bool:
	if not _active(actor) or opened(id) or actor.position.distance_to(point(id)-Vector3(0,1.13,0))>1.8: return false
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(actor.position+Vector3(0,0.7,0),point(id)-Vector3(0,0.4,0),1,[actor.get_rid()]))
	return hit.is_empty() or hit.collider==door(id)
func strike_near(actor: Node, damage: float) -> bool:
	for id in IDS:
		if not contact(actor,id): continue
		entrances[id].condition = maxf(0,entrances[id].condition-damage/10.0/(1.0+entrances[id].tier))
		get_parent().get_node("Emissions").pulse("sound",approach(id),60.0,actor.identity,0.4)
		status = "IMPACT / "+id.to_upper()
		changed.emit()
		return true
	return false
func _physics_process(delta: float) -> void: advance(delta)
func advance(seconds: float) -> void:
	if not is_finite(seconds) or seconds<=0 or seconds>1000000: return
	for id in cooldowns.keys():
		cooldowns[id] = maxf(0,cooldowns[id]-seconds)
		if cooldowns[id]<=0: cooldowns.erase(id)
	for id in routes.keys():
		if not threats.actors.has(id) or threats.actors[id].integrity<=0: routes.erase(id)
	for id in IDS:
		var eligible := false
		if probability(id)>0 and not airlock.busy:
			for actor in threats.actors.values():
				if contact(actor,id): eligible = true; break
		if not eligible: entrances[id].contact = 0.0; continue
		entrances[id].contact += seconds
		while entrances[id].contact>=10.0-0.000000001:
			entrances[id].contact = maxf(0,entrances[id].contact-10.0)
			if rng.randf()<probability(id): _force(id); break
	var human: Node = get_parent().get_node("HumanSortie")
	var exposed: bool = not human.active and not human.dead and not indoors(get_parent().get_node("Operator").position)
	var forced := false
	for record in entrances.values(): forced = forced or record.forced
	exposure = minf(5,exposure+seconds) if exposed and forced else 0.0
	if exposure>=5: human.kill("Unprotected exposure beyond the breached airlock.")
func indoors(at: Vector3) -> bool: return at.z>=-10.05 or at.y< -2.0
func _force(id: String) -> void:
	entrances[id].forced = true
	entrances[id].condition = maxf(0,entrances[id].condition-25)
	entrances[id].contact = 0
	_apply(id)
	status = "SEAL FORCED / "+id.to_upper()+" / CLEAR THE ROUTE BEFORE RESEALING"
	get_parent().get_node("Emissions").pulse("sound",approach(id),90.0,"",0.5)
	changed.emit()
func _apply(id: String) -> void:
	airlock.set_forced(id.trim_prefix("airlock_"),entrances[id].forced)
	var body := door(id)
	var old: Node = body.get_node_or_null("Plating")
	if old!=null: body.remove_child(old); old.queue_free()
	var plates := Node3D.new()
	plates.name = "Plating"
	body.add_child(plates)
	for i in int(entrances[id].tier): Kit.box(plates,"Plate",Vector3(1.6,0.25,0.06),Vector3(0,-0.6+i*0.6,0.14),"metal",false)
func is_intruder(id: String) -> bool:
	return routes.has(id) and routes[id].stage>=1 and threats.actors.has(id) and threats.actors[id].position.z> -10.1
func goal(actor: Node, stimulated: bool) -> Dictionary:
	var local: Vector3 = airlock.to_local(actor.global_position)
	if not routes.has(actor.identity):
		var already_inside: bool = absf(local.x)<1.05 and local.z> -1.2 and local.z<3
		if not already_inside and (trace.trace[0]<40 or actor.position.distance_to(approach("airlock_outer"))>12): return {}
		var siege: Node = get_parent().get_node("Siege")
		if actor.identity in siege.roster and siege.phase in ["forming","retreat"]: return {}
		routes[actor.identity] = {"stage":0,"patrol":0}
	var route: Dictionary = routes[actor.identity]
	if absf(local.x)<1.05 and local.z> -1.2: route.stage = maxi(int(route.stage),1)
	if absf(local.x)<1.05 and local.z>2.5: route.stage = 2
	if route.stage==0: return {"at":airlock.global_transform*Vector3(0,0.02,0.5) if opened("airlock_outer") else approach("airlock_outer")}
	if route.stage==1: return {"at":airlock.global_transform*Vector3(0,0.02,3.5) if opened("airlock_inner") else approach("airlock_inner")}
	if stimulated or actor.memory>0: return {}
	var points := [Vector3(0,0.02,1),Vector3(-4,0.02,1),Vector3(0,0.02,8),Vector3(4,0.02,1)]
	if actor.position.distance_to(points[int(route.patrol)])<0.8: route.patrol = (int(route.patrol)+1)%4
	return {"at":points[int(route.patrol)]}
func _service_hull(id: String) -> Node:
	var d: Node = get_parent().get_node("Fleet").drone(id)
	if d==null or d.destroyed() or Work.busy(get_parent(),id) or not d.get_node("Controller").available or d.module_efficiency("torch")<=0 or not d.has_power() or cooldowns.get(id,0.0)>0: return null
	if get_parent().get_node("FleetControl").transfer.get("id","")==id: return null
	if (not d.deployed and d.position.distance_to(Vector3(-4.3,0.02,1))<=5) or (d.deployed and d.position.distance_to(Vector3(0,0.02,-13))<=8): return d
	return null
func repair_cost(id: String) -> int:
	if not entrances.has(id): return 0
	return ceili((100-entrances[id].condition)*0.2)+(8 if entrances[id].forced else 0)
func clear_aperture(id: String) -> bool:
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.5,2.1,0.55)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = point(id)
	query.collision_mask = 1
	query.exclude = [door("airlock_inner").get_rid(),door("airlock_outer").get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
func service(id: String, hull: String, reinforce: bool) -> bool:
	if not entrances.has(id) or airlock.busy: return false
	var d := _service_hull(hull)
	if d==null: status = "Needs an available powered torch hull at the home bay or cradle."; return false
	if reinforce and (entrances[id].forced or entrances[id].tier>=3 or not get_parent().get_node("Research").has_technology("defense")): return false
	if not reinforce and entrances[id].forced and not clear_aperture(id): status = "Aperture occupied. Clear it before sealing."; return false
	var cost := 24 if reinforce else repair_cost(id)
	var stock: Node = get_parent().get_node("Inventory")
	if cost<=0 or stock.scrap<cost or not Power.available(get_parent(),d,0.02): status = "Needs local scrap and 0.02kWh from the service hull's real supply."; return false
	if not Power.spend(get_parent(),d,0.02): return false
	stock.spend_scrap(cost)
	if reinforce: entrances[id].tier += 1
	else:
		entrances[id].condition = 100.0
		entrances[id].forced = false
	entrances[id].contact = 0.0
	cooldowns[hull] = 15.0/d.module_efficiency("torch")
	_apply(id)
	status = "Plating installed." if reinforce else "Seal serviced."
	changed.emit()
	return true
func record_drill(job: Dictionary, supplied_seconds: float) -> void:
	job.noise_clock = float(job.get("noise_clock",0.0))+supplied_seconds
	while job.noise_clock>=5.0-0.000000001:
		job.noise_clock = maxf(0,job.noise_clock-5.0)
		var at: Vector3 = get_parent().get_node("Territory").pad(int(job.plan.source))
		if job.plan.kind=="tunnel": at = at.lerp(get_parent().get_node("Territory").pad(int(job.plan.target)),clampf(1.0-job.remaining/job.seconds,0,1))
		at.y = -4.5
		get_parent().get_node("Emissions").pulse("drill",at,180.0,job.worker)
func record_rail(edge: int, at: Vector3, metres: float, payload: float) -> void:
	var key := str(edge)
	rail_clocks[key] = rail_clocks.get(key,0.0)+metres
	while rail_clocks[key]>=10.0-0.000000001:
		rail_clocks[key] = maxf(0,rail_clocks[key]-10.0)
		get_parent().get_node("Emissions").pulse("rail",at+Vector3(0,1,0),80.0+0.2*payload,"")
func snapshot() -> Dictionary:
	return {"entrances":entrances.duplicate(true),"rail_clocks":rail_clocks.duplicate(),"cooldowns":cooldowns.duplicate(),"routes":routes.duplicate(true),"exposure":exposure,"rng":str(rng.state)}
static func validate(data: Variant, segments: int) -> bool:
	if not data is Dictionary or not data.get("entrances") is Dictionary or data.entrances.size()!=2 or not data.get("rail_clocks") is Dictionary or data.rail_clocks.size()!=segments or not data.get("cooldowns") is Dictionary or data.cooldowns.size()>32 or not data.get("routes") is Dictionary or data.routes.size()>96 or not data.get("rng") is String or not data.rng.is_valid_int() or not Inventory._number(data.get("exposure")) or data.exposure<0 or data.exposure>5: return false
	for id in IDS:
		if not State.valid(data.entrances.get(id)): return false
	for i in segments:
		var value: Variant = data.rail_clocks.get(str(i))
		if not Inventory._number(value) or value<0 or value>=10: return false
	for id in data.cooldowns:
		if not id is String or id.length()>80 or not Inventory._number(data.cooldowns[id]) or data.cooldowns[id]<=0 or data.cooldowns[id]>45: return false
	for id in data.routes:
		var route: Variant = data.routes[id]
		if not id is String or id.is_empty() or id.length()>80 or not route is Dictionary or not Inventory._integer(route.get("stage"),0,2) or not Inventory._integer(route.get("patrol"),0,3): return false
	return true
func restore(data: Dictionary) -> void:
	assert(validate(data,get_parent().get_node("Excavation").segments.size()))
	entrances = data.entrances.duplicate(true)
	for record in entrances.values(): record.tier = int(record.tier)
	rail_clocks = data.rail_clocks.duplicate()
	cooldowns = data.cooldowns.duplicate()
	routes = data.routes.duplicate(true)
	for route in routes.values(): route.stage = int(route.stage); route.patrol = int(route.patrol)
	exposure = data.exposure
	rng.state = data.rng.to_int()
	for id in IDS: _apply(id)
	changed.emit()
func reset() -> void:
	entrances.clear()
	for id in IDS: entrances[id] = State.initial()
	rail_clocks.clear()
	cooldowns.clear()
	routes.clear()
	exposure = 0
	rng.seed = 140540
	sync()
	for id in IDS: _apply(id)
