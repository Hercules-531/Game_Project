extends Node3D

@export var sensitivity: float = 0.0025
@export var pitch_limit_degrees: float = 80.0


func _ready() -> void:
	InputContext.set_context(InputContext.Context.WALK)


func apply_look(relative: Vector2) -> void:
	if not InputContext.allows_look():
		return
	get_parent().rotate_y(-relative.x * sensitivity)
	rotation.x = clampf(rotation.x - relative.y * sensitivity,
		-deg_to_rad(pitch_limit_degrees), deg_to_rad(pitch_limit_degrees))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		apply_look(event.screen_relative)
