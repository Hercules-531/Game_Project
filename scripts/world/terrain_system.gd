extends Node3D
const MUD := Rect2(-28,-69,8,12)
const Kit = preload("res://scripts/world/surface_kit.gd")

func _ready() -> void:
	var mud: Node3D = Kit.box(self,"DeepSludge",Vector3(8,0.025,12),Vector3(-24,0.018,-63),"crust",false)
	mud.get_child(0).get_active_material(0).set_shader_parameter("tint",Color(0.18,0.23,0.18))
	var ramp: Node3D = Kit.ramp(self,"Incline",7.0,7.0,7.0 * tan(deg_to_rad(30.0)),Vector3(24,0,-74))
	ramp.add_to_group("sensor_landmarks")
	ramp.set_meta("thermal",0.02)
	for x in [1.8,6.2]:
		for z in [-18,-22]:
			Kit.box(self,"GantryPost",Vector3(0.12,3.2,0.12),Vector3(x,1.6,z),"metal",false)
	for z in [-18,-22]:
		Kit.box(self,"GantryBeam",Vector3(4.5,0.14,0.14),Vector3(4,3.2,z),"metal",false)

func factor(drone: Node) -> float:
	if drone.deployed and drone.hull_id == "tracked" and MUD.has_point(Vector2(drone.position.x,drone.position.z)):
		return 0.85 if drone.module_efficiency("tread_scraper") > 0.0 else 0.2
	return 1.0
