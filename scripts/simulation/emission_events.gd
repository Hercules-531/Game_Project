extends Node
## Physical emissions consumed by threats, and later sector trace/audio.
signal emitted(kind: String, at: Vector3, reach: float, source: String)
const Model = preload("res://scripts/drones/drone.gd")
const NOISE = {"mule":8.0,"hover":14.0,"tracked":35.0,"tender":30.0,"biped":20.0,"goliath":240.0}
var pulses: Array = []
var heartbeat := 2.0

func pulse(kind: String, at: Vector3, reach: float, source: String, duration: float = 1.0) -> void:
	if kind not in ["sound","radio","heat","light"] or not Model._range(reach,0.01,600.0) or not Model._range(duration,0.01,5.0) or not at.is_finite() or source.length() > 80: return
	if pulses.size() >= 128: pulses.pop_front()
	pulses.append({"kind":kind,"at":[at.x,at.y,at.z],"reach":reach,"source":source,"remaining":duration})
	emitted.emit(kind,at,reach,source)

func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0: return
	for p in pulses: p.remaining = maxf(0.0,p.remaining - delta)
	pulses = pulses.filter(func(p): return p.remaining > 0.0)
	heartbeat -= delta
	while heartbeat <= 0.0:
		heartbeat += 2.0
		for drone in get_parent().get_node("Fleet").get_children():
			if drone.deployed and get_parent().get_node("Radio").quality(drone) > 0.0:
				pulse("radio",drone.global_position,40.0,drone.identity)

func _physics_process(delta: float) -> void:
	advance(delta)

func sound_reach(drone: Node) -> float:
	if not drone.deployed or not drone.has_power(): return 0.0
	var motion: float = Vector2(drone.velocity.x,drone.velocity.z).length()
	var reach: float = float(NOISE[drone.hull_id]) if motion > 0.08 else 0.0
	reach += 20.0 * drone.work_noise
	return reach * (0.25 if drone.silent_running else 1.0)

func sources() -> Array:
	var result := pulses.duplicate(true)
	for drone in get_parent().get_node("Fleet").get_children():
		if not drone.deployed or not drone.has_power(): continue
		var at: Vector3 = drone.global_position
		var reach := sound_reach(drone)
		if reach > 0.0: result.append(_source("sound",at,reach,drone.identity))
		var heat: float = minf(45.0,12.0 + get_parent().get_node("DronePower").draw_kw(drone) * 2.0)
		result.append(_source("heat",at,heat,drone.identity))
		result.append(_source("contrast",at,8.0 * get_parent().get_node("Weather").visibility_multiplier,drone.identity))
		if not drone.silent_running and drone.module_efficiency("floodlight") > 0.0:
			result.append(_source("light",at,12.0,drone.identity))
	var human: Node = get_parent().get_node("HumanSortie")
	if human.active and not human.dead:
		var operator: Node3D = get_parent().get_node("Operator")
		if operator.position.z < -10.0:
			result.append(_source("heat",operator.global_position,16.0,"operator"))
			if operator.velocity.length() > 0.1: result.append(_source("sound",operator.global_position,5.0,"operator"))
	for landmark in get_tree().get_nodes_in_group("sensor_landmarks"):
		if landmark.get_meta("thermal",0.0) >= 0.2 and not landmark.is_in_group("hostile_pings"):
			result.append(_source("heat",landmark.global_position,12.0 * landmark.get_meta("thermal"),""))
	return result

func _source(kind: String, at: Vector3, reach: float, source: String) -> Dictionary:
	return {"kind":kind,"at":[at.x,at.y,at.z],"reach":reach,"source":source}

func snapshot() -> Dictionary:
	return {"heartbeat":heartbeat,"pulses":pulses.duplicate(true)}

static func validate(data: Variant) -> bool:
	if not data is Dictionary or not Model._range(data.get("heartbeat"),0.0,2.0) or not data.get("pulses") is Array or data.pulses.size() > 128: return false
	for p in data.pulses:
		if not p is Dictionary or p.get("kind") not in ["sound","radio","heat","light"] or not p.get("source") is String or p.source.length() > 80 or not Model._range(p.get("reach"),0.01,600.0) or not Model._range(p.get("remaining"),0.0,5.0) or not valid_position(p.get("at")): return false
	return true

static func valid_position(at: Variant) -> bool:
	if not at is Array or at.size() != 3: return false
	for coordinate in at:
		if not Model._range(coordinate,-1000000.0,1000000.0): return false
	return true

func restore(data: Dictionary) -> void:
	assert(validate(data))
	heartbeat = data.heartbeat
	pulses = data.pulses.duplicate(true)
