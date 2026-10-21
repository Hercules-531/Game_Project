extends Node3D
const Kit = preload("res://scripts/world/surface_kit.gd")
func _ready() -> void:
	Kit.box(self,"Seat",Vector3(0.75,0.12,0.65),Vector3(0,0.62,0.35),"metal",false)
	Kit.box(self,"SeatBack",Vector3(0.75,0.55,0.1),Vector3(0,0.95,0.68),"metal",false)
	for x in [-0.5,0.5]: Kit.box(self,"GrabRail",Vector3(0.055,0.65,1.0),Vector3(x,0.9,0.05),"metal",false)
	Kit.box(self,"CarCollision",Vector3(1.3,0.45,2.0),Vector3(0,0.28,0),"metal")
	Kit.box(self,"LampHousing",Vector3(0.25,0.2,0.2),Vector3(0,1.1,-0.95),"metal",false)
	Kit.box(self,"RearLampHousing",Vector3(0.25,0.2,0.2),Vector3(0,1.1,0.95),"metal",false)
	var lamp := SpotLight3D.new()
	lamp.name = "Headlamp"
	lamp.position = Vector3(0,1.1,-1.08)
	lamp.rotation.x = deg_to_rad(-10)
	lamp.spot_range = 22
	lamp.spot_angle = 42
	lamp.light_color = Color(0.78,0.86,0.72)
	lamp.light_energy = 0
	lamp.shadow_enabled = true
	add_child(lamp)
