extends Node
signal changed
const Rule = preload("res://scripts/autonomy/rule_block.gd")
const Work = preload("res://scripts/drones/work_reservations.gd")
var programs: Dictionary = {}
var local_field_power: bool = false
var logic_rate: float = 1.0
var decision_clock := 1.0/12.0
var decision_elapsed := 0.0
var decision_count := 0
var held_commands: Dictionary = {}
@onready var fleet: Node3D = get_parent().get_node("Fleet")
@onready var radio: Node = get_parent().get_node("Radio")
@onready var control: Node = get_parent().get_node("FleetControl")
var status := "Build rule blocks, then transmit to the selected hull."

func submit(id: String, rules: Array) -> bool:
	var drone: Node = fleet.drone(id)
	if drone == null or radio.quality(drone) <= 0.0 or not Rule.valid(rules):
		status = "Invalid blocks or radio unavailable."
		return false
	programs[id] = {"rules":rules.duplicate(true),"cursor":0,"mode":"running","blocked":0.0,"return_cursor":-1}
	held_commands.erase(id)
	drone.get_node("Controller").stop()
	decision_clock = 1.0/12.0
	drone.silent_running = false
	status = "Program transmitted to " + id + "."
	changed.emit()
	return true

func stop(id: String, interrupted: bool = false) -> void:
	var target: Node = fleet.drone(id)
	if not interrupted and target != null and radio.quality(target) <= 0.0:
		status = "Stop command rejected: radio unavailable."
		return
	if programs.has(id):
		programs[id].mode = "interrupted" if interrupted else "stopped"
	var drone: Node = fleet.drone(id)
	if drone != null:
		drone.silent_running = false
		drone.get_node("Controller").stop()
	changed.emit()

func is_returning(id: String) -> bool:
	return programs.has(id) and programs[id].mode == "return"

func field_powered(id: String) -> bool:
	var drone: Node = fleet.drone(id)
	var assigned: bool = Work.busy(get_parent(),id)
	return local_field_power and drone != null and drone.deployed and (assigned or (programs.has(id) and programs[id].mode in ["running","return","complete"]))

func _physics_process(delta: float) -> void:
	decision_clock += delta
	decision_elapsed += delta
	var interval := 1.0/(12.0*logic_rate)
	if decision_clock+0.000000001>=interval:
		decision_clock = maxf(0,decision_clock-interval*floor((decision_clock+0.000000001)/interval))
		decision_count += 1
		advance(decision_elapsed)
		decision_elapsed = 0.0
		for id in programs:
			var d: Node = fleet.drone(id)
			if Work.controls(get_parent(),id): continue
			if d!=null: held_commands[id] = d.get_node("Controller").command
	else:
		for id in programs:
			var d: Node = fleet.drone(id)
			if Work.controls(get_parent(),id): continue
			if control.piloting and control.selected_id==id:
				stop(id,true)
			elif d!=null and d.deployed and d.has_power() and programs[id].mode in ["running","return","complete"] and (radio.quality(d)>0 or field_powered(id)) and held_commands.has(id):
				d.get_node("Controller").command = held_commands[id]

func advance(delta: float) -> void:
	for id in programs:
		var drone: CharacterBody3D = fleet.drone(id)
		var p: Dictionary = programs[id]
		if drone == null:
			continue
		if Work.controls(get_parent(),id):
			drone.get_node("Controller").stop()
			continue
		if control.piloting and control.selected_id == id and p.mode in ["running","return","complete","blocked"]:
			stop(id,true)
			status = "Manual pilot interrupted " + id + "."
			continue
		if p.mode not in ["running","return","complete"]:
			continue
		var human: Node = get_parent().get_node("HumanSortie")
		if human.active and human.escort_id == id:
			continue
		if not drone.deployed:
			if p.mode == "return":
				p.mode = "complete"
				drone.silent_running = false
			continue
		if not drone.has_power() or (radio.quality(drone) <= 0.0 and not field_powered(id)):
			continue # Existing freeze/retrace owns the motor on ordinary loss.
		var kinds := []
		var points: Array[Vector3] = []
		for rule in p.rules:
			kinds.append(rule.kind)
			if rule.kind == "waypoint":
				points.append(Vector3(rule.x,0.02,-10.0 - rule.north))
		if p.mode in ["running","complete"] and "battery_abort" in kinds and get_parent().get_node("DronePower").reserve_fraction(drone) < 0.2 and not field_powered(id):
			p.mode = "return"
			p.return_cursor = get_parent().get_node("Failsafes").history(id).points.size() - 1
			status = id + " / low cell: return before all other work."
		if "hostile_silent" in kinds:
			if not drone.silent_running:
				drone.get_node("Sonar").ping()
			drone.silent_running = not drone.get_node("Sonar").hostile_contacts.is_empty()
		if p.mode == "return":
			_return(drone,p,delta)
			continue
		if "scrap_collect" in kinds:
			get_parent().get_node("Salvage").recover_nearest(drone)
		if p.mode == "complete":
			drone.get_node("Controller").stop()
			continue
		if points.is_empty():
			continue # Standing conditions can run without a travel block.
		if p.cursor >= points.size():
			p.mode = "complete"
			drone.get_node("Controller").stop()
			status = id + " / route complete."
			continue
		if drone.position.distance_to(points[p.cursor]) < 0.6:
			p.cursor += 1
			drone.get_node("Controller").stop()
		else:
			_steer(drone,p,points[p.cursor],delta)

func _return(drone: Node, p: Dictionary, delta: float) -> void:
	if drone.position.distance_to(Vector3(0,0.02,-14)) <= 6.0:
		drone.get_node("Controller").stop()
		if drone.hull().external_power:
			if control.transfer.is_empty() and control.request_machine_transfer(drone,false):
				p.mode = "complete"
				status = drone.identity + " / exterior gantry reached."
			return
		if control.transfer.is_empty():
			control.request_machine_transfer(drone,false)
		return
	var points: Array[Vector3] = get_parent().get_node("Failsafes").history(drone.identity).points
	if p.return_cursor < 0 or p.return_cursor >= points.size():
		p.mode = "blocked"
		status = drone.identity + " / no remembered safe route home."
		drone.get_node("Controller").stop()
		return
	var destination: Vector3 = points[p.return_cursor]
	if drone.position.distance_to(destination) < 0.5:
		p.return_cursor -= 1
	else:
		_steer(drone,p,destination,delta)

func _steer(drone: CharacterBody3D, p: Dictionary, destination: Vector3, delta: float) -> void:
	var offset := destination - drone.position
	offset.y = 0.0
	if not drone.get_node("Controller").can_traverse(offset.normalized() * 0.35):
		drone.get_node("Controller").stop()
		p.blocked = minf(3.0,p.blocked + delta)
		if p.blocked >= 3.0:
			p.mode = "blocked"
			status = drone.identity + " / route obstructed; edit waypoints."
		return
	p.blocked = 0.0
	var heading := atan2(-offset.x,-offset.z)
	var error := wrapf(heading - drone.rotation.y,-PI,PI)
	drone.get_node("Controller").command = Vector2(clampf(-error * 2.0,-1,1),-1.0 if absf(error) < 0.35 else 0.0)

func snapshot() -> Dictionary:
	return programs.duplicate(true)
static func validate(data: Variant) -> bool:
	if not data is Dictionary or data.size() > 32:
		return false
	for id in data:
		var p: Variant = data[id]
		if not id is String or not p is Dictionary or not Rule.valid(p.get("rules")) or p.get("mode") not in ["running","return","blocked","complete","stopped","interrupted"]:
			return false
		for key in ["cursor","return_cursor","blocked"]:
			var value: Variant = p.get(key)
			if not (value is float or value is int) or not is_finite(value):
				return false
		if p.cursor != int(p.cursor) or p.cursor < 0 or p.cursor > 32 or p.return_cursor != int(p.return_cursor) or p.return_cursor < -1 or p.return_cursor > 2047 or p.blocked < 0.0 or p.blocked > 3.0:
			return false
	return true
func restore(data: Dictionary) -> void:
	assert(validate(data))
	programs = data.duplicate(true)
	held_commands.clear()
	decision_clock = 1.0/12.0
	decision_elapsed = 0.0
	for drone in fleet.get_children():
		drone.silent_running = false
		drone.get_node("Controller").stop()
