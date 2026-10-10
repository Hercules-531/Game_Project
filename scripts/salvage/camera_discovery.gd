extends Node3D

const Kit = preload("res://scripts/world/surface_kit.gd")
var state: String = "available"
var carrier_id: String = ""
var case_body: StaticBody3D
@onready var fleet: Node3D = get_parent().get_node("Fleet")
@onready var inventory: Node = get_parent().get_node("Inventory")


func _ready() -> void:
	case_body = Kit.box(self,"SalvageCase",Vector3(0.8,0.45,0.65),Vector3(0,0.3,0))
	Kit.box(self,"LensHousing",Vector3(0.25,0.2,0.25),Vector3(0,0.63,0),"metal",false)
	add_to_group("sensor_landmarks")
	set_meta("thermal",0.05)


func recover(drone: Node) -> bool:
	if state != "available" or drone == null or not drone.deployed or drone.global_position.distance_to(global_position) > 3.0:
		return false
	if drone.module_efficiency("winch") <= 0.0 and drone.module_efficiency("cargo_rack") <= 0.0:
		return false
	if drone.payload_remaining() < 4.0:
		return false
	state = "carried"
	carrier_id = drone.identity
	drone.cargo_kg += 4.0
	case_body.collision_layer = 0
	return true


func _physics_process(_delta: float) -> void:
	if state != "carried":
		return
	var drone: Node3D = fleet.drone(carrier_id)
	if drone == null:
		return
	global_position = drone.global_position + drone.global_basis * Vector3(0,0,1.35)
	if not drone.deployed:
		state = "delivered"
		carrier_id = ""
		drone.cargo_kg -= 4.0
		hide()
		inventory.add_part("ccd",65.0)


func snapshot() -> Dictionary:
	return {"state":state,"owner":carrier_id}


static func validate(data: Variant) -> bool:
	return data is Dictionary and data.get("state") in ["available","carried","delivered"] and data.get("owner") is String and ((data.state == "carried") == (not data.owner.is_empty()))


func restore(data: Dictionary) -> void:
	assert(validate(data))
	state = data.state
	carrier_id = data.owner
	visible = state != "delivered"
	case_body.collision_layer = 1 if state == "available" else 0
