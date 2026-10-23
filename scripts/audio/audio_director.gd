extends Node3D
## Presentation only: reads simulation emissions and never creates AI events.
signal cue_played(cue: String, source: String, at: Vector3)
const Synth = preload("res://scripts/audio/audio_synth.gd")
var listener: AudioListener3D
var loops: Dictionary = {}
var voices: Array[AudioStreamPlayer3D] = []
var pending: Array = []
var clocks: Dictionary = {}
var recent: Array = []
var remote_id := ""
var link_gain := 1.0
var last_rail := 0.0
var weather_voice: AudioStreamPlayer
var vent_voice: AudioStreamPlayer3D
var alarm_voice: AudioStreamPlayer
var breath_voice: AudioStreamPlayer
var echo_voice: AudioStreamPlayer
@onready var world: Node = get_parent()
@onready var emissions: Node = world.get_node("Emissions")
func _ready() -> void:
	process_physics_priority = 100
	get_viewport().audio_listener_enable_3d = true
	listener = AudioListener3D.new()
	listener.name = "Listener"
	add_child(listener)
	listener.make_current()
	weather_voice = _local("Weather","Ambience")
	alarm_voice = _local("Instruments","Effects")
	breath_voice = _local("SuitBreath","Effects")
	echo_voice = _local("SonarReturns","Effects")
	vent_voice = _spatial("vent","Ambience",true)
	vent_voice.position = Vector3(0,1.5,7)
	vent_voice.set_meta("reach",20.0)
	vent_voice.set_meta("base_db",-22.0)
	emissions.audible.connect(_on_pulse)
	_bind_sonar()
	last_rail = world.get_node("Rail").freight.coordinate
func _local(label: String, bus_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = label
	player.bus = bus_name
	add_child(player)
	return player
func _spatial(cue: String, bus_name: String = "Effects", loop: bool = false) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = Synth.stream(cue)
	player.bus = bus_name
	player.unit_size = 2.5
	player.max_db = 0
	player.set_meta("cue",cue)
	add_child(player)
	if not loop:
		voices.append(player)
		player.finished.connect(func(): voices.erase(player); player.queue_free())
	return player
func update_listener() -> void:
	var control: Node = world.get_node("FleetControl")
	var selected: Node = control.selected()
	remote_id = ""
	link_gain = 1
	if control.panel_open and InputContext.active==InputContext.Context.TERMINAL and selected!=null and selected.deployed and selected.has_power():
		var quality: float = world.get_node("Radio").quality(selected)
		if quality>0:
			remote_id = selected.identity
			link_gain = quality
			listener.global_transform = selected.get_node("CCD").eye_transform()
			return
	listener.global_transform = world.get_node("Operator/Head/Camera").global_transform
func _mix(player: AudioStreamPlayer3D) -> void:
	var reach: float = player.get_meta("reach",20.0)
	var covered := false
	var exclusions: Array[RID] = [world.get_node("Operator").get_rid()]
	if not remote_id.is_empty(): exclusions.append(world.get_node("Fleet").drone(remote_id).get_rid())
	var query := PhysicsRayQueryParameters3D.create(listener.global_position,player.global_position,1,exclusions)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.position.distance_to(player.global_position)>1.2: covered = true
	player.max_distance = reach*(0.35 if covered else 1.0)
	player.volume_db = float(player.get_meta("base_db",-15.0))+(linear_to_db(maxf(0.0001,link_gain)))+(-12.0 if covered else 0.0)
	player.set_meta("covered",covered)
func _record(cue: String, source: String, at: Vector3) -> void:
	recent.append({"cue":cue,"source":source,"at":at})
	if recent.size()>32: recent.pop_front()
	cue_played.emit(cue,source,at)
func play_at(cue: String, at: Vector3, reach: float, source: String = "", db: float = -12.0) -> void:
	if get_tree().paused or voices.size()>=24 or listener.global_position.distance_to(at)>reach: return
	var player := _spatial(cue)
	player.global_position = at+Vector3(0,0.6,0)
	player.set_meta("reach",reach)
	player.set_meta("base_db",db)
	_mix(player)
	if listener.global_position.distance_to(player.global_position)>player.max_distance:
		voices.erase(player)
		player.queue_free()
		return
	player.play()
	_record(cue,source,at)
func _on_pulse(cue: String, at: Vector3, reach: float, source: String) -> void:
	update_listener()
	if world.get_node("Defense").decoys.get(source,false): cue = "sonar"
	play_at(cue,at,reach,source,-16 if cue=="sonar" else -12)
func _bind_sonar() -> void:
	for drone in world.get_node("Fleet").get_children():
		var callback := _sonar_returns.bind(drone)
		var sonar: Node = drone.get_node("Sonar")
		if not sonar.pinged.is_connected(callback): sonar.pinged.connect(callback)
func _sonar_returns(drone: Node) -> void:
	update_listener()
	if drone.identity!=remote_id: return
	var sonar: Node = drone.get_node("Sonar")
	var nearest := INF
	for echo in sonar.echoes: nearest = minf(nearest,drone.position.distance_to(echo))
	if is_finite(nearest): pending.append({"delay":0.15+nearest*2/343.0,"cue":"echo","id":drone.identity})
	# Contact tones only accompany an actual fresh line-of-sight sonar return.
	if not sonar.hostile_contacts.is_empty():
		var distance: float = drone.position.distance_to(sonar.hostile_contacts[0])
		pending.append({"delay":0.4+distance*2/343.0,"cue":"contact","id":drone.identity})
func _loop(id: String, cue: String, at: Vector3, reach: float, db: float, used: Dictionary) -> void:
	used[id] = true
	if not loops.has(id):
		loops[id] = _spatial(cue,"Effects",true)
		loops[id].play()
	var player: AudioStreamPlayer3D = loops[id]
	player.global_position = at+Vector3(0,0.6,0)
	player.set_meta("reach",reach)
	player.set_meta("base_db",db)
	_mix(player)
func _due(id: String, delta: float, period: float) -> bool:
	clocks[id] = clocks.get(id,0.0)-delta
	if clocks[id]>0: return false
	clocks[id] = period
	return true
func _local_cue(player: AudioStreamPlayer, cue: String, db: float) -> void:
	player.stream = Synth.stream(cue)
	player.volume_db = db
	player.play()
	_record(cue,"instrument",listener.global_position)
func _physics_process(delta: float) -> void: advance(delta)
func advance(delta: float) -> void:
	if get_tree().paused or delta<=0 or not is_finite(delta): return
	update_listener()
	_bind_sonar()
	var used := {}
	for drone in world.get_node("Fleet").get_children():
		var reach: float = emissions.sound_reach(drone)
		if reach>0: _loop(drone.identity,"motor",drone.position,reach,-18,used)
	var rail: Node = world.get_node("Rail")
	if rail.car_built and absf(rail.freight.coordinate-last_rail)>0.00001:
		_loop("rail_car","motor",rail.freight.position_at(rail.freight.coordinate),80,-15,used)
	last_rail = rail.freight.coordinate
	for id in loops.keys():
		if not used.has(id): loops[id].stop(); loops[id].queue_free(); loops.erase(id)
	var operator: Node = world.get_node("Operator")
	if operator.velocity.length()>0.1 and not operator.transport_locked and _due("boots",delta,0.55): play_at("step",operator.position,5,"operator",-19)
	for actor in world.get_node("Threats").actors.values():
		if actor.integrity>0 and actor.stun_remaining<=0 and actor.velocity.length()>0.1 and _due("claw_"+actor.identity,delta,0.5): play_at("claw",actor.position,22,actor.identity,-15)
	for player in voices:
		if is_instance_valid(player): _mix(player)
	for item in pending.duplicate():
		item.delay -= delta
		if item.delay>0: continue
		pending.erase(item)
		if item.id==remote_id: _local_cue(echo_voice,item.cue,-22+linear_to_db(maxf(link_gain,0.0001)))
	_update_instruments(delta)
	_update_ambience()
func _update_instruments(delta: float) -> void:
	var life: Node = world.get_node("LifeSupport")
	var human: Node = world.get_node("HumanSortie")
	if not life.dead and not human.dead and not life.warning().is_empty():
		var critical: bool = not life.critical_reason().is_empty()
		if _due("life_alarm",delta,0.8 if critical else 4): _local_cue(alarm_voice,"critical" if critical else "alarm",-19)
	else: clocks.erase("life_alarm")
	if human.active and not human.dead:
		if _due("breath",delta,2.5): _local_cue(breath_voice,"breath",-23)
		var low: float = minf(human.oxygen/human.Suit.OXYGEN_SECONDS,human.filter/human.Suit.FILTER_SECONDS)
		if low<0.2 and _due("suit_alarm",delta,0.75 if low<0.1 else 2.5): _local_cue(alarm_voice,"critical" if low<0.1 else "alarm",-16)
	else:
		breath_voice.stop()
		clocks.erase("breath")
		clocks.erase("suit_alarm")
func _update_ambience() -> void:
	var life: Node = world.get_node("LifeSupport")
	var supplied: float = life.supplied_fraction if life.oxygen_on and not life.dead else 0.0
	vent_voice.volume_db = -24+linear_to_db(maxf(supplied,0.0001))
	vent_voice.max_distance = 20
	if supplied>0 and not vent_voice.playing: vent_voice.play()
	elif supplied<=0: vent_voice.stop()
	var weather: String = world.get_node("Weather").current
	var cue := "rain" if weather=="rain" else "wind"
	var stream := Synth.stream(cue)
	if weather_voice.stream!=stream:
		weather_voice.stream = stream
		weather_voice.play()
	var at: Vector3 = world.get_node("Operator").global_position if remote_id.is_empty() else world.get_node("Fleet").drone(remote_id).global_position
	var indoors: bool = world.get_node("Breaches").indoors(at)
	weather_voice.volume_db = (-39.0 if indoors else -21.0)+(0.0 if weather in ["rain","ash"] else -7.0)+linear_to_db(maxf(link_gain,0.0001))
