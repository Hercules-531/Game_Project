extends Node3D

const BOX = preload("res://Textures/PSX modular house interior pack/props/box.glb")
const Policy = preload("res://scripts/render/material_policy.gd")
var definition: Dictionary
var state: String = "available"
var carrier_id: String = ""
var body: StaticBody3D

func _ready() -> void:
	var visual: Node3D = BOX.instantiate()
	visual.scale = Vector3.ONE * 1.8
	add_child(visual)
	Policy.apply_tree(visual)
	body = StaticBody3D.new()
	add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.8,0.6,0.7)
	collision.shape = shape
	collision.position.y = 0.3
	body.add_child(collision)
	add_to_group("sensor_landmarks")
	set_meta("thermal",0.05)
	set_meta("classification",{"scrap":"Scrap cache","fuel":"Fuel container","rations":"Ration crate"}.get(definition.kind,"Salvage container"))
	if definition.get("buried",false):
		state = "buried"
	apply_state()

func apply_state() -> void:
	visible = state not in ["delivered","buried"]
	body.collision_layer = 1 if state == "available" else 0

func snapshot() -> Dictionary:
	return {"id":definition.id,"state":state,"carrier":carrier_id}
