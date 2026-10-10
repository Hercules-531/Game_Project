extends Node3D

const Kit = preload("res://scripts/world/surface_kit.gd")
var powered: bool = false


func _ready() -> void:
	Kit.box(self,"Footing",Vector3(1.6,0.35,1.6),Vector3(0,0.175,0),"rock")
	Kit.box(self,"Mast",Vector3(0.34,4.2,0.34),Vector3(0,2.45,0))
	Kit.box(self,"Crossarm",Vector3(2.7,0.18,0.2),Vector3(0,4.2,0))
	Kit.box(self,"DeadCapacitor",Vector3(0.55,0.85,0.5),Vector3(0,1.2,0.4))
	for x in [-1.1,1.1]:
		Kit.box(self,"Insulator",Vector3(0.2,0.35,0.25),Vector3(x,4.45,0),"crust",false)
	add_to_group("sensor_landmarks")
	set_meta("thermal",0.05)
