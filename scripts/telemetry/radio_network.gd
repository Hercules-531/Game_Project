extends Node

var range_m: float = 160.0
var range_multiplier: float = 1.0
var weather_latency: float = 0.0
var clock: float = 0.0
var roll_remaining: float = 12.0
var drops: Dictionary = {}
var rng := RandomNumberGenerator.new()
var dropout_chance: float = 0.015
@onready var fleet: Node3D = get_parent().get_node("Fleet")


func _ready() -> void:
	rng.seed = 140531


func _physics_process(delta: float) -> void:
	advance(delta)


func advance(seconds: float) -> void:
	clock += seconds
	for id in drops.keys():
		drops[id] = maxf(0.0,drops[id] - seconds)
	roll_remaining -= seconds
	while roll_remaining <= 0.0:
		roll_remaining += 12.0
		for drone in fleet.get_children():
			if drone.deployed and rng.randf() < dropout_chance:
				drops[drone.identity] = 2.0
		var territory: Node = get_parent().get_node_or_null("Territory")
		if territory != null and not territory.sites.is_empty():
			for i in range(1,6):
				if territory.sites[i].pylon and rng.randf() < dropout_chance: drops["pylon_%d" % i] = 2.0


func quality(drone: Node) -> float:
	if not drone.deployed:
		return 1.0
	if not drone.has_power() or drops.get(drone.identity,0.0) > 0.0 or range_multiplier <= 0.0:
		return 0.0
	var target: Vector3 = drone.global_position + Vector3(0,0.7,0)
	var origins := [{"at":Vector3(0,6,-13),"quality":1.0,"rid":RID()}]
	var territory: Node = get_parent().get_node_or_null("Territory")
	if territory != null and not territory.sites.is_empty(): origins = territory.radio_origins()
	var best := 0.0
	for origin in origins:
		var excluded: Array[RID] = [drone.get_rid()]
		if origin.rid.is_valid(): excluded.append(origin.rid)
		best = maxf(best,minf(origin.quality,edge_quality(origin.at,target,excluded)))
	return best

func edge_quality(origin: Vector3, target: Vector3, excluded: Array[RID] = []) -> float:
	if range_multiplier <= 0.0: return 0.0
	excluded = excluded.duplicate()
	var territory: Node = get_parent().get_node_or_null("Territory")
	if territory != null: excluded.append_array(territory.relay_rids())
	var strength := clampf(1.0-origin.distance_to(target)/(range_m*range_multiplier),0.0,1.0)
	var ray := PhysicsRayQueryParameters3D.create(origin,target,1,excluded)
	if not fleet.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): strength *= 0.3
	return strength if strength >= 0.08 else 0.0


func latency(drone: Node) -> float:
	return 0.1 + weather_latency + (1.0 - quality(drone)) * 0.25


func snapshot() -> Dictionary:
	return {"clock":clock,"roll_remaining":roll_remaining,"drops":drops.duplicate(),"rng":str(rng.state)}


static func validate(data: Variant) -> bool:
	if not data is Dictionary or not data.get("rng") is String or not data.rng.is_valid_int() or not data.get("drops") is Dictionary:
		return false
	for key in ["clock","roll_remaining"]:
		if not (data.get(key) is float or data.get(key) is int) or not is_finite(data[key]) or data[key] < 0.0:
			return false
	if data.roll_remaining > 12.0 or data.clock > 1000000000.0 or data.drops.size() > 64:
		return false
	for id in data.drops:
		var value: Variant = data.drops[id]
		if not id is String or not (value is float or value is int) or not is_finite(value) or value < 0 or value > 2.0:
			return false
	return true


func restore(data: Dictionary) -> void:
	assert(validate(data))
	clock = data.clock
	roll_remaining = data.roll_remaining
	drops = data.drops.duplicate()
	rng.state = data.rng.to_int()
	get_parent().get_node("FleetControl").link.clear_all()
