extends Node3D
const Kit = preload("res://scripts/world/surface_kit.gd")
func _ready() -> void:
	var skin := Kit.material("rock")
	skin.set_shader_parameter("tint",Color(0.36,0.27,0.22))
	for at in [Vector3(-0.8,0.35,0.4),Vector3(0.65,0.45,0.2),Vector3(0,0.6,-0.7)]:
		var blob := MeshInstance3D.new()
		var volume := SphereMesh.new()
		volume.radial_segments = 7
		volume.rings = 3
		volume.radius = 1.0
		volume.height = 1.6
		blob.mesh = volume
		blob.position = at
		blob.material_override = skin
		add_child(blob)
	for x in [-0.65,0.65]:
		var rib := Kit.box(self,"MouthRib",Vector3(0.18,1.0,0.22),Vector3(x,0.5,1.08),"rock",false)
		rib.rotation.z = x * 0.45
		(rib.get_child(0) as MeshInstance3D).material_override = skin
