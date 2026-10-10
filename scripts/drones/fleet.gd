extends Node3D

const DRONE = preload("res://scenes/drones/drone.tscn")
const MODEL = preload("res://scripts/drones/drone.gd")
const CATALOG = preload("res://resources/drones/opening_fleet.tres")


func _ready() -> void:
	create_opening()


func create_opening() -> void:
	_clear()
	for index in CATALOG.opening.size():
		var record: Dictionary = CATALOG.opening[index]
		var drone := DRONE.instantiate()
		drone.identity = record.id
		drone.name = record.id
		drone.hull_id = record.hull
		drone.battery = drone.hull().battery_kwh
		for socket in record.modules:
			assert(drone.install(socket,record.modules[socket]))
		drone.position = Vector3(-5.95,0.02,3.0) if index == 0 else Vector3(-4.1,0.02,2.8)
		add_child(drone)


func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()


func drone(id: String) -> Node:
	for machine in get_children():
		if machine.identity == id:
			return machine
	return null


func snapshot() -> Array:
	var data := []
	for machine in get_children():
		data.append(machine.snapshot())
	return data


static func validate(data: Variant) -> bool:
	if not data is Array or data.size() > 32:
		return false
	var ids := {}
	for record in data:
		if not MODEL.validate(record) or ids.has(record.id):
			return false
		ids[record.id] = true
	return true


func restore(data: Array) -> void:
	assert(validate(data))
	_clear()
	for record in data:
		var machine := DRONE.instantiate()
		machine.restore(record)
		machine.name = record.id
		add_child(machine)
