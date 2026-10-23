extends Node3D

const LAYOUT = preload("res://resources/world/approach.tres")
const Kit = preload("res://scripts/world/surface_kit.gd")
const PYLON = preload("res://scenes/surface/pylon.tscn")
const SUBSTATION = preload("res://scenes/surface/substation.tscn")
var ground_patches: Node3D


func _ready() -> void:
	var ground := Kit.box(self,"FrozenGround",Vector3(120,0.4,600),Vector3(0,-0.2,-310),"crust")
	ground.get_child(0).material_override.set_shader_parameter("uv_scale",Vector2(0.08,0.08))
	for x in [-61.0,61.0]:
		Kit.box(self,"BoundaryRidge",Vector3(2,14,600),Vector3(x,7,-310),"rock")
	Kit.box(self,"NorthBoundary",Vector3(124,14,2),Vector3(0,7,-611),"rock")
	for x in [-33.0,33.0]:
		Kit.box(self,"SouthBoundary",Vector3(54,8,2),Vector3(x,4,-10),"rock")
	for index in LAYOUT.pylons.size():
		var pylon := PYLON.instantiate()
		pylon.name = "Pylon%02d" % (index + 1)
		pylon.position = LAYOUT.pylons[index]
		add_child(pylon)
	var station := SUBSTATION.instantiate()
	station.name = "Substation"
	station.position = LAYOUT.substation
	add_child(station)
	# Hand-authored rubble funnels; the centre pylon route stays traversable.
	var rubble := [Vector3(-18,0,-42),Vector3(15,0,-59),Vector3(-21,0,-86),
		Vector3(22,0,-115),Vector3(-17,0,-157),Vector3(26,0,-193)]
	for index in rubble.size():
		var rock := Kit.box(self,"Rubble%02d" % index,Vector3(8,2.5 + index * 0.25,5),rubble[index] + Vector3(0,1.25,0),"rock")
		rock.rotation.y = index * 0.36
		rock.add_to_group("sensor_landmarks")
		rock.set_meta("thermal",0.02)
		rock.set_meta("classification","Rubble")
	var vent := Kit.box(self,"WarmVent",Vector3(1.8,0.35,1.8),Vector3(9,0.175,-48))
	vent.add_to_group("sensor_landmarks")
	vent.set_meta("thermal",0.8)
	vent.set_meta("classification","Thermal vent")
	var sun := DirectionalLight3D.new()
	sun.name = "SurfaceSun"
	sun.rotation_degrees = Vector3(-35,-25,0)
	sun.light_color = Color(0.66,0.77,0.89)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	add_child(sun)


static func band_at(at: Vector3) -> int:
	return clampi(int(floor((-at.z - 10.0) / LAYOUT.band_depth)),0,5)

func apply_ground_holes(holes: Array[Rect2]) -> void:
	if ground_patches!=null:
		remove_child(ground_patches)
		ground_patches.queue_free()
		ground_patches = null
	var original: Node3D = get_node("FrozenGround")
	original.visible = holes.is_empty()
	original.get_child(1).disabled = not holes.is_empty()
	if holes.is_empty(): return
	var xs: Array = [-60.0,60.0]
	var zs: Array = [-610.0,-10.0]
	for hole in holes:
		for value in [hole.position.x,hole.end.x]:
			if not xs.has(value): xs.append(value)
		for value in [hole.position.y,hole.end.y]:
			if not zs.has(value): zs.append(value)
	xs.sort()
	zs.sort()
	ground_patches = Node3D.new()
	ground_patches.name = "SurfaceSlab"
	add_child(ground_patches)
	for x in xs.size()-1:
		for z in zs.size()-1:
			var middle := Vector2((xs[x]+xs[x+1])*0.5,(zs[z]+zs[z+1])*0.5)
			var cut := false
			for hole in holes:
				if hole.has_point(middle): cut = true; break
			if cut: continue
			var patch := Kit.box(ground_patches,"Slab",Vector3(xs[x+1]-xs[x],0.4,zs[z+1]-zs[z]),Vector3(middle.x,-0.2,middle.y),"crust")
			patch.get_child(0).material_override = original.get_child(0).material_override


static func contains(at: Vector3) -> bool:
	return LAYOUT.bounds.has_point(Vector2(at.x,at.z))
