extends RefCounted

var points: Array[Vector3] = []

func record(at: Vector3) -> void:
	if points.is_empty() or points.back().distance_to(at) >= 0.5:
		points.append(at)
		if points.size() > 2048:
			points.pop_front()

func snapshot() -> Array:
	var data := []
	for point in points:
		data.append([point.x,point.y,point.z])
	return data

static func validate(data: Variant) -> bool:
	if not data is Array or data.size() > 2048:
		return false
	for point in data:
		if not point is Array or point.size() != 3:
			return false
		for value in point:
			if not (value is int or value is float) or not is_finite(value) or absf(value) > 1000000.0:
				return false
	return true

func restore(data: Array) -> void:
	points.clear()
	for point in data:
		points.append(Vector3(point[0],point[1],point[2]))
