extends Node

var ash_seconds: float = 0.0
const HOTSPOT := Vector3(-9,0.02,-64)
const POCKET := Vector3(9,0.02,-48)
const POCKET_RADIUS := 6.0
var vent_cycles: Dictionary = {}
var contamination: float = 100.0
var cycles: Dictionary = {}
var rng := RandomNumberGenerator.new()
var marker: Node3D
@onready var weather: Node = get_parent().get_node("Weather")
@onready var conditions: Node = get_parent().get_node("Conditions")
@onready var salvage: Node = get_parent().get_node("Salvage")

func _ready() -> void:
	rng.seed = 1405275
	marker = preload("res://scripts/world/surface_kit.gd").box(get_parent().get_node("Surface"),"RadiationHotspot",Vector3(5,0.03,5),HOTSPOT + Vector3(0,0.04,0),"metal",false)
	marker.add_to_group("sensor_landmarks")
	marker.set_meta("thermal",0.35)
	var kit = preload("res://scripts/world/surface_kit.gd")
	for angle in [0.0,2.094,4.188]:
		var at := POCKET + Vector3(sin(angle) * 2.8,0.4,cos(angle) * 2.8)
		var warning: Node3D = kit.box(get_parent().get_node("Surface"),"VentMarker",Vector3(0.12,0.8,0.12),at,"metal",false)
		warning.get_child(0).get_active_material(0).set_shader_parameter("tint",Color(0.95,0.55,0.15))
	weather.changed.connect(_update)
	_update()

func _update() -> void:
	conditions.wear_multiplier = 2.0 if weather.current == "ash" else 1.0
	conditions.fault_multiplier = 2.0 if weather.current == "ash" else 1.0
	if marker != null:
		marker.get_child(0).get_active_material(0).set_shader_parameter("tint",Color(0.15,0.22 + contamination * 0.003,0.17))
		marker.set_meta("thermal",0.35 * contamination / 100.0)

func _physics_process(delta: float) -> void:
	advance(delta)

func advance(seconds: float) -> void:
	if not is_finite(seconds) or seconds <= 0.0:
		return
	if weather.current == "ash":
		ash_seconds = minf(30.0,ash_seconds + seconds)
		if ash_seconds >= 30.0 and salvage.items.ash_cache.state == "buried":
			salvage.items.ash_cache.state = "available"
			salvage.items.ash_cache.apply_state()
	if weather.current == "rain":
		contamination = maxf(0.0,contamination - seconds * 0.05)
		_update()
	for drone in get_parent().get_node("Fleet").get_children():
		drone.terrain_multiplier = 0.55 if drone.deployed and drone.position.distance_to(POCKET) <= 3.0 else 1.0
		if not drone.deployed:
			continue
		if drone.position.distance_to(POCKET) <= 2.5:
			vent_cycles[drone.identity] = vent_cycles.get(drone.identity,0.0) + seconds
			while vent_cycles[drone.identity] >= 60.0:
				vent_cycles[drone.identity] -= 60.0
				drone.components.armor = maxf(0.0,drone.components.armor - 5.0)
				drone.faults.joints = 8.0
		if weather.current == "rain":
			drone.components.armor = maxf(0.0,drone.components.armor - seconds * 0.003)
		if weather.current in ["rain","ash"]:
			cycles[drone.identity] = cycles.get(drone.identity,0.0) + seconds
			while cycles[drone.identity] >= 60.0:
				cycles[drone.identity] -= 60.0
				sample_exposure(drone)

func sample_exposure(drone: Node) -> bool:
	# External fouling/shorts are separate from condition-band intrinsic faults.
	var risk: float = 0.12 if weather.current == "rain" else (0.08 if weather.current == "ash" else 0.0)
	if drone.module_efficiency("sealed_housing") > 0.0:
		risk *= 0.4
	if drone.hull_id == "tracked":
		risk *= 0.75
	if rng.randf() >= risk:
		return false
	var part: String = "cell" if weather.current == "rain" else ("sensor_a" if drone.modules.has("sensor_a") and rng.randf() < 0.5 else "joints")
	drone.faults[part] = 8.0
	return true

func radiation(at: Vector3) -> float:
	return contamination / 100.0 if at.distance_to(HOTSPOT) <= 5.0 else 0.0

func cold_multiplier(at: Vector3) -> float:
	return 0.0 if at.distance_to(POCKET) <= POCKET_RADIUS else 1.0

func snapshot() -> Dictionary:
	return {"ash_seconds":ash_seconds,"contamination":contamination,"cycles":cycles.duplicate(),"rng":str(rng.state),"vent_cycles":vent_cycles.duplicate()}

static func validate(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var seconds: Variant = data.get("ash_seconds")
	if not ((seconds is float or seconds is int) and is_finite(seconds) and seconds >= 0.0 and seconds <= 30.0):
		return false
	# Version 17 predates rain. Existing ash saves migrate with the initial hotspot.
	if not data.has("contamination"):
		return true
	var value: Variant = data.contamination
	if not (value is float or value is int) or not is_finite(value) or value < 0.0 or value > 100.0 or not data.get("cycles") is Dictionary or data.cycles.size() > 32 or not data.get("rng") is String or not data.rng.is_valid_int():
		return false
	for id in data.cycles:
		value = data.cycles[id]
		if not id is String or not (value is float or value is int) or not is_finite(value) or value < 0.0 or value >= 60.0:
			return false
	if data.has("vent_cycles"):
		if not data.vent_cycles is Dictionary or data.vent_cycles.size() > 32:
			return false
		for id in data.vent_cycles:
			value = data.vent_cycles[id]
			if not id is String or not (value is float or value is int) or not is_finite(value) or value < 0.0 or value >= 60.0:
				return false
	return true

func restore(data: Dictionary) -> void:
	assert(validate(data))
	ash_seconds = data.ash_seconds
	contamination = data.get("contamination",100.0)
	cycles = data.get("cycles",{}).duplicate()
	vent_cycles = data.get("vent_cycles",{}).duplicate()
	if data.has("rng"): rng.state = data.rng.to_int()
	else: rng.seed = 1405275
	_update()
