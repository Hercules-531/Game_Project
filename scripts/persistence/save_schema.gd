extends RefCounted

const VERSION := 5
const LifeSupport = preload("res://scripts/simulation/life_support.gd")
const Fleet = preload("res://scripts/drones/fleet.gd")
const Inventory = preload("res://scripts/simulation/inventory.gd")
const Fabrication = preload("res://scripts/workshop/fabrication_queue.gd")
const CONTROL_PATHS := ["CommandCRT", "TelemetryCRT", "MapCRT", "WorkshopBench",
	"LifeBreaker", "PowerBreaker", "CommandSwitch", "WorkshopSwitch",
	"Airlock/InnerDoor", "AirlockControlOutside", "AirlockControlInside"]


static func capture(world: Node) -> Dictionary:
	var operator: Node3D = world.get_node("Operator")
	var controls := {}
	for path in CONTROL_PATHS:
		controls[path] = world.get_node("Bunker/" + path + "/Interaction").powered
	var airlock := world.get_node("Bunker/Airlock")
	return {"version":VERSION,"elapsed":world.elapsed_seconds,
		"operator":{"position":[operator.position.x,operator.position.y,operator.position.z],
			"yaw":operator.rotation.y,"pitch":operator.get_node("Head").rotation.x},
		"controls":controls,"airlock":{"open":String(airlock.opened_side),
			"outer_authorized":airlock.outer_authorized},
		"life_support":world.get_node("LifeSupport").snapshot(),
		"fleet":world.get_node("Fleet").snapshot(),
		"inventory":world.get_node("Inventory").snapshot(),
		"fabrication":world.get_node("Fabrication").snapshot()}


static func validate(data: Variant) -> String:
	if not data is Dictionary:
		return "Invalid save structure."
	if not _number(data.get("version")) or data.version != int(data.version) or data.version < 1 or data.version > VERSION:
		return "Unsupported save version."
	if not _number(data.get("elapsed")) or data.elapsed < 0:
		return "Invalid simulation time."
	var operator: Variant = data.get("operator")
	if not operator is Dictionary:
		return "Missing operator state."
	var position: Variant = operator.get("position")
	if not position is Array or position.size() != 3:
		return "Invalid operator position."
	for value in position:
		if not _number(value) or absf(float(value)) > 1000000.0:
			return "Invalid operator position."
	if not _number(operator.get("yaw")) or not _number(operator.get("pitch")):
		return "Invalid camera rotation."
	if absf(float(operator.pitch)) > PI / 2.0:
		return "Invalid camera pitch."
	var controls: Variant = data.get("controls")
	if not controls is Dictionary:
		return "Missing control state."
	for path in CONTROL_PATHS:
		if not controls.get(path) is bool:
			return "Invalid control state."
	var airlock: Variant = data.get("airlock")
	if not airlock is Dictionary or airlock.get("open") not in ["","inner","outer"]:
		return "Invalid airlock state."
	if not airlock.get("outer_authorized") is bool:
		return "Invalid surface authorization."
	if airlock.open == "outer" and not airlock.outer_authorized:
		return "Inconsistent airlock state."
	if data.version >= 2 and not LifeSupport.validate(data.get("life_support")):
		return "Invalid life-support state."
	if data.version >= 3 and not Fleet.validate(data.get("fleet")):
		return "Invalid fleet state."
	if data.version >= 5:
		for machine in data.fleet:
			if not machine.get("deployed") is bool:
				return "Invalid deployment state."
	if data.version >= 4 and (not Inventory.validate(data.get("inventory")) or not Fabrication.validate(data.get("fabrication"))):
		return "Invalid workshop state."
	return ""


static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func restore(world: Node, data: Dictionary) -> void:
	assert(validate(data).is_empty())
	var operator := world.get_node("Operator")
	var position: Array = data.operator.position
	operator.position = Vector3(position[0],position[1],position[2])
	operator.velocity = Vector3.ZERO
	operator.rotation.y = data.operator.yaw
	operator.get_node("Head").rotation.x = data.operator.pitch
	world.elapsed_seconds = data.elapsed
	# Version 1 predates life support; migrate once with the opening supplies.
	if data.version >= 2:
		world.get_node("LifeSupport").restore(data.life_support)
	if data.version >= 3:
		world.get_node("Fleet").restore(data.fleet)
	if data.version >= 4:
		world.get_node("Inventory").restore(data.inventory)
		world.get_node("Fabrication").restore(data.fabrication)
	for path in CONTROL_PATHS:
		var control := world.get_node("Bunker/" + path + "/Interaction")
		control.powered = data.controls[path]
		control.power_changed.emit(control.powered)
	var airlock := world.get_node("Bunker/Airlock")
	airlock.opened_side = StringName(data.airlock.open)
	airlock.outer_authorized = data.airlock.outer_authorized
	for side in ["InnerDoor","OuterDoor"]:
		var door: AnimatableBody3D = airlock.get_node(side)
		door.sync_to_physics = false
		door.position.x = 1.8 if data.airlock.open == ("inner" if side == "InnerDoor" else "outer") else 0.0
		door.sync_to_physics = true
	airlock.state_changed.emit()
