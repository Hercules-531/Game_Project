extends Node3D
signal changed
const MAX_KW := 64.0
var links: Dictionary = {}
var lines: Dictionary = {}
@onready var fleet: Node = get_parent().get_node("Fleet")
@onready var power: Node = get_parent().get_node("DronePower")
var status := "Drive a powered tender within 4m of the heavy power port."

func _ready() -> void:
	process_physics_priority = -20 # Pay before heavy motors advance this frame.

func attach(receiver_id: String, donor_id: String) -> bool:
	var receiver: Node = fleet.drone(receiver_id)
	var donor: Node = fleet.drone(donor_id)
	if receiver == null or donor == null or not receiver.hull().external_power or donor.hull_id != "tender" or not receiver.deployed or not donor.deployed or donor.module_efficiency("power_coupler") <= 0.0 or get_parent().get_node("Radio").quality(donor) <= 0.0 or receiver.position.distance_to(donor.position) > 4.0 or links.has(receiver_id) or donor_id in links.values():
		status = "Needs a linked tender, free coupler and <=4m gap."
		return false
	links[receiver_id] = donor_id
	_make_line(receiver_id)
	status = "Connected. Finite bank; maximum cable length 6m."
	changed.emit()
	return true

func release(receiver_id: String) -> bool:
	if not links.has(receiver_id): return false
	var donor: Node = fleet.drone(links[receiver_id])
	if donor == null or get_parent().get_node("Radio").quality(donor) <= 0.0: return false
	_detach(receiver_id)
	return true

func _detach(id: String) -> void:
	links.erase(id)
	if lines.has(id):
		lines[id].queue_free()
		lines.erase(id)
	var receiver: Node = fleet.drone(id)
	if receiver != null: receiver.get_node("Controller").stop()
	status = "Umbilical lost. Restore supply for heavy work."
	changed.emit()

func supported(id: String) -> bool:
	if not links.has(id): return false
	var receiver: Node = fleet.drone(id)
	var donor: Node = fleet.drone(links[id])
	if receiver == null or donor == null or not receiver.deployed or not donor.deployed or donor.battery <= 0.0 or donor.module_efficiency("power_coupler") <= 0.0 or receiver.position.distance_to(donor.position) > 6.0 or power.required_kw(receiver) > MAX_KW: return false
	var ray := PhysicsRayQueryParameters3D.create(receiver.global_position+Vector3(0,1.25,0),donor.global_position+Vector3(0,1,0),1,[receiver.get_rid(),donor.get_rid()])
	return receiver.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _physics_process(delta: float) -> void: advance(delta)
func advance(seconds: float) -> void:
	if not is_finite(seconds) or seconds <= 0.0: return
	for id in links.keys():
		if not supported(id):
			_detach(id)
			continue
		var receiver: Node = fleet.drone(id)
		var donor: Node = fleet.drone(links[id])
		if not get_parent().get_node("Orders").field_powered(id):
			var cost: float = power.required_kw(receiver) * seconds / (3600.0 * 0.9 * minf(1.0,donor.module_efficiency("power_coupler")))
			donor.battery = maxf(0.0,donor.battery - cost)
			if donor.battery <= 0.0:
				_detach(id)
				continue
		var line: Node3D = lines[id]
		var a: Vector3 = receiver.global_position + Vector3(0,1.25,0)
		var b: Vector3 = donor.global_position + Vector3(0,1,0)
		line.global_position = (a+b)*0.5
		line.basis = Basis(Quaternion(Vector3.UP,(b-a).normalized()))
		line.get_child(0).mesh.height = a.distance_to(b)

func _make_line(id: String) -> void:
	var line := Node3D.new()
	add_child(line)
	var view := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = 0.045
	shape.bottom_radius = 0.045
	shape.radial_segments = 6
	view.mesh = shape
	view.material_override = preload("res://scripts/world/surface_kit.gd").material("metal")
	line.add_child(view)
	lines[id] = line

func snapshot() -> Dictionary: return links.duplicate()
static func validate(data: Variant) -> bool:
	if not data is Dictionary or data.size() > 32: return false
	var donors := {}
	for id in data:
		if not id is String or not data[id] is String or id == data[id] or donors.has(data[id]): return false
		donors[data[id]] = true
	return true
func restore(data: Dictionary) -> void:
	assert(validate(data))
	for id in links.keys(): _detach(id)
	links = data.duplicate()
	for id in links: _make_line(id)
	status = "Finite power convoy restored." if not links.is_empty() else "No power convoy connected."
	changed.emit()
