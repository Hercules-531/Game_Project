extends Node3D
const MUTANT = preload("res://scenes/threats/mutant.tscn")
const Model = preload("res://scripts/threats/mutant_controller.gd")
const Kit = preload("res://scripts/world/surface_kit.gd")
var actors: Dictionary = {}

func _ready() -> void:
	var surface: Node3D = get_parent().get_node("Surface")
	Kit.box(surface,"PatrolShelter",Vector3(5,0.25,4),Vector3(43,2.6,-114),"rock")
	for x in [41.0,45.0]:
		Kit.box(surface,"ShelterPost",Vector3(0.3,2.5,0.3),Vector3(x,1.25,-115.6),"rock")
	spawn("approach_scout",Vector3(42,0.02,-112),Vector3(43,0.02,-114))

func spawn(id: String, at: Vector3, cover: Vector3) -> Node:
	if actors.has(id) or actors.size() >= 96: return null
	var actor := MUTANT.instantiate()
	actor.identity = id
	actor.name = id
	actor.position = at
	actor.home = at
	actor.shelter = cover
	add_child(actor)
	actors[id] = actor
	return actor

func snapshot() -> Array:
	var result := []
	for actor in actors.values(): result.append(actor.snapshot())
	return result

static func validate(data: Variant) -> bool:
	if not data is Array or data.size() > 96: return false
	var seen := {}
	for record in data:
		if not Model.validate(record) or seen.has(record.id): return false
		seen[record.id] = true
	return true

func restore(data: Array) -> void:
	assert(validate(data))
	for actor in actors.values():
		remove_child(actor)
		actor.queue_free()
	actors.clear()
	for record in data:
		var at := Vector3(record.at[0],record.at[1],record.at[2])
		var cover := Vector3(record.shelter[0],record.shelter[1],record.shelter[2])
		spawn(record.id,at,cover).restore(record)
