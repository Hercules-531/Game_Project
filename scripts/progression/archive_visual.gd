extends Node3D
const Kit = preload("res://scripts/world/surface_kit.gd")
const Policy = preload("res://scripts/render/material_policy.gd")
const BOOK = preload("res://Textures/PSX modular house interior pack/props/book.glb")
const COVER = preload("res://Textures/PSX modular house interior pack/props/book_albedo.png")
func _ready() -> void:
	Kit.box(self,"DataCrate",Vector3(0.65,0.35,0.5),Vector3(0,0.175,0),"metal",false)
	var book: Node3D = BOOK.instantiate()
	book.name = "RecoveredManual"
	book.position = Vector3(0,0.36,0)
	book.scale = Vector3.ONE * 3.0
	add_child(book)
	for mesh in book.find_children("*","MeshInstance3D",true,false):
		mesh.material_override = Policy.make_surface(Color(0.85,0.85,0.8),COVER)
