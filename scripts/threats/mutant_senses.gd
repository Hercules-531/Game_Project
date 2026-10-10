extends RefCounted

static func clear_reach(body: CharacterBody3D, at: Vector3, target: Node = null) -> bool:
	var origin := body.global_position + Vector3(0,0.7,0)
	var end := at + Vector3(0,0.7,0)
	var query := PhysicsRayQueryParameters3D.create(origin,end,1,[body.get_rid()])
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == target

static func detects(kind: String, distance: float, reach: float, clear: bool, multiplier: float = 1.0) -> bool:
	var cover: float = 1.0 if clear else (0.35 if kind in ["sound","radio"] else 0.0)
	return cover > 0.0 and distance <= reach * multiplier * cover

static func strongest(body: CharacterBody3D, world: Node, sources: Array) -> Dictionary:
	var best := {}
	var score := 0.0
	for event in sources:
		var at := Vector3(event.at[0],event.at[1],event.at[2])
		var target: Node = world.get_node("Operator") if event.source == "operator" else world.get_node("Fleet").drone(event.source)
		var clear := clear_reach(body,at,target)
		var distance := body.global_position.distance_to(at)
		var multiplier: float = world.get_node("Weather").mutant_sense_multiplier
		if not detects(event.kind,distance,event.reach,clear,multiplier): continue
		var strength: float = event.reach * multiplier / maxf(1.0,distance)
		if event.kind == "light": strength += 1000.0
		if strength > score:
			score = strength
			best = {"kind":event.kind,"at":at,"source":event.source,"distance":distance}
	return best
