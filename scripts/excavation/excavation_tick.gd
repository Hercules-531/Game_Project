extends Node
func _ready() -> void: process_physics_priority = -10
func _physics_process(delta: float) -> void: get_parent().advance(delta)
