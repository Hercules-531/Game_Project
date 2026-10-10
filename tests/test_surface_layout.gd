extends GutTest

const SCENE = preload("res://scenes/surface/approach.tscn")
const LAYOUT = preload("res://scripts/world/world_layout.gd")


func test_finite_northward_layout_and_route_clearance() -> void:
	var surface: Node3D = SCENE.instantiate()
	add_child_autofree(surface)
	await get_tree().physics_frame
	assert_true(LAYOUT.contains(Vector3(0,0,-50)))
	assert_false(LAYOUT.contains(Vector3(65,0,-50)))
	assert_eq(LAYOUT.band_at(Vector3(0,0,-50)),0)
	assert_eq(LAYOUT.band_at(surface.get_node("Substation").position),2)
	var space: PhysicsDirectSpaceState3D = surface.get_world_3d().direct_space_state
	var route := PhysicsRayQueryParameters3D.create(Vector3(0,0.6,-15),Vector3(0,0.6,-247),1)
	assert_true(space.intersect_ray(route).is_empty(),"Pylon spine has a physically clear travel lane")
	var edge := PhysicsRayQueryParameters3D.create(Vector3(0,1,-50),Vector3(70,1,-50),1)
	assert_false(space.intersect_ray(edge).is_empty(),"Map edge is physically bounded")
	for index in range(1,7):
		var a: Node3D = surface.get_node("Pylon%02d" % index)
		var b: Node3D = surface.get_node("Pylon%02d" % (index + 1))
		assert_almost_eq(a.position.distance_to(b.position),35.0,0.01)
		assert_false(a.powered)
