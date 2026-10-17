extends Node3D

const Kit = preload("res://scripts/world/surface_kit.gd")


func _ready() -> void:
	Kit.box(self,"Foundation",Vector3(22,0.2,18),Vector3(0,-0.02,0),"rock")
	# A broken front wall leaves an actual six-metre entrance.
	for x in [-8.0,8.0]:
		Kit.box(self,"FrontWall",Vector3(6,2.8,0.35),Vector3(x,1.4,9),"rock")
	Kit.box(self,"BackWall",Vector3(22,2.8,0.35),Vector3(0,1.4,-9),"rock")
	for x in [-11.0,11.0]:
		Kit.box(self,"SideWall",Vector3(0.35,2.8,18),Vector3(x,1.4,0),"rock")
	for x in [-5.0,5.0]:
		Kit.box(self,"Transformer",Vector3(2.8,2.1,3.6),Vector3(x,1.15,-3))
		for rib in range(5):
			Kit.box(self,"CoolingRib",Vector3(3.1,1.9,0.08),Vector3(x,1.15,-4.4 + rib * 0.7))
	Kit.box(self,"Switchgear",Vector3(2.2,1.8,0.7),Vector3(0,0.95,-7.4))
	add_to_group("sensor_landmarks")
	set_meta("classification","Pre-collapse substation")
	set_meta("thermal",0.08)
