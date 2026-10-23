extends Node3D
signal changed
const State = preload("res://scripts/infrastructure/entrance_state.gd")
const Inventory = preload("res://scripts/simulation/inventory.gd")
const Power = preload("res://scripts/drones/action_power.gd")
const Work = preload("res://scripts/drones/work_reservations.gd")
const Kit = preload("res://scripts/world/surface_kit.gd")
const Portal = preload("res://scripts/infrastructure/ingress_layout.gd")
const PortalView = preload("res://scripts/infrastructure/ingress_geometry.gd")
const Access = preload("res://scripts/rail/service_access.gd")
const IDS = ["airlock_outer","airlock_inner"]
var entrances: Dictionary = {}
var rail_clocks: Dictionary = {}
var cooldowns: Dictionary = {}
var routes: Dictionary = {}
var portals: Dictionary = {}
var portal_views: Dictionary = {}
var geometry_id := 0
var lamp_requests: Array = []
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
	var dig: Node = get_parent().get_node("Excavation")
	var rail: Node = get_parent().get_node("Rail")
	var rebuild := false
	for edge in dig.segments.size():
		rail_clocks.get_or_add(str(edge),0.0)
		for kind in ["mouth","wall"]:
			var id := Portal.id_for(kind,edge)
			if not portals.has(id):
				portals[id] = Portal.create(kind,edge,dig.grid)
				entrances[id] = State.initial()
				if kind=="wall": entrances[id].condition = 60.0
				rebuild = true
	var passenger: Node = get_parent().get_node("Passenger")
	if passenger.installed and not entrances.has("service_hatch"): entrances.service_hatch = State.initial()
	if rail.geometry!=null and geometry_id!=rail.geometry.get_instance_id(): rebuild = true
	if rebuild:
		geometry_id = rail.geometry.get_instance_id()
		for view in portal_views.values(): remove_child(view); view.queue_free()
		portal_views.clear()
		for id in portals:
			var view := PortalView.new()
			view.layout = portals[id]
			view.join_heights = [dig.grid.get(Vector2i(int(portals[id].start)-1,int(portals[id].row)-1),2.6),dig.grid.get(Vector2i(int(portals[id].start)-1,int(portals[id].row)),2.6)]
			add_child(view)
			portal_views[id] = view
			view.apply_state(entrances[id])
		get_parent().get_node("Surface").apply_ground_holes(Portal.ground_holes(portals))
		get_parent().get_node("SurfaceEnvironment").update_roofs(portals)
		dig.rebuild_render_geometry()
func ids() -> Array: return entrances.keys()
func portal_cells() -> Dictionary: return Portal.cut_cells(portals)
func cleared_ranges() -> Dictionary: return Portal.cleared_ranges(portals)
func light_step(fraction: float, requests: Array) -> void:
	for id in portal_views: portal_views[id].lamp.light_energy = 1.2*fraction if id in requests else 0.0
func source_hub(id: String) -> int: return int(portals[id].hub) if portals.has(id) else 0
func door(id: String) -> Node3D:
	if portals.has(id): return portal_views[id].gate
	if id=="service_hatch": return get_parent().get_node("Passenger").access.hatch
	return airlock.get_node("OuterDoor" if id=="airlock_outer" else "InnerDoor")
func point(id: String) -> Vector3:
	if portals.has(id): return Portal.gate_floor(portals[id])+Vector3(0,1.3,0)
	if id=="service_hatch": return Vector3(0,-0.06,8)
	return airlock.global_transform*Vector3(0,1.15,-2 if id=="airlock_outer" else 2)
func approach(id: String) -> Vector3:
	if portals.has(id): return Portal.approach(portals[id])
	if id=="service_hatch": return Access.climb_position(3)
	return point(id)+Vector3(0,-1.13,-0.95)
func opened(id: String) -> bool:
	if portals.has(id): return entrances[id].forced
	if id=="service_hatch": return door(id).get_child(1).disabled
	return entrances[id].forced or String(airlock.opened_side)==id.trim_prefix("airlock_")
func defense_factor(id: String = "airlock_outer") -> float:
	var defense: Node = get_parent().get_node("Defense")
	var band := preload("res://scripts/world/world_layout.gd").band_at(point(id))
	if point(id).distance_to(defense.center(band))>18: return 1.0
	var fence: Dictionary = defense.perimeters.get(str(band),{})
	if fence.is_empty(): return 1.0
	var intact := false
	for health in fence.health: intact = intact or health>0
	var powered: bool = defense.paid_home_fraction>0 if band==0 else defense.paid_field_fractions.get(str(band),0.0)>0
	return (0.6 if powered else 0.8) if intact else 1.0
func probability(id: String) -> float:
	var band := preload("res://scripts/world/world_layout.gd").band_at(point(id))
	return State.risk(entrances[id],trace.trace[band],defense_factor(id))
func _active(actor: Node) -> bool:
	if actor.integrity<=0 or actor.stun_remaining>0 or actor.mode in ["avoid_light","shelter","stunned","dead"]: return false
	var siege: Node = get_parent().get_node("Siege")
	return not (actor.identity in siege.roster and siege.phase in ["forming","retreat"] and not is_intruder(actor.identity))
func contact(actor: Node, id: String) -> bool:
	if not _active(actor) or opened(id) or (actor.position+Vector3(0,0.6,0)).distance_to(point(id))>1.8: return false
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(actor.position+Vector3(0,0.7,0),point(id),1,[actor.get_rid()]))
	return hit.is_empty() or hit.collider==door(id)
func strike_near(actor: Node, damage: float) -> bool:
	for id in ids():
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
	for id in ids():
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
	if exposure>=5: human.kill("Unprotected exposure beyond the breached perimeter.")
func _base_inside(at: Vector3) -> bool:
	if at.y< -0.25 or at.y>0.5: return false
	for rect in [Rect2(-1.3,-6,2.6,12),Rect2(-7.3,-2,6,6),Rect2(1.3,-2,6,6),Rect2(-3.3,6,6.6,4),Rect2(-2.3,-9.3,4.6,3.3)]:
		if rect.has_point(Vector2(at.x,at.z)): return true
	return false
func network_inside(at: Vector3) -> bool:
	if _base_inside(at): return true
	var p: Node = get_parent().get_node("Passenger")
	if p.installed and absf(at.x)<0.85 and at.z>7 and at.z<9 and at.y>=-6.2 and at.y<0.2: return true
	var cell := Vector2i(floori(at.x),floori(at.z))
	if portal_cells().has(cell): return false
	var grid: Dictionary = get_parent().get_node("Excavation").work_grid()
	return grid.has(cell) and at.y>=-6.2 and at.y< -6+grid[cell]-0.1
func indoors(at: Vector3) -> bool:
	if network_inside(at): return true
	for layout in portals.values():
		if Portal.contains(layout,at): return true
	return false
func _force(id: String) -> void:
	entrances[id].forced = true
	entrances[id].condition = maxf(0,entrances[id].condition-25)
	entrances[id].contact = 0
	_apply(id)
	status = "SEAL FORCED / "+id.to_upper()+" / CLEAR THE ROUTE BEFORE RESEALING"
	get_parent().get_node("Emissions").pulse("sound",approach(id),90.0,"",0.5)
	changed.emit()
func _apply(id: String) -> void:
	if portals.has(id): portal_views[id].apply_state(entrances[id]); return
	if id=="service_hatch":
		var p: Node = get_parent().get_node("Passenger")
		p.access.set_open(entrances[id].forced or (p.climb>=0 and p.climb<3.7))
		return
	airlock.set_forced(id.trim_prefix("airlock_"),entrances[id].forced)
	var body := door(id)
	var old: Node = body.get_node_or_null("Plating")
	if old!=null: body.remove_child(old); old.queue_free()
	var plates := Node3D.new()
	plates.name = "Plating"
	body.add_child(plates)
	for i in int(entrances[id].tier): Kit.box(plates,"Plate",Vector3(1.6,0.25,0.06),Vector3(0,-0.6+i*0.6,0.14),"metal",false)
func is_intruder(id: String) -> bool:
	if not threats.actors.has(id): return false
	var at: Vector3 = threats.actors[id].position
	return network_inside(at) or (routes.has(id) and routes[id].stage>=1 and portals.has(routes[id].entry) and Portal.contains(portals[routes[id].entry],at))
func goal(actor: Node, stimulated: bool) -> Dictionary:
	var local: Vector3 = airlock.to_local(actor.global_position)
	if not routes.has(actor.identity):
		var entry := "airlock_outer"
		var already_inside := network_inside(actor.position)
		var nearest := INF
		if not already_inside:
			if trace.trace[0]>=40 and actor.position.distance_to(approach("airlock_outer"))<=12: nearest = actor.position.distance_to(approach("airlock_outer"))
			for id in portals:
				var band := preload("res://scripts/world/world_layout.gd").band_at(Portal.top(portals[id]))
				var distance: float = actor.position.distance_to(Portal.top(portals[id])+Vector3(-0.95,0,0))
				if (trace.trace[band]>=40 or (portals[id].kind=="wall" and Portal.contains(portals[id],actor.position))) and distance<=12 and distance<nearest: entry = id; nearest = distance
			if not is_finite(nearest): return {}
		var siege: Node = get_parent().get_node("Siege")
		if not already_inside and actor.identity in siege.roster and siege.phase in ["forming","retreat"]: return {}
		var navhub := 0
		if already_inside and actor.position.y< -2:
			var nearest_hub := INF
			for hub in get_parent().get_node("Rail").hub_count():
				var distance: float = actor.position.distance_to(get_parent().get_node("Rail").at(hub))
				if distance<nearest_hub: navhub = hub; nearest_hub = distance
		routes[actor.identity] = {"entry":entry,"stage":2 if already_inside else 0,"patrol":0,"waypoint":0,"navhub":navhub,"climb":-1.0}
	var route: Dictionary = routes[actor.identity]
	if route.climb>=0:
		if actor.position.distance_to(Access.climb_position(route.climb))>0.25: route.climb = -1.0
		else: return {"at":Access.climb_position(0 if opened("service_hatch") else 3),"reach":0.04}
	if portals.has(route.entry) and route.stage<2:
		var layout: Dictionary = portals[route.entry]
		if layout.kind=="mouth" and route.stage==0 and not opened(route.entry): return {"at":approach(route.entry)}
		if layout.kind=="mouth" and Portal.contains(layout,actor.position): route.stage = 1
		var points := Portal.waypoints(layout)
		var step := int(route.waypoint)
		if layout.kind=="wall" and step==3 and not opened(route.entry): return {"at":approach(route.entry)}
		if actor.position.distance_to(points[step])<0.3:
			if step<4: route.waypoint += 1; step += 1
			else: route.stage = 2; route.navhub = int(layout.hub)
		if route.stage<2: return {"at":points[step],"reach":0.15}
	if route.stage>=2 and actor.position.y< -2:
		if stimulated or actor.memory>0: return {}
		var rail: Node = get_parent().get_node("Rail")
		var hub := mini(int(route.navhub),maxi(0,rail.hub_count()-1))
		if hub>=0:
			if actor.position.distance_to(rail.at(hub))<0.9:
				route.navhub = hub-1
				hub -= 1
			if hub>=0: return {"at":rail.at(hub)}
		var p: Node = get_parent().get_node("Passenger")
		if p.installed:
			var entry := Access.climb_position(9)
			if actor.position.distance_to(entry)>0.08: return {"at":entry,"reach":0.04}
			route.climb = 9.0
			return {"at":entry,"reach":0.04}
		return {"at":rail.at(0)}
	if route.stage<2:
		if absf(local.x)<1.05 and local.z> -1.2: route.stage = maxi(int(route.stage),1)
		if absf(local.x)<1.05 and local.z>2.5: route.stage = 2
	if route.stage==0: return {"at":airlock.global_transform*Vector3(0,0.02,0.5) if opened("airlock_outer") else approach("airlock_outer")}
	if route.stage==1: return {"at":airlock.global_transform*Vector3(0,0.02,3.5) if opened("airlock_inner") else approach("airlock_inner")}
	if stimulated or actor.memory>0: return {}
	var points := [Vector3(0,0.02,1),Vector3(-4,0.02,1),Vector3(0,0.02,8),Vector3(4,0.02,1)]
	if actor.position.distance_to(points[int(route.patrol)])<0.8: route.patrol = (int(route.patrol)+1)%4
	return {"at":points[int(route.patrol)]}
func advance_motion(actor: Node, seconds: float) -> bool:
	if not routes.has(actor.identity) or routes[actor.identity].climb<0: return false
	var route: Dictionary = routes[actor.identity]
	var target := 0.0 if opened("service_hatch") else 3.0
	var next := move_toward(float(route.climb),target,seconds*0.8)
	var motion: Vector3 = Access.climb_position(next)-actor.position
	actor.velocity = motion/maxf(seconds,0.000001)
	actor.move_and_collide(motion)
	if actor.position.distance_to(Access.climb_position(next))<0.02: route.climb = next
	if next<=0.000001 and actor.position.distance_to(Access.climb_position(0))<0.02: route.climb = -1.0; route.stage = 3
	return true
func _service_hull(id: String, entrance: String = "airlock_outer") -> Node:
	var d: Node = get_parent().get_node("Fleet").drone(id)
	if d==null or d.destroyed() or Work.busy(get_parent(),id) or not d.get_node("Controller").available or d.module_efficiency("torch")<=0 or not d.has_power() or cooldowns.get(id,0.0)>0: return null
	if get_parent().get_node("FleetControl").transfer.get("id","")==id: return null
	var hub := source_hub(entrance)
	if hub>0:
		var rail: Node = get_parent().get_node("Rail")
		return d if d.deployed and rail.wired(hub) and rail.territory.sites[hub].fob and rail.territory.sites[hub].condition>0 and d.position.distance_to(rail.territory.pad(hub))<=8 else null
	if (not d.deployed and d.position.distance_to(Vector3(-4.3,0.02,1))<=5) or (d.deployed and d.position.distance_to(Vector3(0,0.02,-13))<=8): return d
	return null
func repair_cost(id: String) -> int:
	if not entrances.has(id): return 0
	return ceili((100-entrances[id].condition)*0.2)+(8 if entrances[id].forced else 0)
func clear_aperture(id: String) -> bool:
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.55,2.4,1.7) if portals.has(id) else (Vector3(1.8,0.4,1.8) if id=="service_hatch" else Vector3(1.5,2.1,0.55))
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = point(id)
	query.collision_mask = 1
	var excluded: Array[RID] = []
	for entry in ids(): excluded.append(door(entry).get_rid())
	query.exclude = excluded
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
func service(id: String, hull: String, reinforce: bool) -> bool:
	if not entrances.has(id) or airlock.busy: return false
	var d := _service_hull(hull,id)
	if d==null: status = "Needs an available powered torch hull at the home bay or cradle."; return false
	if reinforce and (entrances[id].forced or entrances[id].tier>=3 or not get_parent().get_node("Research").has_technology("defense")): return false
	if not reinforce and entrances[id].forced and not clear_aperture(id): status = "Aperture occupied. Clear it before sealing."; return false
	var cost := 24 if reinforce else repair_cost(id)
	var stock: Node = get_parent().get_node("Inventory") if source_hub(id)==0 else get_parent().get_node("Rail").stock(source_hub(id))
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
	var lining := Portal.id_for("wall",int(job.plan.source))
	if entrances.has(lining): entrances[lining].condition = maxf(0,entrances[lining].condition-supplied_seconds*0.001)
	job.noise_clock = float(job.get("noise_clock",0.0))+supplied_seconds
	while job.noise_clock>=5.0-0.000000001:
		job.noise_clock = maxf(0,job.noise_clock-5.0)
		var at: Vector3 = get_parent().get_node("Territory").pad(int(job.plan.source))
		if job.plan.kind=="tunnel": at = at.lerp(get_parent().get_node("Territory").pad(int(job.plan.target)),clampf(1.0-job.remaining/job.seconds,0,1))
		at.y = -4.5
		get_parent().get_node("Emissions").pulse("drill",at,180.0,job.worker)
func record_rail(edge: int, at: Vector3, metres: float, payload: float) -> void:
	var lining := Portal.id_for("wall",edge)
	if entrances.has(lining): entrances[lining].condition = maxf(0,entrances[lining].condition-metres*0.0005*(1.0+payload/200.0))
	var key := str(edge)
	rail_clocks[key] = rail_clocks.get(key,0.0)+metres
	while rail_clocks[key]>=10.0-0.000000001:
		rail_clocks[key] = maxf(0,rail_clocks[key]-10.0)
		get_parent().get_node("Emissions").pulse("rail",at+Vector3(0,1,0),80.0+0.2*payload,"")
func snapshot() -> Dictionary:
	return {"entrances":entrances.duplicate(true),"portals":portals.duplicate(true),"rail_clocks":rail_clocks.duplicate(),"cooldowns":cooldowns.duplicate(),"routes":routes.duplicate(true),"exposure":exposure,"rng":str(rng.state)}
static func validate(data: Variant, segments: int, hatch: bool = false, legacy: bool = false) -> bool:
	var expected: Array = IDS.duplicate()
	if not legacy:
		for edge in segments:
			for kind in ["mouth","wall"]: expected.append(Portal.id_for(kind,edge))
		if hatch: expected.append("service_hatch")
	if not data is Dictionary or not data.get("entrances") is Dictionary or data.entrances.size()!=expected.size() or not data.get("rail_clocks") is Dictionary or data.rail_clocks.size()!=segments or not data.get("cooldowns") is Dictionary or data.cooldowns.size()>32 or not data.get("routes") is Dictionary or data.routes.size()>96 or not data.get("rng") is String or not data.rng.is_valid_int() or not Inventory._number(data.get("exposure")) or data.exposure<0 or data.exposure>5: return false
	for id in expected:
		if not State.valid(data.entrances.get(id)): return false
	for i in segments:
		var value: Variant = data.rail_clocks.get(str(i))
		if not Inventory._number(value) or value<0 or value>=10: return false
	for id in data.cooldowns:
		if not id is String or id.length()>80 or not Inventory._number(data.cooldowns[id]) or data.cooldowns[id]<=0 or data.cooldowns[id]>45: return false
	for id in data.routes:
		var route: Variant = data.routes[id]
		if not id is String or id.is_empty() or id.length()>80 or not route is Dictionary or not Inventory._integer(route.get("stage"),0,3 if not legacy else 2) or not Inventory._integer(route.get("patrol"),0,3): return false
		if not legacy and (route.get("entry") not in expected or not Inventory._integer(route.get("waypoint"),0,4) or not Inventory._integer(route.get("navhub"),-1,segments) or not Inventory._number(route.get("climb")) or not (route.climb==-1 or (hatch and route.climb>=0 and route.climb<=9))): return false
	return true
func restore(data: Dictionary, legacy: bool = false) -> void:
	assert(validate(data,get_parent().get_node("Excavation").segments.size(),get_parent().get_node("Passenger").installed,legacy))
	if not legacy:
		portals = data.portals.duplicate(true)
		for layout in portals.values():
			for field in ["edge","hub","row","start"]: layout[field] = int(layout[field])
	else: portals.clear()
	entrances = data.entrances.duplicate(true)
	for record in entrances.values(): record.tier = int(record.tier)
	rail_clocks = data.rail_clocks.duplicate()
	cooldowns = data.cooldowns.duplicate()
	routes = data.routes.duplicate(true)
	for route in routes.values():
		if legacy: route.entry = "airlock_outer"; route.waypoint = 0; route.navhub = 0; route.climb = -1.0
		for field in ["stage","patrol","waypoint","navhub"]: route[field] = int(route[field])
	exposure = data.exposure
	rng.state = data.rng.to_int()
	geometry_id = 0
	sync()
	for id in ids(): _apply(id)
	changed.emit()
func reset() -> void:
	entrances.clear()
	for id in IDS: entrances[id] = State.initial()
	rail_clocks.clear()
	cooldowns.clear()
	routes.clear()
	portals.clear()
	geometry_id = 0
	exposure = 0
	rng.seed = 140540
	sync()
	for id in ids(): _apply(id)
