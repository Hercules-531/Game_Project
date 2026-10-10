extends Node3D
signal changed
const Drone = preload("res://scripts/drones/drone.gd")
const Visual = preload("res://scripts/world/territory_visual.gd")
const Kit = preload("res://scripts/world/surface_kit.gd")
const PRODUCTS = {"pylon":{"mass":600.0,"scrap":80,"seconds":180.0},"fob":{"mass":1400.0,"scrap":150,"seconds":300.0},"perimeter":{"mass":800.0,"scrap":60,"seconds":240.0}}
var sites: Array = []
var cargo: Dictionary = {}
var job: Dictionary = {}
var charge_requests: Dictionary = {}
var visuals: Dictionary = {}
var cargo_views: Dictionary = {}
var cables: Dictionary = {}
var power_links: Dictionary = {}
var power_lines: Dictionary = {}
var status := "Earn the next northern pad with a parked high-gain dish scout."
@onready var fleet: Node = get_parent().get_node("Fleet")
@onready var life: Node = get_parent().get_node("LifeSupport")

static func pad(band: int) -> Vector3:
	return Vector3(0,0.02,-13) if band == 0 else Vector3(8,0.02,-25 - 100 * band)
static func initial_sites() -> Array:
	var result := []
	for i in 6: result.append({"held":i==0,"relay":"","pylon":false,"fob":false,"perimeter":false,"battery":0.0,"condition":100.0})
	return result
func _ready() -> void:
	process_physics_priority = -30
	sites = initial_sites()
	life.energy_step.connect(_grid_step)
func frontier() -> int:
	var result := 0
	for i in range(1,6):
		if not sites[i].held: break
		result = i
	return result
func anchor(id: String, band: int) -> bool:
	var drone: Node = fleet.drone(id)
	if band < 1 or band >= 6: return false
	if (band != frontier()+1 and not sites[band].held) or not get_parent().get_node("Research").has_technology("network") or drone == null or drone.hull().external_power or not drone.deployed or not drone.has_power() or drone.module_efficiency("high_gain_dish") <= 0.0 or drone.position.distance_to(pad(band)) > 6.0 or Vector2(drone.velocity.x,drone.velocity.z).length() > 0.2 or get_parent().get_node("Radio").quality(drone) <= 0.0: return false
	for site in sites:
		if site.relay == id: return false
	sites[band].held = true
	sites[band].relay = id
	status = "Northern pad earned. Keep its relay powered and stationary."
	changed.emit()
	return true
func relay_body(band: int) -> Node:
	return fleet.drone(sites[band].relay) if not sites[band].relay.is_empty() else null
func release_relay(id: String) -> bool:
	for i in range(1,6):
		if sites[i].relay == id:
			sites[i].relay = ""
			status = "Scout relay registration released. A powered pylon or replacement must hold the link."
			changed.emit()
			return true
	return false
func _relay_available(band: int) -> bool:
	if _fixed_relay_available(band): return true
	var drone: Node = relay_body(band)
	return drone != null and not drone.hull().external_power and drone.deployed and drone.has_power() and get_parent().get_node("Radio").drops.get(drone.identity,0.0) <= 0.0 and drone.module_efficiency("high_gain_dish") > 0.0 and drone.position.distance_to(pad(band)) <= 6.0 and Vector2(drone.velocity.x,drone.velocity.z).length() <= 0.2
func _fixed_relay_available(band: int) -> bool:
	return sites[band].pylon and sites[band].condition > 0.0 and sites[band].battery > 0.0 and get_parent().get_node("Radio").drops.get("pylon_%d" % band,0.0) <= 0.0
func radio_origins() -> Array:
	var result := [{"at":Vector3(0,6,-13),"quality":1.0,"rid":RID()}]
	var radio: Node = get_parent().get_node("Radio")
	for band in range(1,6):
		if not sites[band].held or not _relay_available(band): break
		var drone: Node = relay_body(band)
		var fixed := _fixed_relay_available(band)
		var at: Vector3 = pad(band) + Vector3(0,5.5,0) if fixed else drone.global_position + Vector3(0,1.6,0)
		var rid: RID = RID() if fixed else drone.get_rid()
		var previous: Dictionary = result.back()
		var excluded: Array[RID] = []
		if rid.is_valid(): excluded.append(rid)
		if previous.rid.is_valid(): excluded.append(previous.rid)
		var strength: float = minf(previous.quality,radio.edge_quality(previous.at,at,excluded))
		if strength <= 0.0: break
		result.append({"at":at,"quality":strength,"rid":rid})
	return result
func online(band: int) -> bool:
	return band == 0 or (band > 0 and band < 6 and radio_origins().size() > band)
func wired(band: int) -> bool:
	if band < 1 or band >= 6: return false
	for i in range(1,band+1):
		if not sites[i].pylon or sites[i].condition <= 0.0: return false
		var a := pad(i-1)+Vector3(0,4,0)
		var b := pad(i)+Vector3(0,4,0)
		if a.distance_to(b) > 140.0 or not get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1,relay_rids())).is_empty(): return false
	return true
func relay_rids() -> Array[RID]:
	var result: Array[RID] = []
	for view in visuals.values(): result.append(view.get_node("Mast").get_rid())
	return result
func load_prefab(id: String, kind: String) -> bool:
	var drone: Node = fleet.drone(id)
	if kind == "perimeter" and not get_parent().get_node("Research").has_technology("defense"): return false
	if not PRODUCTS.has(kind) or cargo.has(id) or not get_parent().get_node("Research").has_technology("heavy") or drone == null or drone.hull_id != "goliath" or not drone.deployed or not drone.has_power() or drone.module_efficiency("prefab_winch") <= 0.0 or drone.position.distance_to(Vector3(0,0.02,-14)) > 8.0 or drone.payload_remaining() < PRODUCTS[kind].mass or not get_parent().get_node("Inventory").spend_scrap(PRODUCTS[kind].scrap): return false
	cargo[id] = kind
	drone.cargo_kg += PRODUCTS[kind].mass
	_show_cargo(id)
	status = "Paid prefab attached. Take it to an earned northern pad."
	changed.emit()
	return true
func construct(id: String, band: int) -> bool:
	if not cargo.has(id) or not job.is_empty() or band < 0 or band >= 6 or not sites[band].held: return false
	var kind: String = cargo[id]
	if band==0 and kind!="perimeter": return false
	if sites[band][kind] or (kind == "fob" and not sites[band].pylon) or not _worker_ready(id,band,kind) or not _clear(band,kind,id): return false
	job = {"id":id,"band":band,"kind":kind,"remaining":PRODUCTS[kind].seconds}
	fleet.drone(id).work_noise = 2.0
	fleet.drone(id).get_node("Controller").available = false
	status = "Construction underway; hull reserved until its powered work finishes."
	changed.emit()
	return true
func _worker_ready(id: String, band: int, kind: String = "pylon") -> bool:
	var drone: Node = fleet.drone(id)
	var work_at: Vector3 = pad(band)+Vector3(-4,0,-5 if band==0 and kind=="perimeter" else 0)
	return drone != null and drone.deployed and drone.hull_id == "goliath" and drone.has_power() and drone.module_efficiency("prefab_winch") > 0.0 and drone.position.distance_to(work_at) <= 3.0 and Vector2(drone.velocity.x,drone.velocity.z).length() < 0.2 and get_parent().get_node("Radio").quality(drone) > 0.0
func _clear(band: int, kind: String, id: String) -> bool:
	if kind=="perimeter":
		var excluded: Array[RID] = [fleet.drone(id).get_rid()]
		return get_parent().get_node("Defense").footprint_clear(band,excluded)
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.5,5.8,1.3) if kind == "pylon" else Vector3(7,3.4,6)
	var center: Vector3 = pad(band) + Vector3(0,2.9,0) if kind == "pylon" else pad(band) + Vector3(5,1.7,0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY,center)
	query.collision_mask = 1
	query.exclude = [fleet.drone(id).get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
func _physics_process(delta: float) -> void:
	advance(delta)
func advance(seconds: float) -> void:
	if not is_finite(seconds) or seconds <= 0.0: return
	_power_heavy(seconds)
	for i in range(1,6):
		if sites[i].pylon: sites[i].battery = maxf(0.0,sites[i].battery - 0.03 * seconds / 3600.0)
	for id in cargo_views:
		var drone: Node = fleet.drone(id)
		if drone != null: cargo_views[id].global_transform = drone.global_transform.translated_local(Vector3(0,2.15,0.7))
	if not job.is_empty():
		var drone: Node = fleet.drone(job.id)
		if drone != null: drone.get_node("Controller").available = false
		if _worker_ready(job.id,job.band,job.kind):
			drone.work_noise = 2.0
			job.remaining = maxf(0.0,job.remaining - seconds * minf(1.0,drone.module_efficiency("prefab_winch")))
			if job.remaining <= 0.0 and _clear(job.band,job.kind,job.id):
				sites[job.band][job.kind] = true
				drone.cargo_kg = maxf(0.0,drone.cargo_kg - PRODUCTS[job.kind].mass)
				cargo.erase(job.id)
				cargo_views[job.id].queue_free()
				cargo_views.erase(job.id)
				drone.work_noise = 0.0
				drone.get_node("Controller").available = true
				if job.kind=="perimeter": get_parent().get_node("Defense").install_perimeter(job.band)
				else: _refresh_visual(job.band)
				job.clear()
				status = "Structure complete. Empty banks need an intact conduit and paid grid charge."
				changed.emit()
		elif drone != null: drone.work_noise = 0.0
	_charge_cells(seconds)
	_update_requests()
func _update_requests() -> void:
	charge_requests.clear()
	var total := 0.0
	for i in range(1,6):
		if wired(i):
			var demand: float = minf(1.0,maxf(0.0,12.0-sites[i].battery)*3600.0)
			charge_requests[i] = demand
			total += demand
	life.territory_load_kw = total
func _grid_step(fraction: float) -> void:
	for i in charge_requests:
		if wired(i): sites[i].battery = minf(12.0,sites[i].battery + charge_requests[i]*fraction/3600.0)
	_update_requests()
func nearest_pylon(drone: Node, reach: float = 6.0) -> int:
	var result := -1
	var best := reach
	for i in range(1,6):
		if not sites[i].pylon or sites[i].battery <= 0.0 or sites[i].condition <= 0.0: continue
		var gap: float = drone.position.distance_to(pad(i))
		if gap > best: continue
		var ray := PhysicsRayQueryParameters3D.create(drone.position+Vector3(0,1.3,0),pad(i)+Vector3(0,2.1,0),1,[drone.get_rid()])
		# The bank is the intended cable endpoint, so ignore its collision body.
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and not visuals[i].is_ancestor_of(hit.collider): continue
		result = i
		best = gap
	return result
func attach_power(id: String, band: int) -> bool:
	var drone: Node = fleet.drone(id)
	if drone == null or not drone.deployed or drone.destroyed() or not drone.hull().external_power or power_links.has(id) or get_parent().get_node("PowerTether").links.has(id) or nearest_pylon(drone,4.0) != band: return false
	power_links[id] = band
	_make_power_line(id)
	changed.emit()
	return true
func release_power(id: String) -> bool:
	if not power_links.has(id): return false
	power_links.erase(id)
	power_lines[id].queue_free()
	power_lines.erase(id)
	var drone: Node = fleet.drone(id)
	if drone != null: drone.get_node("Controller").stop()
	changed.emit()
	return true
func supported(id: String) -> bool:
	var drone: Node = fleet.drone(id)
	return power_links.has(id) and drone != null and not drone.destroyed() and drone.deployed and nearest_pylon(drone) == int(power_links[id]) and get_parent().get_node("DronePower").required_kw(drone) <= 64.0
func _power_heavy(seconds: float) -> void:
	for id in power_links.keys():
		if not supported(id):
			release_power(id)
			continue
		var drone: Node = fleet.drone(id)
		var band: int = power_links[id]
		if not get_parent().get_node("Orders").field_powered(id):
			var cost: float = get_parent().get_node("DronePower").required_kw(drone) * seconds / 3240.0
			sites[band].battery = maxf(0.0,sites[band].battery-cost)
			if sites[band].battery <= 0.0:
				release_power(id)
				continue
		var a: Vector3 = drone.global_position+Vector3(0,1.3,0)
		var b := pad(band)+Vector3(0,2.1,0)
		var line: MeshInstance3D = power_lines[id]
		line.global_position = (a+b)*0.5
		line.basis = Basis(Quaternion(Vector3.UP,(b-a).normalized()))
		line.mesh.height = a.distance_to(b)
func _make_power_line(id: String) -> void:
	var line := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = 0.045
	shape.bottom_radius = 0.045
	shape.radial_segments = 6
	line.mesh = shape
	line.material_override = Kit.material("metal")
	add_child(line)
	power_lines[id] = line
func _charge_cells(seconds: float) -> void:
	for drone in fleet.get_children():
		if not drone.deployed or drone.destroyed() or drone.hull().external_power: continue
		var band := nearest_pylon(drone,4.0)
		if band < 0: continue
		var delivered: float = minf(sites[band].battery*0.9,minf(seconds/3600.0,drone.hull().battery_kwh-drone.battery))
		sites[band].battery -= delivered/0.9
		drone.battery += delivered
func _show_cargo(id: String) -> void:
	var view := Visual.new()
	view.kind = "cargo"
	add_child(view)
	cargo_views[id] = view
func _refresh_visual(band: int) -> void:
	if visuals.has(band):
		remove_child(visuals[band])
		visuals[band].queue_free()
	var view := Visual.new()
	view.kind = "fob" if sites[band].fob else "pylon"
	view.position = pad(band)
	add_child(view)
	view.add_to_group("sensor_landmarks")
	view.set_meta("classification","Forward depot" if sites[band].fob else "Charging pylon")
	view.set_meta("thermal",0.2)
	visuals[band] = view
	if not cables.has(band):
		var a := pad(band-1)+Vector3(0,3.9,0)
		var b := pad(band)+Vector3(0,3.9,0)
		var cable := Kit.box(self,"Conduit%d" % band,Vector3(0.05,0.05,a.distance_to(b)),(a+b)*0.5,"metal",false)
		cable.look_at(b,Vector3.UP)
		cables[band] = cable
func snapshot() -> Dictionary:
	return {"sites":sites.duplicate(true),"cargo":cargo.duplicate(),"job":job.duplicate(),"power_links":power_links.duplicate()}
static func validate(data: Variant) -> bool:
	if not data is Dictionary or not data.get("sites") is Array or data.sites.size() != 6 or not data.get("cargo") is Dictionary or data.cargo.size() > 32 or not data.get("job") is Dictionary or not data.get("power_links") is Dictionary or data.power_links.size() > 32: return false
	var gap := false
	var seen := {}
	for i in 6:
		var site: Variant = data.sites[i]
		if not site is Dictionary or not site.get("held") is bool or not site.get("pylon") is bool or not site.get("fob") is bool or not site.get("relay") is String or site.relay.length() > 80 or not Drone._range(site.get("battery"),0,12) or not Drone._range(site.get("condition"),0,100): return false
		if not site.get("perimeter",false) is bool or (site.get("perimeter",false) and not site.held): return false
		if i == 0 and (not site.held or site.pylon or site.fob or not site.relay.is_empty() or site.battery != 0.0): return false
		if gap and site.held: return false
		gap = not site.held
		if (site.pylon or site.fob or not site.relay.is_empty()) and not site.held: return false
		if site.fob and not site.pylon: return false
		if not site.pylon and site.battery > 0.0: return false
		if not site.relay.is_empty():
			if seen.has(site.relay): return false
			seen[site.relay] = true
	for id in data.cargo:
		if not id is String or id.is_empty() or not PRODUCTS.has(data.cargo[id]): return false
	for id in data.power_links:
		var band: Variant = data.power_links[id]
		if not id is String or not Drone._range(band,1,5) or band != int(band) or not data.sites[int(band)].pylon: return false
	if data.job.is_empty(): return true
	var j: Dictionary = data.job
	if not j.get("id") is String or not data.cargo.has(j.id) or j.get("kind") != data.cargo[j.id] or not Drone._range(j.get("band"),0 if j.kind=="perimeter" else 1,5) or j.band != int(j.band) or not Drone._range(j.get("remaining"),0,PRODUCTS[j.kind].seconds): return false
	return data.sites[int(j.band)].held and not data.sites[int(j.band)].get(j.kind,false) and (j.kind != "fob" or data.sites[int(j.band)].pylon)
func restore(data: Dictionary) -> void:
	assert(validate(data))
	for view in visuals.values():
		remove_child(view)
		view.queue_free()
	visuals.clear()
	for view in cargo_views.values(): view.queue_free()
	cargo_views.clear()
	for view in cables.values(): view.queue_free()
	cables.clear()
	for view in power_lines.values(): view.queue_free()
	power_lines.clear()
	sites = data.sites.duplicate(true)
	for site in sites: site.perimeter = site.get("perimeter",false)
	cargo = data.cargo.duplicate()
	job = data.job.duplicate()
	power_links = data.power_links.duplicate()
	for i in range(1,6):
		if sites[i].pylon: _refresh_visual(i)
	for id in cargo: _show_cargo(id)
	for id in power_links: _make_power_line(id)
	if not job.is_empty(): fleet.drone(job.id).get_node("Controller").available = false
	_update_requests()
	changed.emit()
