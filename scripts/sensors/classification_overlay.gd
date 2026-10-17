extends Control
var control: Node
func _process(_delta: float) -> void: queue_redraw()
func _draw() -> void:
	if control==null: return
	var d: Node = control.selected()
	if d==null: return
	var source: Node = d.get_node("Multispectrum")
	var dimensions := Vector2(640,480)
	var scale_factor := minf(size.x/dimensions.x,size.y/dimensions.y)
	var image_size := dimensions*scale_factor
	var offset := (size-image_size)*0.5
	var font := ThemeDB.fallback_font
	var occupied: Array[Rect2] = []
	var tags: Array = source.classifications().filter(func(tag): return tag["class"]!="Rubble")
	tags.sort_custom(func(a,b):
		var first: bool = a["class"]=="Organic hostile"
		var second: bool = b["class"]=="Organic hostile"
		return first if first!=second else a.range<b.range)
	for tag in tags.slice(0,3):
		var point: Vector2 = offset+tag.uv*image_size
		var label: String = tag["class"]
		var caption: String = "%s / %.0fm" % [label,tag.range]
		while font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x>image_size.x-4 and label.length()>4:
			label = label.left(label.length()-1)
			caption = "%s… / %.0fm" % [label,tag.range]
		var width := font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
		draw_circle(point,3,Color(0.7,1,0.7),false,1)
		var label_at := Vector2.ZERO
		var placed := false
		for shift in [0,14,-14,28,-28,42,-42,56,-56,70,-70]:
			var candidate := Vector2(clampf(point.x+5,offset.x,maxf(offset.x,offset.x+image_size.x-width)),clampf(point.y-5+shift,offset.y+12,offset.y+image_size.y-2))
			var bounds := Rect2(candidate-Vector2(0,12),Vector2(width,14))
			var clear := true
			for prior in occupied:
				if prior.intersects(bounds): clear = false
			if clear:
				occupied.append(bounds)
				label_at = candidate
				placed = true
				break
		if not placed: continue
		if label_at.distance_to(point)>12: draw_line(point,label_at+Vector2(0,-4),Color(0.4,0.65,0.4),1)
		draw_string(font,label_at+Vector2(1,1),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.BLACK)
		draw_string(font,label_at,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(0.7,1,0.7))
