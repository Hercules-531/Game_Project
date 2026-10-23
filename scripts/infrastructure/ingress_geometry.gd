extends Node3D
const Layout = preload("res://scripts/infrastructure/ingress_layout.gd")
const Kit = preload("res://scripts/world/surface_kit.gd")
const Quad = preload("res://scripts/excavation/excavation_geometry.gd")
var layout: Dictionary
var join_heights: Array = [2.6,2.6]
var gate: StaticBody3D
var lamp: OmniLight3D
func _mesh(label: String, points: Array, normal: Vector3, kind: String) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	Quad.add_quad(vertices,normals,points,normal)
	var outer: Array = []
	var solid := PackedVector3Array()
	for point in points:
		outer.append(point-normal*0.12)
		solid.append(point)
		solid.append(point-normal*0.12)
	var reverse: Array = outer.duplicate()
	reverse.reverse()
	Quad.add_quad(vertices,normals,reverse,-normal)
	for i in 4:
		var next := (i+1)%4
		var edge: Vector3 = points[next]-points[i]
		Quad.add_quad(vertices,normals,[points[i],points[next],outer[next],outer[i]],(-normal).cross(edge).normalized())
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var body := StaticBody3D.new()
	body.name = label
	add_child(body)
	body.set_meta("lining_foundation",true)
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = Kit.material(kind)
	body.add_child(view)
	var collision := CollisionShape3D.new()
	var volume := ConvexPolygonShape3D.new()
	volume.points = solid
	collision.shape = volume
	body.add_child(collision)
func _run(label: String, z: float, y_start: float, y_end: float) -> void:
	var a: float = layout.start
	var b := a+9
	_mesh(label+"Floor",[Vector3(a,y_start,z-1),Vector3(a,y_start,z+1),Vector3(b,y_end,z+1),Vector3(b,y_end,z-1)],Vector3(-(y_end-y_start)/9.0,1,0).normalized(),"rock")
	_mesh(label+"Roof",[Vector3(a,y_start+2.6,z-1),Vector3(b,y_end+2.6,z-1),Vector3(b,y_end+2.6,z+1),Vector3(a,y_start+2.6,z+1)],Vector3((y_end-y_start)/9.0,-1,0).normalized(),"metal")
	_mesh(label+"North",[Vector3(a,-6,z-1),Vector3(b,-6,z-1),Vector3(b,y_end+2.6,z-1),Vector3(a,y_start+2.6,z-1)],Vector3.BACK,"crust")
	_mesh(label+"South",[Vector3(b,-6,z+1),Vector3(a,-6,z+1),Vector3(a,y_start+2.6,z+1),Vector3(b,y_end+2.6,z+1)],Vector3.FORWARD,"crust")
func _ready() -> void:
	_run("Lower",layout.row,-6,-3)
	_run("Upper",layout.row+3,0,-3)
	var a: float = layout.start+9
	var b := a+2
	var low: float = layout.row-1
	var high := low+5
	_mesh("LandingFloor",[Vector3(a,-3,low),Vector3(a,-3,high),Vector3(b,-3,high),Vector3(b,-3,low)],Vector3.UP,"rock")
	_mesh("LandingRoof",[Vector3(a,-0.4,low),Vector3(b,-0.4,low),Vector3(b,-0.4,high),Vector3(a,-0.4,high)],Vector3.DOWN,"metal")
	_mesh("LandingEast",[Vector3(b,-6,low),Vector3(b,-6,high),Vector3(b,-0.4,high),Vector3(b,-0.4,low)],Vector3.LEFT,"crust")
	for z in [low,high]: Kit.box(self,"LandingSide",Vector3(2,5.6,0.12),Vector3(a+1,-3.2,z),"crust")
	Kit.box(self,"TurnPartition",Vector3(0.12,5.6,1),Vector3(a,-3.2,layout.row+1.5),"crust")
	for i in 2:
		if absf(join_heights[i]-2.6)>0.0001: Kit.box(self,"RoofJoin",Vector3(0.08,absf(join_heights[i]-2.6),1),Vector3(layout.start,-6+(join_heights[i]+2.6)*0.5,layout.row-0.5+i),"metal")
	var floor := Layout.gate_floor(layout)
	gate = Kit.box(self,"Seal",Vector3(0.16,2.6,1.8),floor+Vector3(0,1.3,0),"metal")
	for z in [-0.98,0.98]: Kit.box(self,"Frame",Vector3(0.25,2.7,0.15),floor+Vector3(0,1.35,z),"metal")
	Kit.box(self,"FrameTop",Vector3(0.25,0.12,2.1),floor+Vector3(0,2.65,0),"metal")
	var sign := Label3D.new()
	sign.text = "RAIL MOUTH" if layout.kind=="mouth" else "SERVICE CHASE / LINING"
	sign.position = floor+Vector3(-0.16,2.2,0)
	sign.rotation.y = -PI/2
	sign.font_size = 24
	sign.pixel_size = 0.004
	sign.double_sided = true
	add_child(sign)
	lamp = OmniLight3D.new()
	lamp.name = "Lamp"
	lamp.position = Vector3(layout.start+10,-0.7,layout.row+1.5)
	lamp.light_color = Color(0.7,0.82,0.68)
	lamp.omni_range = 14
	lamp.light_energy = 0
	add_child(lamp)
func apply_state(record: Dictionary) -> void:
	gate.get_child(1).disabled = record.forced
	gate.get_child(0).visible = not record.forced
	var old: Node = gate.get_node_or_null("Plating")
	if old!=null: gate.remove_child(old); old.queue_free()
	var plates := Node3D.new()
	plates.name = "Plating"
	gate.add_child(plates)
	for i in int(record.tier): Kit.box(plates,"Plate",Vector3(0.06,0.25,1.75),Vector3(-0.13,-0.7+i*0.65,0),"metal",false)
	plates.visible = not record.forced
