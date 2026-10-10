extends RefCounted

const VERSION := 14
const Orders = preload("res://scripts/autonomy/order_runner.gd")
const Suit = preload("res://scripts/player/hazard_suit.gd")
const Recovery = preload("res://scripts/recovery/recovery_controller.gd")
const Salvage = preload("res://scripts/salvage/delivery_zone.gd")
const Failsafes = preload("res://scripts/autonomy/failsafe_controller.gd")
const Conditions = preload("res://scripts/drones/malfunction_system.gd")
const Radio = preload("res://scripts/telemetry/radio_network.gd")
const DronePower = preload("res://scripts/drones/power_system.gd")
const Discovery = preload("res://scripts/salvage/camera_discovery.gd")
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
		"fabrication":world.get_node("Fabrication").snapshot(),
		"camera_discovery":world.get_node("CameraDiscovery").snapshot(),
		"drone_power":world.get_node("DronePower").snapshot(),
		"radio":world.get_node("Radio").snapshot(),
		"conditions":world.get_node("Conditions").snapshot(),
		"failsafes":world.get_node("Failsafes").snapshot(),
		"salvage":world.get_node("Salvage").snapshot(),
		"recovery":world.get_node("Recovery").snapshot(),
		"human_sortie":world.get_node("HumanSortie").snapshot(),
		"orders":world.get_node("Orders").snapshot()}


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
	if data.version >= 6:
		if not Discovery.validate(data.get("camera_discovery")):
			return "Invalid camera discovery."
		if data.camera_discovery.state == "carried":
			var found := false
			for machine in data.fleet:
				found = found or (machine.id == data.camera_discovery.owner and machine.cargo_kg >= 4.0)
			if not found:
				return "Missing camera carrier."
	if data.version >= 7 and not DronePower.validate(data.get("drone_power")):
		return "Invalid charging state."
	if data.version >= 8 and not Radio.validate(data.get("radio")):
		return "Invalid radio schedule."
	if data.version >= 9:
		if not Conditions.validate(data.get("conditions")):
			return "Invalid wear schedule."
		for machine in data.fleet:
			if not machine.has("components") or not machine.has("faults"):
				return "Missing chassis condition."
	if data.version >= 10 and not Failsafes.validate(data.get("failsafes")):
		return "Invalid breadcrumb state."
	if data.version >= 11:
		if data.version >= 12 and not Recovery.validate(data.get("recovery")):
			return "Invalid recovery state."
		if not Salvage.validate(data.get("salvage")):
			return "Invalid salvage state."
		var masses := {}
		for record in data.salvage:
			if record.state == "carried":
				for definition in Salvage.CATALOG.sites:
					if definition.id == record.id:
						masses[record.carrier] = masses.get(record.carrier,0.0) + definition.mass
		if data.camera_discovery.state == "carried":
			masses[data.camera_discovery.owner] = masses.get(data.camera_discovery.owner,0.0) + 4.0
		if data.version >= 12:
			for record in data.recovery.values():
				if record.state == "parts":
					masses[record.owner] = masses.get(record.owner,0.0) + 20.0
		for id in masses:
			var found := false
			for machine in data.fleet:
				found = found or (machine.id == id and machine.cargo_kg + 0.000001 >= masses[id])
			if not found:
				return "Invalid salvage carrier mass."
	if data.version >= 12:
		if not Recovery.validate(data.get("recovery")):
			return "Invalid recovery state."
		for id in data.recovery:
			var record: Dictionary = data.recovery[id]
			var found := false
			for machine in data.fleet:
				if record.state == "awake" and machine.id == id:
					found = true
				if record.state in ["parts","stripping","towing"] and machine.id == record.owner:
					found = record.state != "parts" or machine.cargo_kg >= 20.0
			if record.state in ["awake","parts","stripping","towing"] and not found:
				return "Missing recovered frame or carrier."
	if data.version >= 13:
		if not Suit.validate(data.get("human_sortie")):
			return "Invalid human sortie."
		if data.human_sortie.active and not data.airlock.outer_authorized:
			return "Suit lacks surface authorization."
		if not data.human_sortie.escort.is_empty():
			var found := false
			for machine in data.fleet:
				found = found or machine.id == data.human_sortie.escort
			if not found:
				return "Missing human escort."
	if data.version >= 14:
		if not Orders.validate(data.get("orders")):
			return "Invalid rule program."
		for id in data.orders:
			var found := false
			for machine in data.fleet:
				found = found or machine.id == id
			if not found:
				return "Missing programmed frame."
			if data.orders[id].mode == "return" and data.orders[id].return_cursor >= data.failsafes.get(id,{}).get("points",[]).size():
				return "Invalid remembered return cursor."
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
	if data.version >= 6:
		world.get_node("CameraDiscovery").restore(data.camera_discovery)
	if data.version >= 7:
		world.get_node("DronePower").restore(data.drone_power)
	if data.version >= 8:
		world.get_node("Radio").restore(data.radio)
	if data.version >= 9:
		world.get_node("Conditions").restore(data.conditions)
	if data.version >= 10:
		world.get_node("Failsafes").restore(data.failsafes)
	if data.version >= 11:
		world.get_node("Salvage").restore(data.salvage)
	if data.version >= 12:
		world.get_node("Recovery").restore(data.recovery)
	if data.version >= 13:
		world.get_node("HumanSortie").restore(data.human_sortie)
	if data.version >= 14:
		world.get_node("Orders").restore(data.orders)
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
