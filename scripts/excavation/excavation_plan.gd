extends RefCounted
const BALANCE = preload("res://resources/balance/excavation.tres")
const Network = preload("res://scripts/world/territory_network.gd")
const Model = preload("res://scripts/drones/drone.gd")
static func valid(plan: Variant) -> bool:
	if not plan is Dictionary or plan.get("kind") not in ["tunnel","room"]: return false
	for key in ["source","target"]:
		if not Model._range(plan.get(key),0,5) or plan[key]!=int(plan[key]): return false
	if (plan.kind=="tunnel" and plan.target!=plan.source+1) or (plan.kind=="room" and plan.target!=plan.source): return false
	var maximum := 10.0 if plan.kind=="tunnel" else 20.0
	if not Model._range(plan.get("width"),4,maximum) or fmod(plan.width,2)!=0: return false
	if not Model._range(plan.get("depth"),4,20) or fmod(plan.depth,2)!=0: return false
	return Model._range(plan.get("height"),2.4,BALANCE.drill_reach)
static func cells(plan: Dictionary) -> Dictionary:
	var start := Network.pad(int(plan.source))
	var end := Network.pad(int(plan.target))
	var a := Vector2(start.x,start.z)
	var b := Vector2(end.x,end.z)
	var half := Vector2(plan.width,plan.depth)*0.5
	if plan.kind=="tunnel": half = Vector2.ONE*plan.width*0.5
	var low := a.min(b)-half
	var high := a.max(b)+half
	var result := {}
	for x in range(floori(low.x),ceili(high.x)):
		for z in range(floori(low.y),ceili(high.y)):
			var point := Vector2(x+0.5,z+0.5)
			if plan.kind=="tunnel" and point.distance_to(Geometry2D.get_closest_point_to_segment(point,a,b))>plan.width*0.5: continue
			result[Vector2i(x,z)] = float(plan.height)
	return result
static func grid(segments: Array, rooms: Dictionary) -> Dictionary:
	var result := {}
	var plans: Array = segments.duplicate()
	plans.append_array(rooms.values())
	for plan in plans:
		var area := cells(plan)
		for cell in area: result[cell] = maxf(result.get(cell,0.0),area[cell])
	return result
static func quote(plan: Dictionary, existing: Dictionary) -> Dictionary:
	if not valid(plan): return {}
	var volume := 0.0
	var area := cells(plan)
	for cell in area: volume += maxf(0,area[cell]-float(existing.get(cell,0.0)))
	volume = snappedf(volume,0.000001)
	if volume<=0: return {}
	return {"volume":volume,"scrap":maxi(1,ceili(volume*BALANCE.scrap_per_m3)),"seconds":maxf(BALANCE.minimum_seconds,volume*BALANCE.seconds_per_m3)}
static func reachable(band: int, segments: Array) -> bool:
	return band>=0 and band<=segments.size()
static func expansion(plan: Dictionary, segments: Array, rooms: Dictionary) -> bool:
	if not valid(plan) or not reachable(int(plan.source),segments): return false
	var previous: Dictionary = {}
	if plan.kind=="tunnel" and int(plan.source)<segments.size(): previous = segments[int(plan.source)]
	if plan.kind=="room": previous = rooms.get(str(int(plan.source)),{})
	return previous.is_empty() or (plan.width>=previous.width and (plan.kind=="tunnel" or plan.depth>=previous.depth) and plan.height>=previous.height)
