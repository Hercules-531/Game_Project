extends Node
var night_vision := false
var zoom := 1.0
func working() -> bool:
	var d: Node = get_parent()
	return d.deployed and d.has_power() and d.module_efficiency("multispectrum")>0 and d.get_parent().get_parent().get_node("Radio").quality(d)>0
func configure(night: bool, magnification: float) -> bool:
	if not working() or magnification not in [1.0,2.0,4.0]: return false
	night_vision = night
	zoom = magnification
	return true
func classifications() -> Array:
	var result := []
	if not working(): return result
	var d: Node = get_parent()
	var eye: Transform3D = d.get_node("CCD").eye_transform()
	var reach: float = 80*minf(1,d.module_efficiency("multispectrum"))
	for target in get_tree().get_nodes_in_group("sensor_landmarks"):
		if not target is Node3D or not target.is_visible_in_tree() or (not target.has_meta("classification") and not target.is_in_group("hostile_pings")): continue
		var at: Vector3 = target.global_position+Vector3(0,0.6,0)
		var distance: float = eye.origin.distance_to(at)
		if distance>reach or not d.get_node("CCD").in_frustum(at): continue
		var ray := PhysicsRayQueryParameters3D.create(eye.origin,at,1,[d.get_rid()])
		var hit: Dictionary = d.get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit.collider!=target and not target.is_ancestor_of(hit.collider): continue
		var relative: Vector3 = eye.affine_inverse()*at
		var tangent := tan(deg_to_rad(35.0))/zoom
		var uv := Vector2(0.5+relative.x/(-relative.z*tangent*4.0/3.0)*0.5,0.5-relative.y/(-relative.z*tangent)*0.5)
		var label: String = "Organic hostile" if target.is_in_group("hostile_pings") else str(target.get_meta("classification")).left(48)
		result.append({"class":label,"range":distance,"uv":uv})
	result.sort_custom(func(a,b): return a.range<b.range)
	return result.slice(0,16)
func snapshot() -> Dictionary: return {"night":night_vision,"zoom":zoom}
static func validate(data: Variant) -> bool:
	return data is Dictionary and data.get("night") is bool and (data.get("zoom") is float or data.get("zoom") is int) and float(data.zoom) in [1.0,2.0,4.0]
func restore(data: Dictionary) -> void:
	assert(validate(data))
	night_vision = data.night
	zoom = data.zoom
