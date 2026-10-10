extends Node

const Part = preload("res://scripts/drones/part_condition.gd")
var cycles: Dictionary = {}
var previous: Dictionary = {}
var previous_energy: Dictionary = {}
var wear_multiplier: float = 1.0
var fault_multiplier: float = 1.0
var rng := RandomNumberGenerator.new()
@onready var fleet: Node3D = get_parent().get_node("Fleet")

func _ready() -> void:
	rng.seed = 140522

func _physics_process(delta: float) -> void:
	advance(delta)

func advance(seconds: float) -> void:
	for drone in fleet.get_children():
		for key in drone.faults.keys():
			drone.faults[key] = maxf(0.0,drone.faults[key] - seconds)
			if drone.faults[key] <= 0.0:
				drone.faults.erase(key)
		var distance: float = drone.position.distance_to(previous.get(drone.identity,drone.position))
		var energy: float = maxf(0.0,previous_energy.get(drone.identity,drone.battery) - drone.battery)
		previous[drone.identity] = drone.position
		previous_energy[drone.identity] = drone.battery
		if not drone.deployed:
			continue
		var load_factor: float = 1.0 + drone.cargo_kg / drone.hull().payload_kg
		drone.components.joints = maxf(0.0,drone.components.joints - distance * 0.004 * load_factor * wear_multiplier)
		drone.components.cell = maxf(0.0,drone.components.cell - energy * 5.0 * wear_multiplier)
		drone.components.armor = maxf(0.0,drone.components.armor - seconds * 0.0003 * wear_multiplier)
		for socket in drone.condition:
			drone.condition[socket] = maxf(0.0,drone.condition[socket] - (distance * 0.003 + seconds * 0.00025) * load_factor * wear_multiplier)
		cycles[drone.identity] = cycles.get(drone.identity,0.0) + seconds
		while cycles[drone.identity] >= 60.0:
			cycles[drone.identity] -= 60.0
			sample_work_cycle(drone)

func sample_work_cycle(drone: Node) -> void:
	var parts: Dictionary = drone.components.duplicate()
	parts.merge(drone.condition)
	for key in parts:
		if not drone.faults.has(key) and rng.randf() < minf(1.0,Part.malfunction_chance(parts[key]) * fault_multiplier):
			drone.faults[key] = 8.0

func snapshot() -> Dictionary:
	return {"cycles":cycles.duplicate(),"rng":str(rng.state)}

static func validate(data: Variant) -> bool:
	if not data is Dictionary or not data.get("cycles") is Dictionary or not data.get("rng") is String or not data.rng.is_valid_int() or data.cycles.size() > 32:
		return false
	for id in data.cycles:
		var value: Variant = data.cycles[id]
		if not id is String or not (value is float or value is int) or not is_finite(value) or value < 0.0 or value >= 60.0:
			return false
	return true

func restore(data: Dictionary) -> void:
	assert(validate(data))
	cycles = data.cycles.duplicate()
	rng.state = data.rng.to_int()
	previous.clear()
	previous_energy.clear()
