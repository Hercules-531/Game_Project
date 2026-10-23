extends Node3D
const Kit = preload("res://scripts/world/surface_kit.gd")
const BALANCE = preload("res://resources/balance/excavation.tres")
var cells: Dictionary = {}
static func add_quad(vertices: PackedVector3Array, normals: PackedVector3Array, points: Array, normal: Vector3) -> void:
	for i in [0,2,1,0,3,2]:
		vertices.append(points[i])
		normals.append(normal)
func rebuild(data: Dictionary, roof_holes: Dictionary = {}, portal_cells: Dictionary = {}) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	cells = data.duplicate()
	var vertices := [PackedVector3Array(),PackedVector3Array(),PackedVector3Array()]
	var normals := [PackedVector3Array(),PackedVector3Array(),PackedVector3Array()]
	var y: float = BALANCE.floor_y
	for cell in cells:
		if portal_cells.has(cell): continue
		var x: float = cell.x
		var z: float = cell.y
		var top: float = y+cells[cell]
		add_quad(vertices[0],normals[0],[Vector3(x,y,z),Vector3(x,y,z+1),Vector3(x+1,y,z+1),Vector3(x+1,y,z)],Vector3.UP)
		if not roof_holes.has(cell): add_quad(vertices[1],normals[1],[Vector3(x,top,z),Vector3(x+1,top,z),Vector3(x+1,top,z+1),Vector3(x,top,z+1)],Vector3.DOWN)
		var neighbors := [cell+Vector2i(-1,0),cell+Vector2i(1,0),cell+Vector2i(0,-1),cell+Vector2i(0,1)]
		for side in 4:
			if portal_cells.has(neighbors[side]): continue
			var low: float = y+float(cells.get(neighbors[side],0.0))
			if low>=top-0.000001: continue
			var points: Array
			var normal: Vector3
			match side:
				0:
					points = [Vector3(x,low,z+1),Vector3(x,low,z),Vector3(x,top,z),Vector3(x,top,z+1)]
					normal = Vector3.RIGHT
				1:
					points = [Vector3(x+1,low,z),Vector3(x+1,low,z+1),Vector3(x+1,top,z+1),Vector3(x+1,top,z)]
					normal = Vector3.LEFT
				2:
					points = [Vector3(x,low,z),Vector3(x+1,low,z),Vector3(x+1,top,z),Vector3(x,top,z)]
					normal = Vector3.BACK
				_:
					points = [Vector3(x+1,low,z+1),Vector3(x,low,z+1),Vector3(x,top,z+1),Vector3(x+1,top,z+1)]
					normal = Vector3.FORWARD
			add_quad(vertices[2],normals[2],points,normal)
	for index in 3:
		if vertices[index].is_empty(): continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices[index]
		arrays[Mesh.ARRAY_NORMAL] = normals[index]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var body := StaticBody3D.new()
		body.name = ["Floor","Roof","Walls"][index]
		add_child(body)
		var view := MeshInstance3D.new()
		view.mesh = mesh
		view.material_override = Kit.material(["rock","metal","crust"][index])
		body.add_child(view)
		var collision := CollisionShape3D.new()
		collision.shape = mesh.create_trimesh_shape()
		body.add_child(collision)
