extends Node3D
signal changed
const BALANCE = preload("res://resources/balance/escalation.tres")
const NEST = preload("res://scenes/threats/nest.tscn")
const Nest = preload("res://scripts/threats/nest_state.gd")
const Drone = preload("res://scripts/drones/drone.gd")
const Layout = preload("res://scripts/world/world_layout.gd")
var clock := 0.0
var tick := 0.0
var trace: Array = [0.0,0.0,0.0,0.0,0.0,0.0]
var deployments: Dictionary = {}
var nests: Array = []

func _ready() -> void:
	for index in 6:
		var nest := NEST.instantiate()
		nest.band = index
		nest.name = "Nest%02d" % (index + 1)
		add_child(nest)
		nests.append(nest)
	get_parent().get_node("Emissions").emitted.connect(_pulse)

func _pulse(kind: String, at: Vector3, reach: float, _source: String) -> void:
	if at.z >= -10.0 or kind not in ["radio","sound","drill","rail"]: return
	var index := Layout.band_at(at)
	trace[index] = minf(100.0,trace[index] + reach / (250.0 if kind == "radio" else 100.0))
	changed.emit()

func _physics_process(delta: float) -> void:
	advance(delta)

func advance(seconds: float) -> void:
	if not is_finite(seconds) or seconds <= 0.0 or seconds > 1000000.0: return
	clock += seconds
	tick += seconds
	while tick >= 1.0:
		tick -= 1.0
		_step()
	changed.emit()

func _step() -> void:
	for index in 6: trace[index] = maxf(0.0,trace[index] - BALANCE.decay_per_second)
	for source in get_parent().get_node("Emissions").sources():
		if source.has("remaining") or source.source.is_empty() or source.at[2] >= -10.0 or source.kind not in ["sound","heat"]: continue
		var at := Vector3(source.at[0],source.at[1],source.at[2])
		var index := Layout.band_at(at)
		trace[index] = minf(100.0,trace[index] + source.reach / (300.0 if source.kind == "sound" else 500.0))
	for drone in get_parent().get_node("Fleet").get_children():
		if drone.deployed and not deployments.get(drone.identity,false) and drone.position.z < -10.0:
			var index := Layout.band_at(drone.position)
			trace[index] = minf(100.0,trace[index] + 1.0)
		deployments[drone.identity] = drone.deployed
	for index in 6:
		nests[index].advance(1.0,trace[index])
		for drone in get_parent().get_node("Fleet").get_children(): nests[index].survey(drone,clock - tick)

func snapshot() -> Dictionary:
	var records := []
	for nest in nests: records.append(nest.snapshot())
	return {"clock":clock,"tick":tick,"trace":trace.duplicate(),"deployments":deployments.duplicate(),"nests":records}

static func validate(data: Variant) -> bool:
	if not data is Dictionary or not Drone._range(data.get("clock"),0.0,1000000000.0) or not Drone._range(data.get("tick"),0.0,1.0) or data.tick >= 1.0 or not data.get("trace") is Array or data.trace.size() != 6 or not data.get("deployments") is Dictionary or data.deployments.size() > 32 or not data.get("nests") is Array or data.nests.size() != 6: return false
	for value in data.trace:
		if not Drone._range(value,0.0,100.0): return false
	for id in data.deployments:
		if not id is String or id.length() > 80 or not data.deployments[id] is bool: return false
	for index in 6:
		if not Nest.validate(data.nests[index]) or data.nests[index].band != index or data.nests[index].surveyed_at > data.clock: return false
	return true

func restore(data: Dictionary) -> void:
	assert(validate(data))
	clock = data.clock
	tick = data.tick
	trace = data.trace.duplicate()
	deployments = data.deployments.duplicate()
	for index in 6: nests[index].restore(data.nests[index])
	changed.emit()
