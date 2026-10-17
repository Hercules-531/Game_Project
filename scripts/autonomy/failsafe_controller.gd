extends Node

const History = preload("res://scripts/autonomy/waypoint_history.gd")
var histories: Dictionary = {}
var states: Dictionary = {}
@onready var fleet: Node3D = get_parent().get_node("Fleet")
@onready var radio: Node = get_parent().get_node("Radio")

func _physics_process(delta: float) -> void:
	advance(delta)

func history(id: String) -> RefCounted:
	if not histories.has(id):
		histories[id] = History.new()
	return histories[id]

func advance(delta: float) -> void:
	for drone in fleet.get_children():
		var excavation: Node = get_parent().get_node_or_null("Excavation")
		if excavation!=null and excavation.controls(drone.identity):
			drone.get_node("Controller").stop()
			continue
		var trail: RefCounted = history(drone.identity)
		if not states.has(drone.identity):
			states[drone.identity] = {"mode":"idle","cursor":-1,"blocked":0.0}
		var state: Dictionary = states[drone.identity]
		if not drone.deployed:
			trail.points.clear()
			state.mode = "idle"
			state.cursor = -1
			state.blocked = 0.0
			continue
		if get_parent().get_node("Orders").field_powered(drone.identity):
			continue # Preloaded local program owns the motor during an aurora.
		if radio.quality(drone) > 0.0:
			if state.mode != "idle":
				drone.get_node("Controller").stop()
				state.mode = "idle"
				state.cursor = -1
				state.blocked = 0.0
			var orders: Node = get_parent().get_node_or_null("Orders")
			if orders == null or not orders.is_returning(drone.identity):
				trail.record(drone.position)
			continue
		if state.mode == "idle":
			state.mode = "retrace" if drone.module_efficiency("retrace") > 0.0 and not trail.points.is_empty() else "freeze"
			state.cursor = trail.points.size() - 1
			state.blocked = 0.0
		if state.mode != "retrace" or drone.battery <= 0.0 or drone.module_efficiency("retrace") <= 0.0:
			drone.get_node("Controller").stop()
			continue
		if state.cursor < 0:
			state.mode = "freeze"
			drone.get_node("Controller").stop()
			continue
		var target: Vector3 = trail.points[state.cursor]
		var offset: Vector3 = target - drone.position
		offset.y = 0.0
		if offset.length() < 0.3:
			state.cursor -= 1
			continue
		if not drone.get_node("Controller").can_traverse(offset.normalized() * 0.35):
			drone.get_node("Controller").stop()
			state.blocked = minf(3.0,state.blocked + delta)
			if state.blocked >= 3.0:
				state.mode = "freeze"
			continue
		state.blocked = 0.0
		var heading := atan2(-offset.x,-offset.z)
		var error := wrapf(heading - drone.rotation.y,-PI,PI)
		drone.get_node("Controller").command = Vector2(clampf(-error * 2.0,-1,1),-1.0 if absf(error) < 0.35 else 0.0)

func snapshot() -> Dictionary:
	var data := {}
	for id in states:
		data[id] = states[id].duplicate()
		data[id]["points"] = history(id).snapshot()
	return data

static func validate(data: Variant) -> bool:
	if not data is Dictionary or data.size() > 32:
		return false
	for id in data:
		var record: Variant = data[id]
		if not id is String or not record is Dictionary or record.get("mode") not in ["idle","freeze","retrace"] or not History.validate(record.get("points")):
			return false
		var cursor: Variant = record.get("cursor")
		var blocked: Variant = record.get("blocked")
		if not (cursor is float or cursor is int) or not is_finite(cursor) or cursor != int(cursor) or cursor < -1 or cursor >= record.points.size():
			return false
		if not (blocked is float or blocked is int) or not is_finite(blocked) or blocked < 0 or blocked > 3.1:
			return false
	return true

func restore(data: Dictionary) -> void:
	assert(validate(data))
	histories.clear()
	states.clear()
	for id in data:
		states[id] = {"mode":data[id].mode,"cursor":int(data[id].cursor),"blocked":data[id].blocked}
		history(id).restore(data[id].points)
