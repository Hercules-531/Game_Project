extends Node3D
signal changed
const Drone = preload("res://scripts/drones/drone.gd")
const Cargo = preload("res://scripts/salvage/cargo_hold.gd")
const Visual = preload("res://scripts/artifacts/artifact_visual.gd")
const KIT = preload("res://scripts/world/surface_kit.gd")
const DEFINITIONS = {
	"thermal":{"name":"Thermal Siphon","at":Vector3(-16,0.02,-170)},
	"neural":{"name":"Neural Interface Core","at":Vector3(24,0.02,-360)},
	"photonic":{"name":"Photonic Converter","at":Vector3(-18,0.02,-485)}}
var devices: Dictionary = {}
var bodies: Dictionary = {}
var status := "Recover a device, unload it, then choose a universal socket at home."
@onready var fleet: Node = get_parent().get_node("Fleet")
func _ready() -> void:
	for id in DEFINITIONS:
		devices[id] = {"state":"available","carrier":"","socket":""}
		var body := Node3D.new()
		body.name = id
		add_child(body)
		var visual := Visual.new()
		visual.kind = id
		body.add_child(visual)
		var solid := StaticBody3D.new()
		solid.name = "Body"
		body.add_child(solid)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.48,0.55,0.4)
		collision.shape = shape
		collision.position.y = 0.3
		solid.add_child(collision)
		body.add_to_group("sensor_landmarks")
		body.set_meta("thermal",0.25)
		body.set_meta("classification","Anomalous device")
		bodies[id] = body
		_apply(id)
func fitted(socket: String) -> String:
	for id in devices:
		if devices[id].state=="fitted" and devices[id].socket==socket: return id
	return ""
func on_hull(drone: Node, id: String) -> bool:
	return drone!=null and not drone.destroyed() and fitted(drone.identity)==id
func hull_mass(id: String) -> float: return 0.0 if fitted(id).is_empty() else 1.0
func small(drone: Node, id: String) -> bool: return on_hull(drone,id) and not drone.hull().external_power
func heavy(drone: Node, id: String) -> bool: return on_hull(drone,id) and drone.hull().external_power
func heat_at(at: Vector3, exclude_id: String = "") -> bool:
	for d in fleet.get_children():
		if not d.deployed or not heavy(d,"thermal") or d.position.distance_to(at)>10: continue
		var excluded: Array[RID] = [d.get_rid()]
		for other in fleet.get_children():
			if other.identity==exclude_id or other.position.distance_to(at)<0.05: excluded.append(other.get_rid())
		var operator: Node = get_parent().get_node("Operator")
		if operator.position.distance_to(at)<0.05: excluded.append(operator.get_rid())
		var ray := PhysicsRayQueryParameters3D.create(d.position+Vector3(0,1.3,0),at+Vector3(0,0.7,0),1,excluded)
		if get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): return true
	return false
func _at_home(socket: String) -> bool:
	if socket=="bunker": return true
	var d: Node = fleet.drone(socket)
	return d!=null and not d.destroyed() and (not d.deployed or (d.hull().external_power and d.position.distance_to(Vector3(0,0.02,-14))<=8)) and get_parent().get_node("FleetControl").transfer.get("id","")!=socket
func fit(id: String, socket: String) -> bool:
	if not devices.has(id) or devices[id].state!="delivered" or not fitted(socket).is_empty() or not _at_home(socket): return false
	var d: Node = fleet.drone(socket)
	if socket!="bunker" and (d==null or d.payload_remaining()<1): return false
	devices[id] = {"state":"fitted","carrier":"","socket":socket}
	_sync()
	if d!=null: d.configuration_changed.emit()
	_apply(id)
	status = DEFINITIONS[id].name+" fitted."
	changed.emit()
	return true
func remove(socket: String) -> bool:
	var id := fitted(socket)
	if id.is_empty() or not _at_home(socket): return false
	devices[id] = {"state":"delivered","carrier":"","socket":""}
	_sync()
	var d: Node = fleet.drone(socket)
	if d!=null: d.configuration_changed.emit()
	_apply(id)
	status = DEFINITIONS[id].name+" returned to workshop storage."
	changed.emit()
	return true
func recover_nearest(d: Node) -> bool:
	if not Cargo.can_load(d,1): return false
	var chosen := ""
	var gap := 3.0
	for id in devices:
		var distance: float = d.position.distance_to(bodies[id].position)
		if devices[id].state=="available" and distance<=gap:
			chosen = id
			gap = distance
	if chosen.is_empty(): return false
	var ray := PhysicsRayQueryParameters3D.create(d.position+Vector3(0,0.7,0),bodies[chosen].position+Vector3(0,0.3,0),1,[d.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty() and not bodies[chosen].is_ancestor_of(hit.collider): return false
	devices[chosen] = {"state":"carried","carrier":d.identity,"socket":""}
	d.cargo_kg += 1
	_apply(chosen)
	status = "Anomaly attached. Unload it before fitting a socket."
	changed.emit()
	return true
func deliver(d: Node, exterior: bool = false) -> int:
	if d==null: return 0
	var gantry: bool = exterior and d.hull().external_power and d.position.distance_to(Vector3(0,0.02,-14))<=8
	if not gantry and (d.deployed or d.position.z < -6): return 0
	var count := 0
	for id in devices:
		if devices[id].state!="carried" or devices[id].carrier!=d.identity: continue
		devices[id] = {"state":"delivered","carrier":"","socket":""}
		d.cargo_kg = maxf(0,d.cargo_kg-1)
		_apply(id)
		count += 1
	_sync()
	if count>0: changed.emit()
	return count
func _sync() -> void:
	var life: Node = get_parent().get_node("LifeSupport")
	life.artifact_heat_multiplier = 0.7 if fitted("bunker")=="thermal" else 1.0
	life.artifact_aux_kw = 0.25 if fitted("bunker")=="photonic" else 0.0
	get_parent().get_node("Orders").logic_rate = 3.0 if fitted("bunker")=="neural" else 1.0
func _apply(id: String) -> void:
	var record: Dictionary = devices[id]
	bodies[id].visible = record.state in ["available","carried","fitted"]
	bodies[id].set_meta("thermal",0.25 if bodies[id].visible else 0.0)
	bodies[id].get_node("Body").collision_layer = 1 if record.state=="available" else 0
	if record.state=="available": bodies[id].position = DEFINITIONS[id].at
func _physics_process(_delta: float) -> void:
	for id in devices:
		var record: Dictionary = devices[id]
		var d: Node = fleet.drone(record.carrier if record.state=="carried" else record.socket)
		if d!=null:
			bodies[id].global_transform = d.global_transform.translated_local(Vector3(0,2.2 if d.hull().external_power else 1.1,0.5))
		elif record.state=="fitted" and record.socket=="bunker":
			bodies[id].global_position = get_parent().get_node("Bunker/LifeBreaker").global_position+Vector3(0.25,0.1,0.15)
func snapshot() -> Dictionary: return devices.duplicate(true)
static func validate(data: Variant) -> bool:
	if not data is Dictionary or data.size()!=3: return false
	var occupied := {}
	for id in DEFINITIONS:
		var record: Variant = data.get(id)
		if not record is Dictionary or record.get("state") not in ["available","carried","delivered","fitted"] or not record.get("carrier") is String or not record.get("socket") is String or record.carrier.length()>80 or record.socket.length()>80: return false
		if (record.state=="carried")!=(not record.carrier.is_empty()) or (record.state=="fitted")!=(not record.socket.is_empty()): return false
		if record.state=="fitted":
			if occupied.has(record.socket): return false
			occupied[record.socket] = true
	return true
func restore(data: Dictionary) -> void:
	assert(validate(data))
	devices = data.duplicate(true)
	for id in devices: _apply(id)
	_sync()
	for d in fleet.get_children(): d.configuration_changed.emit()
	changed.emit()
