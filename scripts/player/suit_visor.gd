extends Control
## Code-drawn analog gauges and scratches; no invented bitmap.
var sortie: Node
func _process(_delta: float) -> void:
	visible = sortie.active and InputContext.active == InputContext.Context.WALK
	if visible:
		queue_redraw()
func _draw() -> void:
	if sortie.flash_remaining > 9.75:
		draw_rect(Rect2(Vector2.ZERO,size),Color(0.85,0.93,1.0,(sortie.flash_remaining - 9.75) * 2.0))
	var edge := Color(0.035,0.045,0.038,0.9)
	draw_rect(Rect2(0,0,size.x,28),edge)
	draw_rect(Rect2(0,size.y - 72,size.x,72),edge)
	var font := ThemeDB.fallback_font
	var green := Color(0.7,0.86,0.67)
	draw_string(font,Vector2(18,20),"14 / SUIT  |  USE NEAR THREAT: FLASH",HORIZONTAL_ALIGNMENT_LEFT,-1,16,green)
	_gauge(Vector2(62,size.y - 32),sortie.oxygen / 480.0,"O2",green)
	_gauge(Vector2(174,size.y - 32),sortie.filter / 300.0,"FILTER",green)
	draw_string(font,Vector2(232,size.y - 36),"CELL %.2f kWh  |  ESCORT %s" % [sortie.jumper,sortie.escort_id if not sortie.escort_id.is_empty() else "NONE"],HORIZONTAL_ALIGNMENT_LEFT,-1,14,green)
	draw_string(font,Vector2(232,size.y - 15),"O2 %03ds / FILTER %03ds / FLASH %s" % [sortie.oxygen,sortie.filter,"READY" if sortie.flash_remaining <= 0.0 else str(int(ceil(sortie.flash_remaining)))],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(1,0.5,0.3) if minf(sortie.oxygen,sortie.filter) < 60 else green)
	for line in [[Vector2(52,92),Vector2(88,134)],[Vector2(544,200),Vector2(572,156)],[Vector2(96,330),Vector2(112,290)]]:
		draw_line(line[0],line[1],Color(0.8,0.85,0.8,0.09),1)
func _gauge(center: Vector2, value: float, title: String, color: Color) -> void:
	draw_arc(center,25,PI,TAU,20,color,1)
	for i in 6:
		var a := PI + PI * i / 5.0
		draw_line(center + Vector2(cos(a),sin(a)) * 20,center + Vector2(cos(a),sin(a)) * 25,color,1)
	var angle := PI + PI * clampf(value,0,1)
	draw_line(center,center + Vector2(cos(angle),sin(angle)) * 22,Color(1,0.52,0.3),2)
	draw_string(ThemeDB.fallback_font,center + Vector2(-22,17),title,HORIZONTAL_ALIGNMENT_LEFT,-1,12,color)
