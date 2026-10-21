extends CharacterBody3D
const TUNING = preload("res://resources/threats/mutant.tres")
const Senses = preload("res://scripts/threats/mutant_senses.gd")
const Events = preload("res://scripts/simulation/emission_events.gd")
const Model = preload("res://scripts/drones/drone.gd")
var identity := "approach_scout"
var home := Vector3(42,0.02,-112)
var shelter := Vector3(43,0.02,-114)
var mode := "patrol"
var memory := 0.0
var strike_remaining := 0.0
var stun_remaining := 0.0
var integrity := 100.0
var target_id := ""
var last_known := Vector3.ZERO
var patrol_index := 0
var fence_grip_band := -1
var world: Node
var interaction: OutpostInteractable

func _ready() -> void:
	world = get_parent().get_parent()
	floor_snap_length = 0.4
	add_to_group("hostile_pings")
	add_to_group("sensor_landmarks")
	set_meta("thermal",0.8)
	set_meta("classification","Organic hostile")
	interaction = OutpostInteractable.new()
	interaction.name = "Interaction"
	interaction.display_name = "Emergency flash / jumper cell"
	add_child(interaction)
	interaction.used.connect(func(_target): world.get_node("HumanSortie").emergency_flash(self))

func _physics_process(delta: float) -> void:
	strike_remaining = maxf(0.0,strike_remaining - delta)
	if strike_remaining<=0: fence_grip_band = -1
	stun_remaining = maxf(0.0,stun_remaining - delta)
	interaction.enabled = integrity > 0.0 and world.get_node("HumanSortie").active and not world.get_node("HumanSortie").dead
	if integrity <= 0.0 or stun_remaining > 0.0:
		mode = "dead" if integrity <= 0.0 else "stunned"
		_move(Vector3.ZERO,delta)
		return
	var heard := Senses.strongest(self,world,world.get_node("Emissions").sources())
	var goal: Vector3
	var speed: float = TUNING.patrol_speed
	var rainy: bool = world.get_node("Weather").current == "rain"
	var siege: Node = world.get_node_or_null("Siege")
	var order: Dictionary = siege.goal(identity) if siege!=null else {}
	var breaches: Node = world.get_node_or_null("Breaches")
	var breach_order: Dictionary = breaches.goal(self,not heard.is_empty()) if breaches!=null else {}
	var intruder: bool = breaches!=null and breaches.is_intruder(identity)
	if intruder: order = {}
	var lure: bool = not heard.is_empty() and world.get_node("Defense").decoys.get(heard.source,false)
	if not heard.is_empty() and heard.kind == "light":
		mode = "avoid_light"
		memory = 0.0
		goal = global_position + (global_position - heard.at).normalized() * 4.0
		speed = TUNING.hunt_speed
	elif rainy and not intruder and (heard.is_empty() or heard.distance > 5.0):
		mode = "shelter"
		memory = 0.0
		goal = shelter
	elif lure:
		mode = "hunt"
		target_id = heard.source
		last_known = heard.at
		memory = TUNING.memory_seconds
		goal = last_known
		speed = TUNING.hunt_speed
	elif not breach_order.is_empty():
		mode = "breach"
		goal = breach_order.at
		speed = TUNING.hunt_speed
	elif not order.is_empty():
		mode = "siege"
		if not heard.is_empty() and not heard.source.is_empty():
			target_id = heard.source
		goal = order.at
		speed = TUNING.hunt_speed
	elif not heard.is_empty():
		mode = "hunt"
		target_id = heard.source
		last_known = heard.at
		memory = TUNING.memory_seconds
		goal = last_known
		speed = TUNING.hunt_speed
	elif memory > 0.0:
		mode = "investigate"
		memory = maxf(0.0,memory - delta)
		goal = last_known
		speed = TUNING.hunt_speed
	else:
		mode = "patrol"
		target_id = ""
		var offsets := [Vector3(-4,0,3),Vector3(3,0,4),Vector3(4,0,-3),Vector3(-3,0,-4)]
		goal = home + offsets[patrol_index]
		if global_position.distance_to(goal) < 0.7: patrol_index = (patrol_index + 1) % 4
	var gap := goal - global_position
	gap.y = 0.0
	_move(gap.normalized() * speed if gap.length() > 0.65 else Vector3.ZERO,delta)
	if mode in ["hunt","investigate","siege","breach"]:
		if strike_remaining<=0 and world.get_node("Defense").attack_near(self,TUNING.strike_damage):
			strike_remaining = TUNING.strike_interval
		elif strike_remaining<=0 and breaches!=null and breaches.strike_near(self,TUNING.strike_damage):
			strike_remaining = TUNING.strike_interval
		else: _strike()

func _move(desired: Vector3, delta: float) -> void:
	# Short collision feelers steer around cover; never teleport or cross solids.
	if desired.length() > 0.0 and test_move(global_transform,desired.normalized() * 0.8):
		var clear := false
		for angle in [PI/4,-PI/4,PI/2,-PI/2]:
			var detour := desired.rotated(Vector3.UP,angle)
			if not test_move(global_transform,detour.normalized() * 0.8):
				desired = detour
				clear = true
				break
		if not clear: desired = Vector3.ZERO
	velocity.x = desired.x
	velocity.z = desired.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - 9.8 * delta
	if desired.length() > 0.01: rotation.y = atan2(-desired.x,-desired.z)
	move_and_slide()

func _strike() -> void:
	if strike_remaining > 0.0 or target_id.is_empty(): return
	var target: Node = world.get_node("Operator") if target_id == "operator" else world.get_node("Fleet").drone(target_id)
	if target == null or global_position.distance_to(target.global_position) > TUNING.strike_reach or not Senses.clear_reach(self,target.global_position,target): return
	if target_id == "operator":
		var human: Node = world.get_node("HumanSortie")
		var breaches: Node = world.get_node_or_null("Breaches")
		if human.dead or (not human.active and (breaches==null or not breaches.is_intruder(identity))): return
		human.kill("Mutant strike breached the hazard suit." if human.active else "A mutant reached the unprotected operator.")
	else:
		if not target.deployed or target.destroyed(): return
		target.apply_damage(TUNING.strike_damage)
	strike_remaining = TUNING.strike_interval

func stun(seconds: float) -> void:
	stun_remaining = maxf(stun_remaining,clampf(seconds,0.0,3.0))
	velocity.x = 0.0
	velocity.z = 0.0

func apply_damage(amount: float) -> void:
	if not is_finite(amount) or amount <= 0.0: return
	integrity = maxf(0.0,integrity - amount)
	if integrity <= 0.0:
		collision_layer = 0
		set_meta("thermal",0.05)
		set_meta("classification","Organic remains")
		remove_from_group("hostile_pings")
		get_node("Visual").scale.y = 0.25

func snapshot() -> Dictionary:
	return {"id":identity,"at":[position.x,position.y,position.z],"home":[home.x,home.y,home.z],"shelter":[shelter.x,shelter.y,shelter.z],"yaw":rotation.y,"mode":mode,"memory":memory,"strike":strike_remaining,"stun":stun_remaining,"integrity":integrity,"target":target_id,"last_known":[last_known.x,last_known.y,last_known.z],"patrol":patrol_index,"fence_grip":fence_grip_band}

static func validate(data: Variant) -> bool:
	if not data is Dictionary or not data.get("id") is String or data.id.is_empty() or data.id.length() > 80 or data.get("mode") not in ["patrol","hunt","investigate","shelter","avoid_light","stunned","dead","siege","breach"] or not data.get("target") is String or data.target.length() > 80: return false
	for key in ["at","home","shelter","last_known"]:
		if not Events.valid_position(data.get(key)): return false
	var limits := {"yaw":1000000.0,"memory":16.0,"strike":2.0,"stun":3.0,"integrity":100.0,"patrol":3.0}
	for key in limits:
		if not Model._range(data.get(key),-1000000.0 if key == "yaw" else 0.0,limits[key]): return false
	if not Model._range(data.get("fence_grip",-1),-1,5) or data.get("fence_grip",-1)!=int(data.get("fence_grip",-1)): return false
	return data.patrol == int(data.patrol)

func restore(data: Dictionary) -> void:
	assert(validate(data))
	position = Vector3(data.at[0],data.at[1],data.at[2])
	home = Vector3(data.home[0],data.home[1],data.home[2])
	shelter = Vector3(data.shelter[0],data.shelter[1],data.shelter[2])
	rotation.y = data.yaw
	mode = data.mode
	memory = data.memory
	strike_remaining = data.strike
	stun_remaining = data.stun
	integrity = data.integrity
	target_id = data.target
	last_known = Vector3(data.last_known[0],data.last_known[1],data.last_known[2])
	patrol_index = int(data.patrol)
	fence_grip_band = int(data.get("fence_grip",-1))
	velocity = Vector3.ZERO
	if integrity <= 0.0: apply_damage(0.01)
