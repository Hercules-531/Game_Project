extends Node3D
const DATA = preload("res://resources/world/campaign.tres")
const Kit = preload("res://scripts/world/surface_kit.gd")
func _ready() -> void:
	assert(DATA.valid())
	for band in DATA.bands:
		var region := Node3D.new()
		region.name = "Band%02d" % (band.index+1)
		add_child(region)
		for i in band.shelters.size():
			var at: Vector3 = band.shelters[i]
			var roof := Kit.box(region,"Shelter%d" % i,Vector3(6,0.24,5),at+Vector3(0,2.7,0),"rock")
			roof.add_to_group("sensor_landmarks")
			roof.set_meta("classification","Collapsed service shelter")
			roof.set_meta("thermal",0.02)
			for x in [-2.8,2.8]: Kit.box(region,"Pier",Vector3(0.35,2.6,0.35),at+Vector3(x,1.3,2.2),"metal")
			Kit.box(region,"BackWall",Vector3(6,2.6,0.22),at+Vector3(0,1.3,-2.4),"crust")
