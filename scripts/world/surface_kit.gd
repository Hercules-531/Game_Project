extends RefCounted
## Authored low-poly forms; no generated or external bitmap assets.

const Policy = preload("res://scripts/render/material_policy.gd")
const CRUST = preload("res://Textures/PSX modular house interior pack/geometry/capRoofConcrete_albedo.png")
const METAL = preload("res://Textures/PSX modular house interior pack/geometry/cornerPillarMetal_albedo.png")
const STONE = preload("res://Textures/PSX modular house interior pack/geometry/floorStone_albedo.png")


static func material(kind: String) -> ShaderMaterial:
	var texture: Texture2D = CRUST if kind == "crust" else (STONE if kind == "rock" else METAL)
	var color := Color(0.7,0.78,0.83) if kind == "crust" else (Color(0.32,0.39,0.43) if kind == "rock" else Color(0.48,0.54,0.49))
	var result := Policy.make_surface(color,texture)
	result.set_shader_parameter("box_projection",true)
	return result


static func box(parent: Node3D, label: String, size: Vector3, at: Vector3, kind: String = "metal", solid: bool = true) -> Node3D:
	var node: Node3D = StaticBody3D.new() if solid else Node3D.new()
	node.name = label
	node.position = at
	parent.add_child(node)
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material(kind)
	node.add_child(mesh)
	if solid:
		var collision := CollisionShape3D.new()
		var volume := BoxShape3D.new()
		volume.size = size
		collision.shape = volume
		node.add_child(collision)
	return node
