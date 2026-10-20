extends Node3D
signal changed
const MODEL = preload("res://scripts/drones/drone.gd")
const Jumper = preload("res://scripts/recovery/jumper.gd")
const Winch = preload("res://scripts/recovery/winch.gd")
const Strip = preload("res://scripts/recovery/field_strip.gd")
const DRONE = preload("res://scenes/drones/drone.tscn")
const SITES = {"derelict_01":Vector3(10,0.02,-88),"derelict_02":Vector3(-12,0.02,-125)}
var records: Dictionary = {}
var bodies: Dictionary = {}
var lines: Dictionary = {}
var status := "Approach a derelict with recovery equipment."
@onready var fleet: Node3D = get_parent().get_node("Fleet")
@onready var inventory: Node = get_parent().get_node("Inventory")

func _ready() -> void:
	for id in SITES:
		_spawn(id)

func _spawn(id: String) -> void:
	var body = DRONE.instantiate()
	body.identity = id
	body.name = id
	body.hull_id = "tracked"
	body.deployed = true
	body.battery = 0.0
	body.position = SITES[id]
	body.components = {"joints":55.0,"cell":60.0,"armor":42.0}
	body.install("sensor_a","sonar",45.0)
	body.install("sensor_b","thermal",60.0)
	body.install("tool","heavy_winch",55.0)
	add_child(body)
	body.add_to_group("sensor_landmarks")
	body.set_meta("classification","Tracked chassis")
	body.set_meta("thermal",0.05)
	body.get_node("Controller").set_physics_process(false)
	bodies[id] = body
	records[id] = {"state":"dormant","owner":"","remaining":0.0,"blocked":0.0,"parts":[]}

func nearby(donor: Node) -> Array:
	var ids := []
	if donor == null:
		return ids
	for id in bodies:
		if records[id].state in ["dormant","towing","stripping","stripped"] and donor.global_position.distance_to(bodies[id].global_position) <= 4.0:
			ids.append(id)
	return ids

func hotwire(donor: Node, target: Node) -> bool:
	var id: String = target.identity if target != null else ""
	if not records.has(id):
		return Jumper.transfer(donor,target) > 0.0
	if records[id].state != "dormant" or fleet.get_child_count() >= 32 or Jumper.transfer(donor,target) <= 0.0:
		return false
	_claim(id)
	status = "Frame awake. Original condition retained."
	changed.emit()
	return true

func _claim(id: String) -> void:
	var body: Node3D = bodies[id]
	body.reparent(fleet,true)
	body.get_node("Controller").set_physics_process(true)
	records[id].state = "awake"
	records[id].owner = ""
	if get_parent().get_node("FleetPanel").panel.visible:
		get_parent().get_node("FleetPanel").open()

func start_tow(donor: Node, id: String) -> bool:
	if not records.has(id) or records[id].state != "dormant" or not Winch.can_tow(donor,bodies[id]):
		return false
	for record in records.values():
		if record.state == "towing" and record.owner == donor.identity:
			return false
	records[id].state = "towing"
	records[id].owner = donor.identity
	donor.speed_multiplier = 0.25
	donor.work_noise = 2.0
	_make_tether(id)
	status = "Heavy tow attached. Crawl; keep cable within 6m."
	changed.emit()
	return true

func _make_tether(id: String) -> void:
	var line := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.035,0.035,1.0)
	line.mesh = mesh
	line.material_override = preload("res://scripts/world/surface_kit.gd").material("metal")
	add_child(line)
	lines[id] = line

func release_tow(id: String) -> void:
	if not records.has(id) or records[id].state != "towing":
		return
	var donor: Node = fleet.drone(records[id].owner)
	if donor != null:
		donor.speed_multiplier = 1.0
		donor.work_noise = 0.0
	records[id].state = "dormant"
	records[id].owner = ""
	records[id].blocked = 0.0
	if lines.has(id):
		lines[id].queue_free()
		lines.erase(id)
	changed.emit()

func start_strip(donor: Node, id: String) -> bool:
	if not records.has(id) or records[id].state != "dormant" or not Strip.can_strip(donor,bodies[id]):
		return false
	records[id].state = "stripping"
	records[id].owner = donor.identity
	records[id].remaining = 20.0
	status = "Cutting: 20 seconds. Stay within reach."
	changed.emit()
	return true

func _physics_process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	for id in records:
		var record: Dictionary = records[id]
		if record.state not in ["stripping","towing"]:
			continue
		var donor: Node = fleet.drone(record.owner)
		var body: CharacterBody3D = bodies[id]
		if record.state == "stripping":
			if not Strip.can_strip(donor,body):
				continue
			record.remaining = maxf(0.0,record.remaining - delta)
			donor.work_noise = 1.0
			if record.remaining <= 0.0:
				for socket in body.modules.keys():
					record.parts.append(body.remove_module(socket))
				donor.cargo_kg += 20.0
				donor.work_noise = 0.0
				record.state = "parts"
				body.get_node("Visual").rebuild()
				status = "Parts packed. Dock to add them to stock; frame stays."
				changed.emit()
		else:
			if donor == null or donor.battery <= 0.0 or Winch.capacity(donor) < 300.0:
				release_tow(id)
				continue
			var gap: Vector3 = donor.global_position - body.global_position
			if lines.has(id):
				var line: MeshInstance3D = lines[id]
				line.global_position = (donor.global_position + body.global_position) * 0.5 + Vector3(0,0.45,0)
				line.look_at(donor.global_position + Vector3(0,0.45,0),Vector3.UP)
				line.scale = Vector3(1,1,maxf(0.01,gap.length()))
			if gap.length() > 6.0:
				release_tow(id)
				status = "Tow cable released: too far apart."
				continue
			if not donor.deployed:
				# Airlock docking must first park the frame at the local cradle.
				release_tow(id)
				continue
			if gap.length() > 2.6:
				var speed: float = minf(0.6,(gap.length() - 2.5) * 2.0)
				var before := body.position
				body.velocity = Vector3(gap.x,0,gap.z).normalized() * speed
				body.move_and_slide()
				body.rotation.y = atan2(-gap.x,-gap.z)
				record.blocked = minf(3.0,record.blocked + delta) if before.distance_to(body.position) < 0.01 * delta else 0.0
				if record.blocked >= 3.0:
					release_tow(id)
					status = "Tow blocked. Clear the route before reconnecting."
			else:
				body.velocity = Vector3.ZERO
				record.blocked = 0.0

func deliver(donor: Node, exterior: bool = false) -> int:
	var count := 0
	if donor==null: return 0
	var gantry: bool = exterior and donor.hull().external_power and donor.position.distance_to(Vector3(0,0.02,-14)) <= 8.0
	var destination: Node = inventory
	if not gantry and (donor.deployed or donor.position.z < -6.0):
		destination = get_parent().get_node("Rail").field_stock(donor)
		if destination==null: return count
	for id in records:
		var record: Dictionary = records[id]
		if record.state == "parts" and record.owner == donor.identity:
			if destination.parts.size()+record.parts.size()>2000 or inventory.next_serial+record.parts.size()>10000000: continue
			for part in record.parts:
				destination.add_part(part.id,part.condition)
			record.parts.clear()
			donor.cargo_kg = maxf(0.0,donor.cargo_kg - 20.0)
			record.state = "stripped"
			record.owner = ""
			count += 1
	return count

func dock_tow(donor: Node) -> bool:
	for id in records:
		if records[id].state == "towing" and records[id].owner == donor.identity:
			var body: Node3D = bodies[id]
			if body.global_position.distance_to(Vector3(0,0,-14)) > 8.0:
				return false
			release_tow(id)
			_claim(id)
			# Recovered frame remains on the surface until its own loader cycle.
	return true

func snapshot() -> Dictionary:
	var data := {}
	for id in records:
		data[id] = records[id].duplicate(true)
		if records[id].state != "awake":
			data[id]["body"] = bodies[id].snapshot()
	return data

static func validate(data: Variant) -> bool:
	if not data is Dictionary or data.size() != SITES.size():
		return false
	for id in SITES:
		var r: Variant = data.get(id)
		if not r is Dictionary or r.get("state") not in ["dormant","awake","towing","stripping","parts","stripped"] or not r.get("owner") is String or not r.get("parts") is Array or r.parts.size() > 4:
			return false
		if not MODEL._range(r.get("remaining"),0.0,20.0) or not MODEL._range(r.get("blocked"),0.0,3.0):
			return false
		if (r.state in ["towing","stripping","parts"]) != (not r.owner.is_empty()):
			return false
		if r.state != "awake" and (not MODEL.validate(r.get("body")) or r.body.id != id):
			return false
		for part in r.parts:
			if not part is Dictionary or MODEL.CATALOG.module(str(part.get("id"))) == null or not MODEL._range(part.get("condition"),0,100):
				return false
	return true

func restore(data: Dictionary) -> void:
	assert(validate(data))
	for line in lines.values():
		line.queue_free()
	lines.clear()
	for donor in fleet.get_children():
		donor.speed_multiplier = 1.0
		donor.work_noise = 0.0
	for id in SITES:
		if is_instance_valid(bodies.get(id)) and bodies[id].get_parent() == self:
			remove_child(bodies[id])
			bodies[id].queue_free()
		if data[id].state == "awake":
			bodies[id] = fleet.drone(id)
		else:
			_spawn(id)
			bodies[id].restore(data[id].body)
		records[id] = data[id].duplicate(true)
		records[id].erase("body")
		if records[id].state == "towing":
			var donor: Node = fleet.drone(records[id].owner)
			donor.speed_multiplier = 0.25
			donor.work_noise = 2.0
			_make_tether(id)

