extends Node
## Heat only: no material, object identity or ordinary camera image is returned.

@export var range_m: float = 35.0


func sample() -> Array:
	var drone: CharacterBody3D = get_parent()
	var readings := []
	if not drone.deployed or drone.battery <= 0.0 or not "thermal" in drone.modules.values():
		return readings
	var origin := drone.global_position + Vector3(0,0.7,0)
	for target in get_tree().get_nodes_in_group("sensor_landmarks"):
		var heat: float = target.get_meta("thermal",0.0)
		var destination: Vector3 = target.global_position + Vector3(0,0.6,0)
		var relative: Vector3 = drone.global_basis.inverse() * (destination - origin)
		if heat < 0.2 or relative.length() > range_m or relative.z >= 0.0 or absf(relative.x) > -relative.z:
			continue
		var ray := PhysicsRayQueryParameters3D.create(origin,destination,1,[drone.get_rid()])
		var hit: Dictionary = drone.get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit.position.distance_to(destination) > 1.0:
			continue
		readings.append({"offset":relative,"heat":heat})
	return readings
