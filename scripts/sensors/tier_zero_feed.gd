extends Control

var control: Node
var heat: Array = []
var refresh_in: float = 0.0


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	refresh_in -= delta
	if refresh_in <= 0.0:
		refresh_in = 0.5
		var drone: Node = control.selected()
		heat = drone.get_node("Thermal").sample() if drone != null else []
	queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("interact") and not event.is_echo():
		ping()
		get_viewport().set_input_as_handled()


func ping() -> void:
	var drone: Node = control.selected()
	if drone != null:
		control.request_action("ping")
		queue_redraw()


func _draw() -> void:
	if control == null or control.selected() == null:
		return
	var drone: Node3D = control.selected()
	var sonar: Node = drone.get_node("Sonar")
	var center := Vector2(size.x * 0.28,size.y * 0.5 + 8)
	var radius := minf(size.x * 0.24,size.y * 0.42)
	var green := Color(0.35,0.77,0.5)
	for ring in [0.25,0.5,0.75,1.0]:
		draw_arc(center,radius * ring,0,TAU,64,Color(0.13,0.3,0.21),1)
	draw_line(center - Vector2(radius,0),center + Vector2(radius,0),green.darkened(0.6))
	draw_line(center - Vector2(0,radius),center + Vector2(0,radius),green.darkened(0.6))
	draw_circle(center,3.0,green)
	for echo in sonar.echoes:
		var offset: Vector3 = drone.global_basis.inverse() * (echo - drone.global_position)
		var point: Vector2 = center + Vector2(offset.x,offset.z) * radius / sonar.range_m
		if point.distance_to(center) <= radius:
			draw_rect(Rect2(point - Vector2(2,2),Vector2(4,4)),green,false,1)
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(12,24),"SONAR / 60m  |  PING [" + OS.get_keycode_string(UserSettings.store.keys.interact) + "]",HORIZONTAL_ALIGNMENT_LEFT,-1,16,green)
	var age := "NO ECHO" if sonar.last_ping < 0 else "ECHO AGE %.1fs" % (sonar.clock - sonar.last_ping)
	draw_string(font,Vector2(12,size.y - 12),age,HORIZONTAL_ALIGNMENT_LEFT,-1,14,green)
	var ir := Rect2(size.x * 0.56,44,size.x * 0.42,size.y - 72)
	draw_rect(ir,Color(0.015,0.025,0.04))
	draw_string(font,Vector2(ir.position.x,26),"IR / HEAT ONLY",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(0.65,0.7,0.8))
	for reading in heat:
		var offset: Vector3 = reading.offset
		var x: float = clampf(offset.x / -offset.z,-1,1)
		var point := Vector2(ir.get_center().x + x * ir.size.x * 0.45,ir.get_center().y)
		for ring in range(5,0,-1):
			draw_circle(point,ring * 4.0 * clampf(8.0 / offset.length(),0.4,1.6),Color(0.9,0.2 + reading.heat * 0.4,0.12,0.13))
	if heat.is_empty():
		draw_string(font,ir.position + Vector2(12,ir.size.y * 0.5),"NO WARM RETURN",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(0.3,0.38,0.47))
