extends Node3D
## Authored PSX furnishing pass; collision shell dimensions stay authoritative.

const Policy = preload("res://scripts/render/material_policy.gd")
const PLASTER = preload("res://Textures/PSX modular house interior pack/geometry/wallPlaster_albedo.png")
const STONE = preload("res://Textures/PSX modular house interior pack/geometry/floorStone_albedo.png")
const CONCRETE = preload("res://Textures/PSX modular house interior pack/geometry/ceilingConcrete_albedo.png")
const METAL = preload("res://Textures/PSX modular house interior pack/geometry/cornerPillarMetal_albedo.png")
const PROPS = {
	"table": preload("res://Textures/PSX modular house interior pack/props/table.glb"),
	"tv": preload("res://Textures/PSX modular house interior pack/props/tv.glb"),
	"radio": preload("res://Textures/PSX modular house interior pack/props/radio.glb"),
	"chair": preload("res://Textures/PSX modular house interior pack/props/chair.glb"),
	"shelves": preload("res://Textures/PSX modular house interior pack/props/shelves.glb"),
	"box": preload("res://Textures/PSX modular house interior pack/props/box.glb"),
	"pallet": preload("res://Textures/PSX modular house interior pack/props/pallet.glb"),
	"cabinet": preload("res://Textures/PSX modular house interior pack/props/cabinetBig.glb"),
	"breaker": preload("res://Textures/PSX modular house interior pack/props/breakerBox.glb"),
	"switch": preload("res://Textures/PSX modular house interior pack/props/lightSwitch.glb"),
	"socket": preload("res://Textures/PSX modular house interior pack/props/powerSocket.glb"),
	"radiator": preload("res://Textures/PSX modular house interior pack/props/radiator.glb"),
	"light": preload("res://Textures/PSX modular house interior pack/props/ceilingLight.glb"),
}


func _ready() -> void:
	if RenderingServer.get_rendering_device() != null:
		_surface_pass()
	_furnish()


func _surface(color: Color, texture: Texture2D) -> ShaderMaterial:
	var material := Policy.make_surface(color, texture)
	material.set_shader_parameter("box_projection", true)
	return material


func _surface_pass() -> void:
	var wall := _surface(Color(0.63, 0.61, 0.49), PLASTER)
	var floor_material := _surface(Color(0.55, 0.58, 0.53), STONE)
	var ceiling := _surface(Color(0.42, 0.44, 0.4), CONCRETE)
	var painted := _surface(Color(0.22, 0.29, 0.25), PLASTER)
	var trim := _surface(Color(0.6, 0.64, 0.58), METAL)
	for child in get_children():
		if not child is StaticBody3D:
			continue
		var mesh := child.get_node("Mesh") as MeshInstance3D
		if "Floor" in child.name:
			mesh.material_override = floor_material
		elif "Ceiling" in child.name:
			mesh.material_override = ceiling
		elif child.name.begins_with("Wall"):
			mesh.material_override = wall
			var dimensions: Vector3 = mesh.mesh.size
			var lower_size := Vector3(dimensions.x + 0.012, 1.0, dimensions.z + 0.012)
			_box(child, "LowerPaint", Vector3(0,-0.89,0), lower_size, painted)
			_box(child, "Skirting", Vector3(0,-1.34,0),
				Vector3(dimensions.x + 0.025,0.12,dimensions.z + 0.025), trim)
		else:
			mesh.material_override = trim
	for side in ["InnerDoor", "OuterDoor"]:
		var door := get_node("Airlock/" + side)
		door.get_node("Mesh").material_override = _surface(Color(0.76,0.72,0.5), METAL)
		for x in [-0.7,0.7]:
			_box(door,"Rib",Vector3(x,0,0.095),Vector3(0.07,2.1,0.07),trim)
		_box(door,"Crossbar",Vector3(0,-0.35,0.1),Vector3(1.5,0.12,0.08),trim)
		_box(door,"Latch",Vector3(0.48,-0.02,0.16),Vector3(0.07,0.3,0.09),trim)


func _box(parent: Node, node_name: String, at: Vector3, dimensions: Vector3,
		material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.position = at
	var shape := BoxMesh.new()
	shape.size = dimensions
	mesh.mesh = shape
	mesh.material_override = material
	parent.add_child(mesh)
	return mesh


func _prop(kind: String, node_name: String, at: Vector3, yaw: float = 0.0,
		scale_factor: float = 1.0, collision: bool = true) -> Node3D:
	var prop: Node3D = PROPS[kind].instantiate()
	prop.name = node_name
	add_child(prop)
	prop.position = at
	prop.rotation_degrees.y = yaw
	prop.scale = Vector3.ONE * scale_factor
	if collision:
		var bounds := AABB()
		var first := true
		for mesh in prop.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = prop.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		var body := StaticBody3D.new()
		body.name = "PropCollision"
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = bounds.size
		collider.shape = shape
		collider.position = bounds.get_center()
		body.add_child(collider)
		prop.add_child(body)
	Policy.apply_tree(prop)
	if kind == "light" and RenderingServer.get_rendering_device() != null:
		for mesh in prop.find_children("*", "MeshInstance3D", true, false):
			for index in mesh.mesh.get_surface_count():
				mesh.get_active_material(index).set_shader_parameter("emission_strength", 0.65)
	return prop


func _sign(node_name: String, text: String, at: Vector3, yaw: float = 0.0) -> void:
	var label := Label3D.new()
	label.name = node_name
	label.text = text
	label.position = at
	label.rotation_degrees.y = yaw
	label.font_size = 48
	label.pixel_size = 0.0025
	label.modulate = Color(0.73,0.74,0.59)
	add_child(label)


func _furnish() -> void:
	_prop("table","CommandDeskLeft",Vector3(3.4,0,-1.1))
	_prop("table","CommandDeskRight",Vector3(5.1,0,-1.1))
	_prop("tv","CommandCRT",Vector3(3.2,0.721,-1.2))
	_prop("tv","TelemetryCRT",Vector3(3.95,0.721,-1.2))
	_prop("tv","MapCRT",Vector3(5.0,0.721,-1.2))
	_prop("radio","CommandRadio",Vector3(5.65,0.721,-0.95))
	_prop("chair","OperatorChair",Vector3(5.2,0,0.45),180)
	_prop("cabinet","CommandStorage",Vector3(6.7,0,2.7),-90)
	_prop("table","WorkshopBench",Vector3(-4.3,0,-1.0),0,1.35)
	_prop("radio","WorkshopMeter",Vector3(-4.8,0.974,-1.0))
	_prop("shelves","PartsShelves",Vector3(-6.85,0,1),90)
	_prop("pallet","CargoPallet",Vector3(-2.7,0,2.9))
	_prop("box","CargoA",Vector3(-2.9,0.175,2.8),20)
	_prop("box","CargoB",Vector3(-2.4,0.175,3.0),-10)
	_prop("box","PartsA",Vector3(-6.7,0.05,0.4),90)
	_prop("box","PartsB",Vector3(-6.7,0.05,1.6),90)
	_prop("cabinet","RationsCabinet",Vector3(2.1,0,9.5),180)
	_prop("breaker","LifeBreaker",Vector3(-3.18,1.4,8.3))
	_prop("breaker","PowerBreaker",Vector3(-3.18,1.4,7.5))
	_prop("radiator","LifeRadiator",Vector3(-3.06,0.1,9.25))
	_prop("radiator","CommandRadiator",Vector3(7.05,0.1,0.7),180)
	_prop("switch","CommandSwitch",Vector3(1.42,1.35,-0.25))
	_prop("switch","WorkshopSwitch",Vector3(-1.42,1.35,-0.25),180)
	_prop("socket","CommandSocket",Vector3(4.3,0.4,-1.89),-90)
	_prop("socket","WorkshopSocket",Vector3(-4.3,0.4,-1.89),-90)
	for point in [Vector3(0,2.79,3),Vector3(0,2.79,-3),Vector3(4.3,2.79,1),
		Vector3(-4.3,2.79,1),Vector3(0,2.79,8),Vector3(0,2.79,-8)]:
		_prop("light","CeilingFixture",point,0,1,false)
	_sign("OperationsTitle","14 / REMOTE OPERATIONS",Vector3(4.3,2.05,-1.895))
	_sign("WorkshopTitle","FABRICATION / REPAIR",Vector3(-4.3,2.05,-1.895))
	_sign("LifeTitle","O2 / HEAT / POWER",Vector3(-3.19,2.1,8.1),90)
	if RenderingServer.get_rendering_device() != null:
		var pipe_material := _surface(Color(0.65,0.65,0.57), METAL)
		for x in [-1.0,1.0]:
			_box(self,"ServiceConduit",Vector3(x,2.61,0),Vector3(0.065,0.065,11.9),pipe_material)
		for z in [-4.8,-2.8,-0.8,1.2,3.2,5.2]:
			_box(self,"ConduitSupport",Vector3(0,2.68,z),Vector3(2.35,0.035,0.04),pipe_material)
