extends Node3D
signal changed
const Drone = preload("res://scripts/drones/drone.gd")
const Perimeter = preload("res://scripts/defense/perimeter_visual.gd")
const Kit = preload("res://scripts/world/surface_kit.gd")
const Layout = preload("res://scripts/world/world_layout.gd")
var ammo: Dictionary = {}
var kits: Dictionary = {}
var cooldowns: Dictionary = {}
var pending: Dictionary = {}
var decoys: Dictionary = {}
var decoy_clock := 2.0
var traps: Array = []
var next_trap := 1
var perimeters: Dictionary = {}
var views: Dictionary = {}
var trap_views: Dictionary = {}
var status := "Fit defenses, load finite supplies at home, then send observed fire orders."
@onready var fleet: Node = get_parent().get_node("Fleet")
@onready var territory: Node = get_parent().get_node("Territory")
@onready var life: Node = get_parent().get_node("LifeSupport")
func _ready() -> void:
	life.energy_step.connect(_home_energy)
func center(band: int) -> Vector3:
	return Vector3(0,0.02,-22) if band == 0 else territory.pad(band)
func _at_home(drone: Node) -> bool:
	return drone != null and not drone.destroyed() and (not drone.deployed or (drone.hull().external_power and drone.position.distance_to(Vector3(0,0.02,-14))<=8)) and get_parent().get_node("FleetControl").transfer.get("id","") != drone.identity
func reload_ammo(id: String) -> bool:
	var d: Node = fleet.drone(id)
	if not _at_home(d) or d.module_efficiency("sentry_mount")<=0 or int(ammo.get(id,0))>40 or d.payload_remaining()<0.4 or not get_parent().get_node("Inventory").spend_scrap(10): return false
	ammo[id] = int(ammo.get(id,0))+20
	d.cargo_kg += 0.4
	changed.emit()
	return true
func load_trap(id: String) -> bool:
	var d: Node = fleet.drone(id)
	if not _at_home(d) or d.module_efficiency("trap_layer")<=0 or int(kits.get(id,0))>=8 or d.payload_remaining()<1 or not get_parent().get_node("Inventory").spend_scrap(6): return false
	kits[id] = int(kits.get(id,0))+1
	d.cargo_kg += 1
	changed.emit()
	return true
func _target(id: String) -> Node:
	if id.begins_with("nest:"):
		var band := id.trim_prefix("nest:")
		if band.is_valid_int() and int(band)>=0 and int(band)<6: return get_parent().get_node("Trace").nests[int(band)]
	return get_parent().get_node("Threats").actors.get(id)
func _clear(drone: Node, target: Node) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(drone.global_position+Vector3(0,0.7,0),target.global_position+Vector3(0,0.6,0),1,[drone.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or hit.collider == target or target.is_ancestor_of(hit.collider)
func observed(drone: Node, target: Node) -> bool:
	if drone==null or target==null or not drone.deployed or not drone.has_power() or target.integrity<=0 or get_parent().get_node("Radio").quality(drone)<=0 or not _clear(drone,target): return false
	var destination: Vector3 = target.global_position+Vector3(0,0.6,0)
	if preload("res://scripts/sensors/sensor_router.gd").working(drone) and drone.get_node("CCD").in_frustum(destination): return true
	var relative: Vector3 = drone.global_basis.inverse()*(destination-drone.global_position-Vector3(0,0.7,0))
	if drone.module_efficiency("thermal")>0 and target.get_meta("thermal",0.0)>=0.2 and relative.length()<=35*drone.module_efficiency("thermal") and relative.z<0 and absf(relative.x)<=-relative.z: return true
	var sonar: Node = drone.get_node("Sonar")
	if drone.module_efficiency("sonar")>0 and sonar.clock-sonar.last_ping<=sonar.echo_lifetime:
		for at in sonar.hostile_contacts:
			if at.distance_to(destination)<1.0: return true
	return false
func contacts(id: String) -> Array:
	var d: Node = fleet.drone(id)
	var result := []
	for target in get_parent().get_node("Threats").actors.values():
		if observed(d,target): result.append({"id":target.identity,"at":target.position})
	for i in 6:
		var target: Node = get_parent().get_node("Trace").nests[i]
		if observed(d,target): result.append({"id":"nest:%d" % i,"at":target.position})
	return result
func fire(id: String, target_id: String) -> bool:
	var d: Node = fleet.drone(id)
	var target: Node = _target(target_id)
	if d==null or d.module_efficiency("sentry_mount")<=0 or int(ammo.get(id,0))<1 or cooldowns.get(id,0.0)>0 or pending.has(id) or not observed(d,target) or d.position.distance_to(target.position)>35 or (not d.hull().external_power and d.battery<0.002): return false
	pending[id] = {"target":target_id,"remaining":get_parent().get_node("Radio").latency(d)}
	status = "Fire order transmitted. Link and observation will be checked on arrival."
	return true
func _shoot(id: String, target_id: String) -> bool:
	var d: Node = fleet.drone(id)
	var target: Node = _target(target_id)
	if d==null or target==null or int(ammo.get(id,0))<1 or d.module_efficiency("sentry_mount")<=0 or not observed(d,target) or d.position.distance_to(target.position)>35: return false
	if d.hull().external_power:
		var tether: Node = get_parent().get_node("PowerTether")
		if territory.power_links.has(id):
			var band: int = territory.power_links[id]
			if territory.sites[band].battery<0.002/0.9: return false
			territory.sites[band].battery -= 0.002/0.9
		else:
			var donor: Node = fleet.drone(tether.links.get(id,""))
			if donor==null or donor.battery<0.002/0.9: return false
			donor.battery -= 0.002/0.9
	else:
		if d.battery<0.002: return false
		d.battery -= 0.002
	ammo[id] = int(ammo[id])-1
	d.cargo_kg = maxf(0,d.cargo_kg-0.02)
	cooldowns[id] = 2.0
	target.apply_damage(40*d.module_efficiency("sentry_mount"))
	get_parent().get_node("Emissions").pulse("sound",d.position,100,d.identity)
	changed.emit()
	return true
func lay_trap(id: String) -> bool:
	var d: Node = fleet.drone(id)
	if d==null or not d.deployed or not d.has_power() or d.module_efficiency("trap_layer")<=0 or int(kits.get(id,0))<1 or traps.size()>=128 or get_parent().get_node("Radio").quality(d)<=0: return false
	var at: Vector3 = d.position+d.basis*Vector3(0,0,-2)
	var band := Layout.band_at(at)
	if at.z>=-10 or absf(at.x)>58 or at.z < -608 or not territory.sites[band].held: return false
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1,0.1,1)
	query.shape = shape
	query.transform.origin = Vector3(at.x,0.15,at.z)
	query.collision_mask = 1
	if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return false
	var record := {"serial":next_trap,"at":[at.x,0.02,at.z],"spent":false}
	traps.append(record)
	next_trap += 1
	kits[id] = int(kits[id])-1
	d.cargo_kg = maxf(0,d.cargo_kg-1)
	_trap_view(record)
	changed.emit()
	return true
func _trap_view(record: Dictionary) -> void:
	var view := Kit.box(self,"Trap%d" % record.serial,Vector3(0.8,0.06,0.8),Vector3(record.at[0],0.05,record.at[2]),"metal",false)
	for x in [-0.3,0.3]: Kit.box(view,"SpringJaw",Vector3(0.06,0.13,0.65),Vector3(x,0.08,0),"rock",false)
	view.scale.y = 0.25 if record.spent else 1.0
	trap_views[int(record.serial)] = view
func toggle_decoy(id: String) -> bool:
	var d: Node = fleet.drone(id)
	if d==null or not d.deployed or not d.has_power() or d.module_efficiency("noise_decoy")<=0 or get_parent().get_node("Radio").quality(d)<=0: return false
	decoys[id] = not decoys.get(id,false)
	changed.emit()
	return true
func footprint_clear(band: int, excluded: Array[RID] = []) -> bool:
	for i in 5:
		var query := PhysicsShapeQueryParameters3D.new()
		var shape := BoxShape3D.new()
		shape.size = Perimeter.SIZES[i]
		query.shape = shape
		query.transform.origin = center(band)+Perimeter.OFFSETS[i]
		query.exclude = excluded
		query.collision_mask = 1
		if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return false
	return true
func install_perimeter(band: int) -> void:
	if perimeters.has(str(band)): return
	perimeters[str(band)] = {"health":[200.0,200.0,200.0,200.0,200.0],"on":false}
	_perimeter_view(band)
	changed.emit()
func _perimeter_view(band: int) -> void:
	var view := Perimeter.new()
	view.position = center(band)
	add_child(view)
	views[band] = view
	_apply_perimeter(band)
func _apply_perimeter(band: int) -> void:
	for i in 5:
		var body: StaticBody3D = views[band].get_node("Section%d" % i)
		var intact: bool = perimeters[str(band)].health[i]>0
		body.collision_layer = 1 if intact else 0
		for mesh in body.find_children("*","MeshInstance3D",true,false): mesh.visible = intact
func set_fence(band: int, enabled: bool) -> bool:
	if not perimeters.has(str(band)) or (band>0 and not territory.online(band)): return false
	perimeters[str(band)].on = enabled
	_update_home_load()
	changed.emit()
	return true
func _update_home_load() -> void:
	life.defense_load_kw = 2.0 if perimeters.get("0",{}).get("on",false) else 0.0
func fence_live(band: int) -> bool:
	if not perimeters.get(str(band),{}).get("on",false): return false
	if band==0: return not life.dead and life.supplied_fraction>0.0
	return territory.sites[band].pylon and territory.sites[band].condition>0.0 and territory.sites[band].battery>0.0
func _near_section(at: Vector3, band: int, i: int, reach: float) -> bool:
	var point: Vector3 = at-center(band)-Perimeter.OFFSETS[i]
	var half: Vector3 = Perimeter.SIZES[i]*0.5
	var nearest := Vector3(clampf(point.x,-half.x,half.x),clampf(point.y,-half.y,half.y),clampf(point.z,-half.z,half.z))
	return point.distance_to(nearest)<=reach
func _contact_damage(band: int, fraction: float) -> void:
	if fraction<=0 or not perimeters.has(str(band)): return
	for actor in get_parent().get_node("Threats").actors.values():
		if actor.integrity<=0: continue
		for i in 5:
			var contact_reach: float = 1.8 if actor.fence_grip_band==band and actor.strike_remaining>0 else 0.65
			if perimeters[str(band)].health[i]>0 and _near_section(actor.position+Vector3(0,0.6,0),band,i,contact_reach):
				var endpoint := _section_aim(actor.position,band,i)
				var ray := PhysicsRayQueryParameters3D.create(actor.position+Vector3(0,0.6,0),endpoint,1,[actor.get_rid()])
				var hit := get_world_3d().direct_space_state.intersect_ray(ray)
				if hit.is_empty() or not views[band].is_ancestor_of(hit.collider): continue
				actor.apply_damage(40*fraction)
				break
func _home_energy(fraction: float) -> void:
	if perimeters.get("0",{}).get("on",false): _contact_damage(0,fraction)
	_update_home_load()
func _section_aim(at: Vector3, band: int, i: int) -> Vector3:
	var endpoint: Vector3 = center(band)+Perimeter.OFFSETS[i]
	# End inside the thin collider; Jolt may omit a ray ending exactly on its skin.
	if Perimeter.SIZES[i].x>Perimeter.SIZES[i].z:
		endpoint.x = clampf(at.x,endpoint.x-Perimeter.SIZES[i].x/2+0.01,endpoint.x+Perimeter.SIZES[i].x/2-0.01)
	else:
		endpoint.z = clampf(at.z,endpoint.z-Perimeter.SIZES[i].z/2+0.01,endpoint.z+Perimeter.SIZES[i].z/2-0.01)
	return endpoint
func damage_section(band: int, index: int, amount: float) -> bool:
	if not perimeters.has(str(band)) or index<0 or index>=5 or not is_finite(amount) or amount<=0: return false
	perimeters[str(band)].health[index] = maxf(0,perimeters[str(band)].health[index]-amount)
	_apply_perimeter(band)
	changed.emit()
	return true
func attack_near(actor: Node, amount: float) -> bool:
	for key in perimeters:
		var band := int(key)
		for i in 5:
			if perimeters[key].health[i]<=0 or not _near_section(actor.position+Vector3(0,0.6,0),band,i,1.8): continue
			var endpoint := _section_aim(actor.position,band,i)
			var ray := PhysicsRayQueryParameters3D.create(actor.position+Vector3(0,0.6,0),endpoint,1,[actor.get_rid()])
			var hit := get_world_3d().direct_space_state.intersect_ray(ray)
			if not hit.is_empty() and views[band].is_ancestor_of(hit.collider):
				actor.fence_grip_band = band
				var applied := damage_section(band,i,amount)
				if band==0 or territory.online(band): status = "%s SECTION %d STRUCK" % ["HOME" if band==0 else "BAND %d" % (band+1),i+1]
				return applied
	return false
func repair_perimeter(id: String, band: int) -> bool:
	var d: Node = fleet.drone(id)
	if not perimeters.has(str(band)) or d==null or not d.deployed or d.hull_id!="goliath" or not d.has_power() or d.module_efficiency("prefab_winch")<=0 or d.position.distance_to(center(band))>10 or get_parent().get_node("Radio").quality(d)<=0: return false
	var cost := 0
	for health in perimeters[str(band)].health: cost += ceili((200-health)*0.1)
	if cost<=0 or not get_parent().get_node("Inventory").spend_scrap(cost): return false
	perimeters[str(band)].health = [200.0,200.0,200.0,200.0,200.0]
	_apply_perimeter(band)
	changed.emit()
	return true
func _physics_process(delta: float) -> void: advance(delta)
func advance(seconds: float) -> void:
	if not is_finite(seconds) or seconds<=0: return
	for id in cooldowns: cooldowns[id] = maxf(0,cooldowns[id]-seconds)
	for id in pending.keys():
		pending[id].remaining -= seconds
		if pending[id].remaining<=0:
			var target_id: String = pending[id].target
			pending.erase(id)
			status = "Shot fired." if _shoot(id,target_id) else "Fire order lost or target no longer observed."
	for record in traps:
		if record.spent: continue
		for actor in get_parent().get_node("Threats").actors.values():
			var at := Vector3(record.at[0],record.at[1],record.at[2])
			if actor.integrity>0 and actor.position.distance_to(at)<=1.8:
				var ray := PhysicsRayQueryParameters3D.create(at+Vector3(0,0.25,0),actor.position+Vector3(0,0.6,0),1,[actor.get_rid()])
				if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
				actor.apply_damage(120)
				record.spent = true
				trap_views[int(record.serial)].scale.y = 0.25
				get_parent().get_node("Emissions").pulse("sound",at,40,"trap_%d" % record.serial)
				break
	for key in perimeters:
		var band := int(key)
		if band==0 or not fence_live(band): continue
		var cost := 2.0*seconds/3600.0
		var paid: float = minf(cost,territory.sites[band].battery)
		territory.sites[band].battery -= paid
		_contact_damage(band,seconds*paid/cost)
	decoy_clock -= seconds
	while decoy_clock<=0:
		decoy_clock += 2
		for id in decoys:
			var d: Node = fleet.drone(id)
			if decoys[id] and d!=null and d.deployed and d.has_power() and not d.silent_running and d.module_efficiency("noise_decoy")>0: get_parent().get_node("Emissions").pulse("sound",d.position,100,id)
	for d in fleet.get_children():
		for light in d.get_node("Visual").find_children("FloodBeam","SpotLight3D",true,false): light.visible = d.deployed and d.has_power() and not d.silent_running and d.module_efficiency("floodlight")>0
	_update_home_load()
func snapshot() -> Dictionary:
	return {"ammo":ammo.duplicate(),"kits":kits.duplicate(),"cooldowns":cooldowns.duplicate(),"pending":pending.duplicate(true),"decoys":decoys.duplicate(),"decoy_clock":decoy_clock,"traps":traps.duplicate(true),"next_trap":next_trap,"perimeters":perimeters.duplicate(true)}
static func validate(data: Variant) -> bool:
	if not data is Dictionary: return false
	for key in ["ammo","kits","cooldowns","pending","decoys","perimeters"]:
		if not data.get(key) is Dictionary or data[key].size()>32: return false
	for key in ["ammo","kits","cooldowns"]:
		for id in data[key]:
			if not id is String or id.is_empty() or id.length()>80 or not Drone._range(data[key][id],0,60 if key=="ammo" else (8 if key=="kits" else 2)): return false
			if key!="cooldowns" and data[key][id]!=int(data[key][id]): return false
	for id in data.pending:
		var order: Variant = data.pending[id]
		if not id is String or not order is Dictionary or not order.get("target") is String or order.target.length()>80 or not Drone._range(order.get("remaining"),0,5): return false
	for id in data.decoys:
		if not id is String or not data.decoys[id] is bool: return false
	if not Drone._range(data.get("decoy_clock"),0,2) or not Drone._range(data.get("next_trap"),1,1000000) or data.next_trap!=int(data.next_trap) or not data.get("traps") is Array or data.traps.size()>128: return false
	var seen := {}
	for trap in data.traps:
		if not trap is Dictionary or not Drone._range(trap.get("serial"),1,data.next_trap-1) or trap.serial!=int(trap.serial) or seen.has(trap.serial) or not preload("res://scripts/simulation/emission_events.gd").valid_position(trap.get("at")) or not trap.get("spent") is bool: return false
		seen[trap.serial] = true
	for key in data.perimeters:
		if not key is String or not key.is_valid_int() or str(int(key))!=key or int(key)<0 or int(key)>5: return false
		var record: Variant = data.perimeters[key]
		if not record is Dictionary or not record.get("on") is bool or not record.get("health") is Array or record.health.size()!=5: return false
		for health in record.health:
			if not Drone._range(health,0,200): return false
	return true
func restore(data: Dictionary) -> void:
	assert(validate(data))
	for view in views.values():
		remove_child(view)
		view.queue_free()
	views.clear()
	for view in trap_views.values(): view.queue_free()
	trap_views.clear()
	for key in ["ammo","kits","cooldowns","pending","decoys","perimeters"]: set(key,data[key].duplicate(true))
	decoy_clock = data.decoy_clock
	traps = data.traps.duplicate(true)
	next_trap = int(data.next_trap)
	for key in perimeters: _perimeter_view(int(key))
	for record in traps: _trap_view(record)
	_update_home_load()
	changed.emit()
