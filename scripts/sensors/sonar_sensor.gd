extends Node

signal pinged
@export var range_m: float = 60.0
@export var cooldown: float = 2.0
@export var echo_lifetime: float = 8.0
var clock: float = 0.0
var last_ping: float = -100.0
var echoes: Array[Vector3] = []
var last_range: float = 60.0
var hostile_contacts: Array[Vector3] = []


func _physics_process(delta: float) -> void:
	clock += delta
	if clock - last_ping > echo_lifetime:
		echoes.clear()
		hostile_contacts.clear()


func ping() -> bool:
	var drone: CharacterBody3D = get_parent()
	if not drone.deployed or not drone.has_power() or drone.silent_running or drone.module_efficiency("sonar") <= 0.0 or clock - last_ping < cooldown:
		return false
	echoes.clear()
	hostile_contacts.clear()
	last_range = range_m * drone.module_efficiency("sonar")
	var origin := drone.global_position + Vector3(0,0.6,0)
	for index in range(72):
		var angle := float(index) / 72.0 * TAU
		var direction := Vector3(sin(angle),0,-cos(angle))
		var ray := PhysicsRayQueryParameters3D.create(origin,origin + direction * last_range,1,[drone.get_rid()])
		var hit: Dictionary = drone.get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty():
			echoes.append(hit.position)
	last_ping = clock
	# Only a fresh, line-of-sight acoustic signature; no world-wide threat lookup.
	for source in get_tree().get_nodes_in_group("hostile_pings"):
		var at: Vector3 = source.global_position + Vector3(0,0.6,0)
		if origin.distance_to(at) > minf(30.0,last_range):
			continue
		var query := PhysicsRayQueryParameters3D.create(origin,at,1,[drone.get_rid()])
		var hit: Dictionary = drone.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.collider == source:
			hostile_contacts.append(at)
	pinged.emit()
	return true
