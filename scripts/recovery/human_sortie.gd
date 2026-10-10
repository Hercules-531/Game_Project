extends Node
signal died(reason: String)
signal changed
const Suit = preload("res://scripts/player/hazard_suit.gd")
const Interaction = preload("res://scripts/interaction/interactable.gd")
var active := false
var departed := false
var dead := false
var reason := ""
var oxygen: float = Suit.OXYGEN_SECONDS
var filter: float = Suit.FILTER_SECONDS
var jumper: float = 0.0
var escort_id := ""
var status := "Suit is reserved for a stranded fleet."
@onready var operator: CharacterBody3D = get_parent().get_node("Operator")
@onready var fleet: Node3D = get_parent().get_node("Fleet")
@onready var airlock: Node3D = get_parent().get_node("Bunker/Airlock")
var bindings: Dictionary = {}

func _ready() -> void:
	var bunker: Node3D = get_parent().get_node("Bunker")
	var locker: Node3D = bunker._prop("box","SuitLocker",Vector3(-0.9,0.02,-4.7),0,1.7)
	var use := Interaction.new()
	use.name = "Interaction"
	use.display_name = "Emergency suit locker"
	locker.add_child(use)
	use.used.connect(func(_target): get_parent().get_node("SuitPanel").open())
	bunker._sign("SuitSign","EMERGENCY / SUIT",Vector3(-1.19,1.5,-4.7),90)
	for entry in [["OuterControlInside",Vector3(-1.03,1.35,-9.9),90.0],["OuterControlOutside",Vector3(-1.03,1.35,-10.1),-90.0]]:
		var prop: Node3D = bunker._prop("switch",entry[0],entry[1],entry[2])
		var button := Interaction.new()
		button.name = "Interaction"
		button.display_name = "Cycle outer airlock"
		prop.add_child(button)
		button.used.connect(func(_target):
			if active and not dead:
				if airlock.opened_side == &"outer":
					airlock.request_close()
				else:
					airlock.request_open(&"outer"))

func fleet_unavailable() -> bool:
	for drone in fleet.get_children():
		if not drone.deployed:
			return false
		if drone.battery > 0.0 and get_parent().get_node("Radio").quality(drone) > 0.0:
			return false
	return true

func suit_up() -> bool:
	var life: Node = get_parent().get_node("LifeSupport")
	var stock: Node = get_parent().get_node("Inventory")
	if active or dead or operator.position.z < -6.0 or not fleet_unavailable() or life.oxygen < 2.0 or life.battery < Suit.JUMPER_KWH or stock.scrap < 5:
		status = "Suit requires a stranded fleet, 5 scrap, 2% O2 and 0.30 kWh."
		return false
	stock.spend_scrap(5)
	life.oxygen -= 2.0
	life.battery -= Suit.JUMPER_KWH
	active = true
	departed = false
	oxygen = Suit.OXYGEN_SECONDS
	filter = Suit.FILTER_SECONDS
	jumper = Suit.JUMPER_KWH
	operator.walk_speed = Suit.WALK_SPEED
	airlock.outer_authorized = true
	status = "Close inner door, then cycle outer. Revive one frame and lead it home."
	changed.emit()
	return true

func finish() -> bool:
	if not active or dead or operator.position.z < -6.0 or airlock.busy or airlock.opened_side == &"outer":
		return false
	if departed:
		var escort: Node = fleet.drone(escort_id)
		if escort == null or escort.battery <= 0.0 or escort.position.distance_to(Vector3(0,0,-14)) > 8.0:
			status = "Bring a revived escort to the airlock before stowing the suit."
			return false
	active = false
	operator.walk_speed = 2.6
	airlock.outer_authorized = false
	if fleet.drone(escort_id) != null:
		fleet.drone(escort_id).get_node("Controller").stop()
	escort_id = ""
	status = "Suit stowed. Dock the recovered machine from the command desk."
	changed.emit()
	return true

func _physics_process(delta: float) -> void:
	_bind_frames()
	advance(delta)
	_escort()

func _bind_frames() -> void:
	for drone in fleet.get_children():
		var button: Node = drone.get_node_or_null("Interaction")
		if button == null:
			button = Interaction.new()
			button.name = "Interaction"
			button.display_name = "Wake machine / jumper"
			drone.add_child(button)
			button.used.connect(func(_target): revive(drone))
		# Interactor looks for this conventional name on the collider's parent.
		button.enabled = active and not dead and drone.deployed and drone.battery <= 0.01
		bindings[drone.identity] = button

func revive(target: Node) -> bool:
	if not active or dead or target == null or not target.deployed or target.battery > 0.01 or operator.position.distance_to(target.position) > 3.0 or jumper <= 0.0 or target.component_efficiency("cell") <= 0.0:
		status = "Reach a dead cell within 3m; jumper charge is finite."
		return false
	var ray := PhysicsRayQueryParameters3D.create(operator.position + Vector3(0,1.55,0),target.position + Vector3(0,0.7,0),1,[operator.get_rid()])
	var hit: Dictionary = operator.get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty() and hit.collider != target:
		status = "Jumper blocked by solid cover."
		return false
	var paid: float = minf(0.25,minf(jumper,(target.hull().battery_kwh - target.battery) / 0.9))
	jumper -= paid
	target.battery += paid * 0.9
	escort_id = target.identity
	status = "Escort awake. Walk home; it follows physically. Watch both gauges."
	changed.emit()
	return true

func advance(delta: float) -> void:
	if not active or dead or not is_finite(delta) or delta <= 0.0:
		return
	oxygen = maxf(0.0,oxygen - delta)
	if operator.position.z < -10.0:
		departed = true
		filter = maxf(0.0,filter - delta)
	if oxygen <= 0.0 or filter <= 0.0:
		kill("Suit oxygen exhausted." if oxygen <= 0.0 else "Suit filter failed.")

func kill(message: String) -> void:
	if dead:
		return
	dead = true
	reason = message
	operator.movement_enabled = false
	if fleet.drone(escort_id) != null:
		fleet.drone(escort_id).get_node("Controller").stop()
	died.emit(reason)

func _escort() -> void:
	if not active or dead or escort_id.is_empty():
		return
	var body: CharacterBody3D = fleet.drone(escort_id)
	if body == null or body.battery <= 0.0:
		return
	var driver: Node = body.get_node("Controller")
	# Escort waits at the exterior cradle when the operator enters the airlock.
	var goal: Vector3 = operator.position if operator.position.z <= -10.0 else Vector3(0,0.02,-14)
	var gap: Vector3 = goal - body.position
	if gap.length() <= 2.5:
		driver.stop()
		return
	var yaw := atan2(-gap.x,-gap.z)
	var error := wrapf(yaw - body.rotation.y,-PI,PI)
	var forward: Vector3 = -body.global_basis.z * 0.4
	if body.test_move(body.global_transform,forward):
		driver.stop()
		status = "Escort blocked. Lead around the obstacle."
		return
	driver.command = Vector2(clampf(-error / 0.5,-1,1),-0.45 if absf(error) < 0.4 else 0.0)

func snapshot() -> Dictionary:
	return {"active":active,"departed":departed,"dead":dead,"reason":reason,"oxygen":oxygen,"filter":filter,"jumper":jumper,"escort":escort_id}

func restore(data: Dictionary) -> void:
	assert(Suit.validate(data))
	active = data.active
	departed = data.departed
	dead = data.dead
	reason = data.reason
	oxygen = data.oxygen
	filter = data.filter
	jumper = data.jumper
	escort_id = data.escort
	operator.walk_speed = Suit.WALK_SPEED if active else 2.6
	operator.movement_enabled = not dead
	_bind_frames()
