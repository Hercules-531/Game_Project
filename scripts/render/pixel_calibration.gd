extends Control
## Diagnostic geometry, not a gameplay texture.


func _draw() -> void:
	for y in range(12):
		for x in range(48):
			draw_rect(Rect2(x, y, 1, 1), Color.WHITE if (x + y) % 2 == 0 else Color.BLACK)
