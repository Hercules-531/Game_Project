extends RefCounted
const Network = preload("res://scripts/world/territory_network.gd")
const Inventory = preload("res://scripts/simulation/inventory.gd")
const RUN := 9
const HEIGHT := 2.6
static func id_for(kind: String, edge: int) -> String: return "mouth_%d" % (edge+1) if kind=="mouth" else "wall_%d" % edge
static func row_for(kind: String, edge: int) -> int:
	return roundi(Network.pad(edge+1).z+3) if kind=="mouth" else floori((Network.pad(edge).z+Network.pad(edge+1).z)*0.5)
static func create(kind: String, edge: int, grid: Dictionary) -> Dictionary:
	var row := row_for(kind,edge)
	var maximum := [-1000,-1000]
	for cell in grid:
		for i in 2:
			if cell.y==row-1+i: maximum[i] = maxi(maximum[i],cell.x)
	return {"kind":kind,"edge":edge,"hub":edge+1 if kind=="mouth" else edge,"row":row,"start":mini(maximum[0],maximum[1])+1}
static func valid(layouts: Variant, segments: Array, grid: Dictionary) -> bool:
	if not layouts is Dictionary or layouts.size()!=segments.size()*2: return false
	for edge in segments.size():
		for kind in ["mouth","wall"]:
			var layout: Variant = layouts.get(id_for(kind,edge))
			if not layout is Dictionary or layout.get("kind")!=kind or layout.get("edge")!=edge or layout.get("hub")!=(edge+1 if kind=="mouth" else edge) or layout.get("row")!=row_for(kind,edge) or not Inventory._integer(layout.get("start"),-40,40): return false
			for z in range(int(layout.row)-1,int(layout.row)+1):
				if not grid.has(Vector2i(int(layout.start)-1,z)): return false
	return true
static func top(layout: Dictionary) -> Vector3: return Vector3(layout.start,0,layout.row+3)
static func bottom(layout: Dictionary) -> Vector3: return Vector3(layout.start,-6,layout.row)
static func gate_floor(layout: Dictionary) -> Vector3: return top(layout) if layout.kind=="mouth" else bottom(layout)
static func approach(layout: Dictionary) -> Vector3:
	return top(layout)+Vector3(-0.95,0,0) if layout.kind=="mouth" else Vector3(layout.start+0.95,-6+0.95/3.0,layout.row)
static func cut_cells(layouts: Dictionary) -> Dictionary:
	var result := {}
	for layout in layouts.values():
		for x in range(int(layout.start),int(layout.start)+RUN+2):
			for z in range(int(layout.row)-1,int(layout.row)+4):
				if x<int(layout.start)+RUN and z==int(layout.row)+1: continue
				result[Vector2i(x,z)] = true
	return result
static func cleared_ranges(layouts: Dictionary) -> Dictionary:
	var result := {}
	for layout in layouts.values():
		for cell in cut_cells({"one":layout}):
			var floor := floor_at(layout,Vector2(cell.x+0.5,cell.y+0.5))
			result[cell] = [floor+6.0,floor+6.0+HEIGHT]
	return result
static func floor_at(layout: Dictionary, point: Vector2) -> float:
	var x: float = point.x-layout.start
	if x>=RUN: return -3.0
	return -6.0+x/3.0 if point.y<layout.row+1 else -x/3.0
static func contains(layout: Dictionary, at: Vector3) -> bool:
	if at.x<layout.start or at.x>layout.start+RUN+2 or at.z<layout.row-1 or at.z>layout.row+4: return false
	if at.x<layout.start+RUN and at.z>layout.row+1 and at.z<layout.row+2: return false
	var floor := floor_at(layout,Vector2(at.x,at.z))
	return at.y>=floor-0.2 and at.y<floor+HEIGHT-0.1
static func waypoints(layout: Dictionary) -> Array[Vector3]:
	return [top(layout)+Vector3(2,-2.0/3.0,0),Vector3(layout.start+10.2,-3,layout.row+3),Vector3(layout.start+10.2,-3,layout.row),approach(layout) if layout.kind=="wall" else Vector3(layout.start+1,-6+1.0/3.0,layout.row),bottom(layout)+Vector3(-1.1,0,0)]
static func ground_holes(layouts: Dictionary) -> Array[Rect2]:
	var holes: Array[Rect2] = []
	for layout in layouts.values(): holes.append(Rect2(layout.start,layout.row+2,RUN,2))
	return holes
