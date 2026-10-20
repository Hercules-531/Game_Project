extends RefCounted
const Kit = preload("res://scripts/world/surface_kit.gd")
const Policy = preload("res://scripts/render/material_policy.gd")
const Cargo = preload("res://Textures/PSX modular house interior pack/props/box.glb")
static func track(parent: Node3D, a: Vector3, b: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "Track"
	parent.add_child(root)
	root.position = (a+b)*0.5
	root.rotation.y = atan2(-(b-a).x,-(b-a).z)
	var length := a.distance_to(b)
	for x in [-0.6,0.6]: Kit.box(root,"Rail",Vector3(0.09,0.12,length),Vector3(x,0.14,0),"metal",false)
	for i in range(ceili(length/3.0)):
		Kit.box(root,"Sleeper",Vector3(1.8,0.08,0.25),Vector3(0,0.04,-length*0.5+i*3.0),"rock",false)
	Kit.box(root,"Conduit",Vector3(0.08,0.08,length),Vector3(1.65,0.3,0),"metal",false)
	return root
static func station(parent: Node3D, hub: int, at: Vector3, height: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Hub%d" % hub
	parent.add_child(root)
	root.position = at
	Kit.box(root,"Console",Vector3(0.38,0.9,0.6),Vector3(1.35,0.45,0),"metal",false)
	Kit.box(root,"DepotLocker",Vector3(0.5,1.15,1.4),Vector3(-1.35,0.575,0),"metal",false)
	Kit.box(root,"LampHousing",Vector3(0.75,0.06,0.2),Vector3(0,height-0.15,0),"metal",false)
	var label := Label3D.new()
	label.text = "14 / HOME" if hub==0 else "14 / DEPOT %d" % hub
	label.font_size = 32
	label.pixel_size = 0.009
	label.position = Vector3(0,height-0.4,0)
	label.modulate = Color(0.62,0.81,0.65)
	label.double_sided = true
	label.no_depth_test = false
	root.add_child(label)
	var light := OmniLight3D.new()
	light.name = "Light"
	light.position = Vector3(0,height-0.35,0)
	light.light_color = Color(0.72,0.85,0.69)
	light.omni_range = 9.0
	light.light_energy = 0
	root.add_child(light)
	return root
static func car(parent: Node3D, at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "FreightCar"
	parent.add_child(root)
	root.position = at+Vector3(0,0.15,0)
	Kit.box(root,"Chassis",Vector3(1.3,0.22,2.0),Vector3(0,0.4,0),"metal",false)
	for x in [-0.6,0.6]:
		for z in [-0.68,0.68]:
			var wheel := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.2
			mesh.bottom_radius = 0.2
			mesh.height = 0.13
			mesh.radial_segments = 6
			wheel.mesh = mesh
			wheel.material_override = Kit.material("metal")
			wheel.rotation.z = PI/2
			wheel.position = Vector3(x,0.25,z)
			root.add_child(wheel)
	var cargo := Cargo.instantiate()
	root.add_child(cargo)
	cargo.position = Vector3(0,0.51,0)
	cargo.scale = Vector3.ONE*0.6
	Policy.apply_tree(cargo)
	return root
