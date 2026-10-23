extends Node
## Physical emissions consumed by threats, sector trace and audible presentation.
signal emitted(kind: String, at: Vector3, reach: float, source: String)
signal audible(cue: String, at: Vector3, reach: float, source: String)
const Model = preload("res://scripts/drones/drone.gd")
const NOISE = {"mule":8.0,"hover":14.0,"tracked":35.0,"tender":30.0,"biped":20.0,"goliath":240.0}
var pulses: Array = []
var heartbeat := 2.0
var source_frame := -1
var cached_sources: Array = []

func pulse(kind: String, at: Vector3, reach: float, source: String, duration: float = 1.0, cue: String = "impact") -> void:
	if kind not in ["sound","radio","heat","light","drill","rail"] or not Model._range(reach,0.01,600.0) or not Model._range(duration,0.01,5.0) or not at.is_finite() or source.length() > 80: return
	if pulses.size() >= 128: pulses.pop_front()
	pulses.append({"kind":kind,"at":[at.x,at.y,at.z],"reach":reach,"source":source,"remaining":duration})
	source_frame = -1
	emitted.emit(kind,at,reach,source)
	if kind in ["sound","drill","rail"]:
		audible.emit(kind if kind in ["drill","rail"] else (cue if cue in ["sonar","impact"] else "impact"),at,reach,source)

func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0: return
	for p in pulses: p.remaining = maxf(0.0,p.remaining - delta)
	pulses = pulses.filter(func(p): return p.remaining > 0.0)
	heartbeat -= delta
	while heartbeat <= 0.0:
		heartbeat += 2.0
		for drone in get_parent().get_node("Fleet").get_children():
			if drone.deployed and get_parent().get_node("Radio").quality(drone) > 0.0:
				pulse("radio",drone.global_position,40.0 * radio_factor(drone),drone.identity)
		var territory: Node = get_parent().get_node_or_null("Territory")
		if territory != null:
			for i in range(1,6):
				if territory.sites[i].pylon and territory.sites[i].battery > 0.0 and territory.online(i): pulse("radio",territory.pad(i),40.0,"pylon_%d" % i)

func _physics_process(delta: float) -> void:
	advance(delta)

func sound_reach(drone: Node) -> float:
	if not drone.deployed or not drone.has_power(): return 0.0
	var artifacts: Node = get_parent().get_node_or_null("Artifacts")
	if artifacts!=null and artifacts.small(drone,"thermal"): return 0.0
	var motion: float = Vector2(drone.velocity.x,drone.velocity.z).length()
	var reach: float = float(NOISE[drone.hull_id]) if motion > 0.08 else 0.0
	reach += 20.0 * drone.work_noise
	return reach * (0.25 if drone.silent_running else 1.0)

func sources() -> Array:
	var frame := Engine.get_physics_frames()
	if source_frame == frame: return cached_sources
	source_frame = frame
	var result := pulses.duplicate(true)
	for drone in get_parent().get_node("Fleet").get_children():
		if not drone.deployed: continue
		if not drone.has_power():
			var artifacts: Node = get_parent().get_node_or_null("Artifacts")
			if artifacts!=null and artifacts.heavy(drone,"thermal"): result.append(_source("heat",drone.global_position,10.0,drone.identity))
			continue
		var at: Vector3 = drone.global_position
		var reach := sound_reach(drone)
		if reach > 0.0: result.append(_source("sound",at,reach,drone.identity))
		var heat: float = minf(45.0,12.0 + get_parent().get_node("DronePower").draw_kw(drone) * 2.0)
		result.append(_source("heat",at,heat,drone.identity))
		result.append(_source("contrast",at,8.0 * get_parent().get_node("Weather").visibility_multiplier,drone.identity))
		if not drone.silent_running and drone.module_efficiency("floodlight") > 0.0:
			var beams: Array = drone.get_node("Visual").find_children("FloodBeam","SpotLight3D",true,false)
			if not beams.is_empty():
				var beam: SpotLight3D = beams[0]
				var light := _source("light",beam.global_position,beam.spot_range,drone.identity)
				var forward := -beam.global_basis.z
				light["forward"] = [forward.x,forward.y,forward.z]
				light["cone"] = cos(deg_to_rad(beam.spot_angle))
				result.append(light)
	var human: Node = get_parent().get_node("HumanSortie")
	if not human.dead:
		var operator: Node3D = get_parent().get_node("Operator")
		if human.active or get_parent().get_node_or_null("Breaches")!=null:
			result.append(_source("heat",operator.global_position,16.0,"operator"))
			if operator.velocity.length() > 0.1: result.append(_source("sound",operator.global_position,5.0,"operator"))
	for landmark in get_tree().get_nodes_in_group("sensor_landmarks"):
		if landmark.get_meta("thermal",0.0) >= 0.2 and not landmark.is_in_group("hostile_pings"):
			result.append(_source("heat",landmark.global_position,12.0 * landmark.get_meta("thermal"),""))
	cached_sources = result
	return cached_sources

func radio_factor(drone: Node) -> float:
	return 0.2 if drone.module_efficiency("signal_shield") > 0.0 else 1.0

func _source(kind: String, at: Vector3, reach: float, source: String) -> Dictionary:
	return {"kind":kind,"at":[at.x,at.y,at.z],"reach":reach,"source":source}

func snapshot() -> Dictionary:
	return {"heartbeat":heartbeat,"pulses":pulses.duplicate(true)}

static func validate(data: Variant) -> bool:
	if not data is Dictionary or not Model._range(data.get("heartbeat"),0.0,2.0) or not data.get("pulses") is Array or data.pulses.size() > 128: return false
	for p in data.pulses:
		if not p is Dictionary or p.get("kind") not in ["sound","radio","heat","light","drill","rail"] or not p.get("source") is String or p.source.length() > 80 or not Model._range(p.get("reach"),0.01,600.0) or not Model._range(p.get("remaining"),0.0,5.0) or not valid_position(p.get("at")): return false
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
	source_frame = -1
