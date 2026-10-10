extends Node

signal pinged
@export var range_m: float = 60.0
@export var cooldown: float = 2.0
@export var echo_lifetime: float = 8.0
var clock: float = 0.0
var last_ping: float = -100.0
var echoes: Array[Vector3] = []


func _physics_process(delta: float) -> void:
	clock += delta
	if clock - last_ping > echo_lifetime:
		echoes.clear()


func ping() -> bool:
	var drone: CharacterBody3D = get_parent()
	if not drone.deployed or not "sonar" in drone.modules.values() or clock - last_ping < cooldown:
		return false
	echoes.clear()
	var origin := drone.global_position + Vector3(0,0.6,0)
	for index in range(72):
		var angle := float(index) / 72.0 * TAU
		var direction := Vector3(sin(angle),0,-cos(angle))
		var ray := PhysicsRayQueryParameters3D.create(origin,origin + direction * range_m,1,[drone.get_rid()])
		var hit: Dictionary = drone.get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty():
			echoes.append(hit.position)
	last_ping = clock
	pinged.emit()
	return true
