extends Node3D
const Kit = preload("res://scripts/world/surface_kit.gd")
@export_enum("pylon", "fob", "cargo") var kind := "pylon"
func _ready() -> void:
	if kind == "cargo":
		Kit.box(self,"PackedStructure",Vector3(2.4,1.1,2.0),Vector3(0,0.55,0),"metal",false)
		for x in [-0.95,0.95]: Kit.box(self,"PackingBand",Vector3(0.12,1.15,2.05),Vector3(x,0.55,0),"rock",false)
		return
	Kit.box(self,"Bank",Vector3(1.4,1.8,1.2),Vector3(0,0.9,0))
	Kit.box(self,"Mast",Vector3(0.22,4.2,0.22),Vector3(0,3.9,0))
	for z in [-0.55,0.55]: Kit.box(self,"Antenna",Vector3(1.6,0.13,0.13),Vector3(0,5.4,z),"metal",false)
	if kind == "fob":
		Kit.box(self,"DepotRoof",Vector3(7,0.3,6),Vector3(5,3.0,0),"crust")
		Kit.box(self,"DepotRear",Vector3(7,3,0.3),Vector3(5,1.5,-3),"crust")
		for x in [1.5,8.5]: Kit.box(self,"DepotPost",Vector3(0.3,3,0.3),Vector3(x,1.5,2.5))
		Kit.box(self,"Storage",Vector3(2.2,1.0,1.2),Vector3(5,0.5,-1.8))
