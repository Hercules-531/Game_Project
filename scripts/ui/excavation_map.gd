extends Control
var planner: Node
var panel: Node
func _process(_delta: float) -> void: queue_redraw()
func _draw() -> void:
	if planner==null: return
	var chosen: Dictionary = panel.plan() if panel!=null else {}
	if chosen.get("kind")=="room":
		var room_font := ThemeDB.fallback_font
		var zoom := minf((size.x-20)/24,(size.y-40)/24)
		var middle := size*0.5+Vector2(0,8)
		for i in range(-12,13,2):
			draw_line(middle+Vector2(i,-12)*zoom,middle+Vector2(i,12)*zoom,Color(0.1,0.18,0.13))
			draw_line(middle+Vector2(-12,i)*zoom,middle+Vector2(12,i)*zoom,Color(0.1,0.18,0.13))
		var old: Dictionary = planner.rooms.get(str(chosen.source),{})
		if not old.is_empty():
			var prior := Vector2(old.width,old.depth)*zoom
			draw_rect(Rect2(middle-prior*0.5,prior),Color(0.2,0.4,0.28))
		var footprint := Vector2(chosen.width,chosen.depth)*zoom
		draw_rect(Rect2(middle-footprint*0.5,footprint),Color(0.9,0.7,0.25),false,2)
		draw_string(room_font,Vector2(5,15),"N / ROOM FOOTPRINT",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(0.7,0.8,0.65))
		draw_string(room_font,Vector2(5,size.y-3),"%.0f x %.0fm / H %.1f" % [chosen.width,chosen.depth,chosen.height],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(0.7,0.8,0.65))
		return
	var origin := Vector2(size.x*0.5,size.y-12)
	var scale_factor := (size.y-24)/540.0
	var font := ThemeDB.fallback_font
	var points := []
	for i in 6:
		var at: Vector3 = planner.territory.pad(i)
		points.append(origin+Vector2(at.x,at.z+13)*scale_factor)
	for segment in planner.segments: draw_line(points[int(segment.source)],points[int(segment.target)],Color(0.4,0.8,0.55),3)
	if panel!=null:
		var plan: Dictionary = panel.plan()
		if planner.Plan.valid(plan):
			if plan.kind=="tunnel": draw_line(points[int(plan.source)],points[int(plan.target)],Color(0.9,0.7,0.25),2)
			else:
				var area := Vector2(plan.width,plan.depth)*scale_factor
				draw_rect(Rect2(points[int(plan.source)]-area*0.5,area),Color(0.9,0.7,0.25),false,2)
	for i in 6:
		var color := Color(0.55,0.85,0.65) if planner.territory.sites[i].held else Color(0.2,0.25,0.2)
		draw_circle(points[i],3,color)
		draw_string(font,points[i]+Vector2(8,4),"HOME" if i==0 else str(i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,12,color)
	draw_string(font,Vector2(8,15),"NORTH / HELD HUBS",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(0.7,0.8,0.65))
