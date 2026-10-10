extends Node3D
## Angular organic silhouette using the verified PSX stone surface.
const Kit = preload("res://scripts/world/surface_kit.gd")

func _ready() -> void:
	var skin := Kit.material("rock")
	skin.set_shader_parameter("tint",Color(0.43,0.36,0.31))
	_blob("Torso",Vector3(0,0.92,0.05),Vector3(0.58,0.42,0.95),skin)
	_blob("BlindHead",Vector3(0,0.98,-0.52),Vector3(0.36,0.3,0.4),skin)
	for side in [-1.0,1.0]:
		for z in [-0.32,0.36]:
			var hip := Vector3(side * 0.23,0.87,z)
			var knee := Vector3(side * 0.52,0.42,z + 0.14)
			var foot := Vector3(side * 0.38,0.06,z - 0.17)
			_bone(hip,knee,0.1,skin)
			_bone(knee,foot,0.065,skin)
			_blob("Foot",foot,Vector3(0.18,0.09,0.25),skin)
	for z in [-0.1,0.18,0.44]:
		_bone(Vector3(0,1.05,z),Vector3(0,1.31,z + 0.08),0.055,skin)

func _blob(label: String, at: Vector3, size: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var volume := SphereMesh.new()
	volume.radial_segments = 6
	volume.rings = 2
	volume.radius = 0.5
	volume.height = 1.0
	mesh.mesh = volume
	mesh.position = at
	mesh.scale = size
	mesh.material_override = material
	add_child(mesh)

func _bone(start: Vector3, end: Vector3, radius: float, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	var volume := CylinderMesh.new()
	volume.radial_segments = 5
	volume.top_radius = radius * 0.65
	volume.bottom_radius = radius
	volume.height = start.distance_to(end)
	mesh.mesh = volume
	mesh.material_override = material
	mesh.position = (start + end) * 0.5
	mesh.quaternion = Quaternion(Vector3.UP,(end - start).normalized())
	add_child(mesh)
