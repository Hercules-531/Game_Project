extends CharacterBody3D

signal configuration_changed
const CATALOG = preload("res://resources/drones/opening_fleet.tres")
var identity: String = ""
var hull_id: String = "mule"
var modules: Dictionary = {}
var condition: Dictionary = {}
var cargo_kg: float = 0.0
var battery: float = 1.0
var deployed: bool = false
var speed_multiplier: float = 1.0
var terrain_multiplier: float = 1.0
var work_noise: float = 0.0
var silent_running: bool = false
var components: Dictionary = {"joints":100.0,"cell":100.0,"armor":100.0}
var faults: Dictionary = {}
const Part = preload("res://scripts/drones/part_condition.gd")

func has_power() -> bool:
	if component_efficiency("cell") <= 0.0:
		return false
	if battery > 0.0 and not hull().external_power:
		return true
	if get_parent() == null or get_parent().get_parent() == null:
		return false
	var orders: Node = get_parent().get_parent().get_node_or_null("Orders")
	if orders != null and orders.field_powered(identity): return true
	var tether: Node = get_parent().get_parent().get_node_or_null("PowerTether")
	return hull().external_power and tether != null and tether.supported(identity)

func component_efficiency(part: String) -> float:
	return 0.0 if faults.get(part,0.0) > 0.0 else Part.efficiency(components[part])

func module_efficiency(id: String) -> float:
	if id != "sealed_housing" and component_efficiency("cell") <= 0.0:
		return 0.0
	var efficiency := 0.0
	for socket in modules:
		if modules[socket] == id and faults.get(socket,0.0) <= 0.0:
			efficiency = maxf(efficiency,Part.efficiency(condition[socket]))
	return efficiency


func _ready() -> void:
	floor_max_angle = deg_to_rad(hull().slope_degrees)
	floor_snap_length = 0.4
	var collision := get_node_or_null("Collision") as CollisionShape3D
	if collision != null:
		var shape := BoxShape3D.new()
		shape.size = collision_size(hull_id)
		collision.shape = shape
		collision.position.y = shape.size.y * 0.5


static func collision_size(frame_id: String) -> Vector3:
	if frame_id == "biped": return Vector3(0.78,1.8,0.8)
	if frame_id == "goliath": return Vector3(3.4,2.3,3.6)
	if frame_id == "tender": return Vector3(1.9,1.5,2.3)
	if frame_id == "tracked":
		return Vector3(1.6,1.05,1.7)
	return Vector3(1.86,1.05,0.9) if frame_id == "hover" else Vector3(1.6,1.05,1.7)


func hull() -> Resource:
	return CATALOG.hull(hull_id)


func module_mass() -> float:
	var mass := 0.0
	for id in modules.values():
		mass += CATALOG.module(id).mass_kg
	return mass


func payload_remaining() -> float:
	return hull().payload_kg - module_mass() - cargo_kg


func draw_kw() -> float:
	var draw: float = hull().idle_kw
	for id in modules.values():
		draw += CATALOG.module(id).draw_kw
	return draw


func can_install(socket: String, module_id: String) -> bool:
	var part: Resource = CATALOG.module(module_id)
	if part == null or not hull().sockets.has(socket) or modules.has(socket):
		return false
	var slot: Dictionary = hull().sockets[socket]
	return slot.category == part.category and slot.size >= part.size and part.mass_kg <= payload_remaining()


func install(socket: String, module_id: String, part_condition: float = 100.0) -> bool:
	if not can_install(socket,module_id) or not is_finite(part_condition) or part_condition < 0.0 or part_condition > 100.0:
		return false
	modules[socket] = module_id
	condition[socket] = part_condition
	configuration_changed.emit()
	return true


func remove_module(socket: String) -> Dictionary:
	if not modules.has(socket):
		return {}
	var part := {"id":modules[socket],"condition":condition[socket]}
	modules.erase(socket)
	condition.erase(socket)
	faults.erase(socket)
	configuration_changed.emit()
	return part


func snapshot() -> Dictionary:
	return {"id":identity,"hull":hull_id,"modules":modules.duplicate(),"condition":condition.duplicate(),
		"cargo_kg":cargo_kg,"battery":battery,"deployed":deployed,"components":components.duplicate(),"faults":faults.duplicate(),"position":[position.x,position.y,position.z],"yaw":rotation.y}


static func validate(data: Variant) -> bool:
	if not data is Dictionary or not data.get("id") is String or data.id.is_empty() or data.id.length() > 80:
		return false
	if data.has("deployed") and not data.deployed is bool:
		return false
	if data.has("components"):
		if not data.components is Dictionary or data.components.size() != 3:
			return false
		for key in ["joints","cell","armor"]:
			if not _range(data.components.get(key),0.0,100.0):
				return false
	if data.has("faults"):
		if not data.faults is Dictionary or data.faults.size() > 20:
			return false
		for key in data.faults:
			if key not in ["joints","cell","armor"] and not data.get("modules",{}).has(key):
				return false
			if not _range(data.faults[key],0.0,8.0):
				return false
	var frame: Resource = CATALOG.hull(str(data.get("hull","")))
	if frame == null or not data.get("modules") is Dictionary or not data.get("condition") is Dictionary:
		return false
	if data.modules.size() != data.condition.size():
		return false
	var mass := 0.0
	for socket in data.modules:
		var part: Resource = CATALOG.module(str(data.modules[socket]))
		if part == null or not frame.sockets.has(socket):
			return false
		var slot: Dictionary = frame.sockets[socket]
		if slot.category != part.category or slot.size < part.size or not _range(data.condition.get(socket),0.0,100.0):
			return false
		mass += part.mass_kg
	if not _range(data.get("cargo_kg"),0.0,frame.payload_kg - mass) or not _range(data.get("battery"),0.0,frame.battery_kwh):
		return false
	var location: Variant = data.get("position")
	if not location is Array or location.size() != 3 or not _range(data.get("yaw"),-1000000.0,1000000.0):
		return false
	for coordinate in location:
		if not _range(coordinate,-1000000.0,1000000.0):
			return false
	return true


static func _range(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and value <= maximum


func restore(data: Dictionary) -> void:
	assert(validate(data))
	identity = data.id
	hull_id = data.hull
	modules = data.modules.duplicate()
	condition = data.condition.duplicate()
	cargo_kg = data.cargo_kg
	battery = data.battery
	deployed = data.get("deployed",false)
	components = data.get("components",{"joints":100.0,"cell":100.0,"armor":100.0}).duplicate()
	faults = data.get("faults",{}).duplicate()
	position = Vector3(data.position[0],data.position[1],data.position[2])
	rotation.y = data.yaw
	configuration_changed.emit()
