extends Node

signal changed
const Drone = preload("res://scripts/drones/drone.gd")
var selected_id: String = "mule_01"
var piloting: bool = false
var panel_open: bool = false
var transfer: Dictionary = {}
var status: String = "Select a machine."
var held := Vector2.ZERO
var link := preload("res://scripts/telemetry/command_link.gd").new()
@onready var fleet: Node3D = get_parent().get_node("Fleet")
@onready var airlock: Node3D = get_parent().get_node("Bunker/Airlock")


func _ready() -> void:
	get_parent().get_node("LifeSupport").energy_step.connect(func(fraction: float):
		if transfer.get("gantry",false): advance_transfer(fraction,true))
	InputContext.context_changed.connect(func(context: int):
		if context != InputContext.Context.TERMINAL:
			panel_open = false
			piloting = false
			held = Vector2.ZERO
			stop_all())


func selected() -> Node:
	return fleet.drone(selected_id)


func select(id: String) -> bool:
	if fleet.drone(id) == null:
		return false
	stop_all()
	held = Vector2.ZERO
	selected_id = id
	changed.emit()
	return true


func stop_all() -> void:
	link.clear_all()
	for machine in fleet.get_children():
		machine.get_node("Controller").stop()


func _physics_process(delta: float) -> void:
	advance_transfer(delta)
	link.advance(delta)
	var machine := selected()
	stop_all_commands()
	var radio: Node = get_parent().get_node("Radio")
	if machine != null and machine.hull().script_only and piloting:
		piloting = false
		held = Vector2.ZERO
		status = "Heavy hull requires standing rule blocks."
	for drone in fleet.get_children():
		if radio.quality(drone) <= 0.0:
			link.clear(drone.identity)
			if drone.identity == selected_id:
				piloting = false
				held = Vector2.ZERO
	if machine != null and panel_open and piloting and InputContext.active == InputContext.Context.TERMINAL and transfer.is_empty():
		var keys := Input.get_vector("move_left","move_right","move_forward","move_back")
		if radio.quality(machine) > 0.0:
			link.send(machine.identity,(keys + held).limit_length(1.0),radio.latency(machine))
		machine.get_node("Controller").command = link.receive(machine.identity,radio.quality(machine) > 0.0)
	for action in link.ready_actions():
		var drone: Node = fleet.drone(action.id)
		if drone == null or radio.quality(drone) <= 0.0:
			continue
		if action.kind == "ping":
			drone.get_node("Sonar").ping()
		elif action.kind == "camera":
			status = "Camera attached. Dock to unload it." if get_parent().get_node("CameraDiscovery").recover(drone) else "No case in reach / no carrying hardware."
		elif action.kind == "salvage":
			status = "Cargo attached. Dock to unload it." if get_parent().get_node("Salvage").recover_nearest(drone) else "No salvage in reach / insufficient carrying capacity."


func request_action(kind: String) -> bool:
	var machine := selected()
	var radio: Node = get_parent().get_node("Radio")
	if machine == null or radio.quality(machine) <= 0.0 or kind not in ["ping","camera","salvage"]:
		status = "Command rejected: link unavailable."
		return false
	link.send_action(machine.identity,kind,radio.latency(machine))
	status = "Command transmitted."
	return true


func stop_all_commands() -> void:
	for machine in fleet.get_children():
		machine.get_node("Controller").command = Vector2.ZERO


func request_transfer(deploy: bool) -> bool:
	return request_machine_transfer(selected(),deploy)

func request_machine_transfer(machine: Node, deploy: bool) -> bool:
	if machine == null or machine.deployed == deploy or airlock.busy or airlock.opened_side != &"" or not transfer.is_empty():
		status = "Close the airlock and finish its current transfer first."
		return false
	if not deploy and machine.position.distance_to(Vector3(0,0,-14)) > 8.0:
		status = "Drive within 8m of the airlock to dock."
		return false
	if not deploy and not get_parent().get_node("Recovery").dock_tow(machine):
		status = "Tow frame must also reach the local airlock cradle."
		return false
	if machine.hull().external_power:
		if deploy: return false
		stop_all()
		piloting = false
		airlock.busy = true
		machine.get_node("Controller").available = false
		transfer = {"id":machine.identity,"deploy":true,"remaining":8.0,"at":machine.position,"gantry":true}
		get_parent().get_node("LifeSupport").gantry_load_kw = 0.6
		status = "Exterior gantry unload: 8 paid seconds."
		changed.emit()
		return true
	var destination := _destination(machine,deploy)
	if destination.is_empty():
		status = "Receiving bay obstructed. Clear it before transfer."
		return false
	stop_all()
	piloting = false
	airlock.busy = true
	machine.get_node("Controller").available = false
	transfer = {"id":machine.identity,"deploy":deploy,"remaining":8.0,"at":destination[0]}
	machine.get_node("Visual").hide()
	machine.get_node("Collision").set_deferred("disabled",true)
	status = "Sealed airlock loader: 8 seconds."
	changed.emit()
	return true


func _destination(machine: Node, deploy: bool) -> Array:
	var positions := [Vector3(-2,0.02,-14),Vector3(2,0.02,-14)] if deploy else [Vector3(-5.3,0.02,0.8),Vector3(-3.7,0.02,0.8),Vector3(-5.95,0.02,3)]
	for at in positions:
		if _clear(machine,at):
			return [at]
	return []


func _clear(machine: Node, at: Vector3) -> bool:
	var shape := BoxShape3D.new()
	shape.size = Drone.collision_size(machine.hull_id)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY,at + Vector3(0,shape.size.y*0.5,0))
	query.collision_mask = 1
	query.exclude = [machine.get_rid()]
	return machine.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()


func advance_transfer(delta: float, paid: bool = false) -> void:
	if transfer.is_empty():
		return
	if transfer.get("gantry",false) and not paid: return
	transfer.remaining = maxf(0.0,transfer.remaining - delta)
	if transfer.remaining > 0.0:
		return
	var machine: Node = fleet.drone(transfer.id)
	if not _clear(machine,transfer.at):
		status = "Loader held: receiving bay became obstructed."
		return
	machine.position = transfer.at
	machine.rotation.y = 0.0
	machine.deployed = transfer.deploy
	machine.get_node("Controller").available = true
	machine.get_node("Visual").show()
	machine.get_node("Collision").set_deferred("disabled",false)
	var exterior: bool = transfer.get("gantry",false)
	if not machine.deployed or exterior:
		get_parent().get_node("Salvage").deliver(machine,exterior)
		get_parent().get_node("CameraDiscovery").unload(machine,exterior)
		get_parent().get_node("Recovery").deliver(machine,exterior)
	get_parent().get_node("LifeSupport").gantry_load_kw = 0.0
	transfer.clear()
	airlock.busy = false
	get_parent().get_node("Workshop").changed.emit()
	status = "Transfer complete."
	changed.emit()
