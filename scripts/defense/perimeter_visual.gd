extends Node3D
const Kit = preload("res://scripts/world/surface_kit.gd")
const SIZES = [Vector3(20,1.5,0.16),Vector3(0.16,1.5,16),Vector3(0.16,1.5,16),Vector3(7.75,1.5,0.16),Vector3(7.75,1.5,0.16)]
const OFFSETS = [Vector3(0,0.75,-8),Vector3(-10,0.75,0),Vector3(10,0.75,0),Vector3(-6.125,0.75,8),Vector3(6.125,0.75,8)]
func _ready() -> void:
	for i in 5:
		var body := StaticBody3D.new()
		body.name = "Section%d" % i
		body.position = OFFSETS[i]
		add_child(body)
		var shape := BoxShape3D.new()
		shape.size = SIZES[i]
		var collision := CollisionShape3D.new()
		collision.name = "Collision"
		collision.shape = shape
		body.add_child(collision)
		var rail_size: Vector3 = SIZES[i]
		rail_size.y = 0.1
		for y in [-0.55,0.0,0.55]: Kit.box(body,"FenceRail",rail_size,Vector3(0,y,0),"metal",false)
		var along_x: bool = SIZES[i].x > SIZES[i].z
		var length: float = SIZES[i].x if along_x else SIZES[i].z
		var count := ceili(length/2)
		for j in range(count+1):
			var offset: float = -length/2 + length*j/count
			Kit.box(body,"FencePost",Vector3(0.12,1.7,0.12),Vector3(offset,0,0) if along_x else Vector3(0,0,offset),"metal",false)
