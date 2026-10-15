extends Node3D
const Kit = preload("res://scripts/world/surface_kit.gd")
const Policy = preload("res://scripts/render/material_policy.gd")
@export var kind := "thermal"
func _ready() -> void:
	Kit.box(self,"UniversalPlug",Vector3(0.3,0.12,0.3),Vector3(0,0.08,0),"metal",false)
	var view := MeshInstance3D.new()
	view.name = "Anomaly"
	var shape := PrismMesh.new()
	shape.size = Vector3(0.3,0.38,0.3)
	view.mesh = shape
	view.position.y = 0.32
	var tint := Color(0.78,0.38,0.18) if kind=="thermal" else (Color(0.32,0.7,0.75) if kind=="neural" else Color(0.75,0.72,0.38))
	view.material_override = Policy.make_surface(tint,Kit.STONE,Vector2.ONE,0.35)
	add_child(view)
	for x in [-0.2,0.2]:
		Kit.box(self,"CageRail",Vector3(0.04,0.45,0.3),Vector3(x,0.3,0),"metal",false)
