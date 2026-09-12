extends Node3D
## The two doors cannot open together. Surface access requires authorization.

signal state_changed

@export var cycle_seconds: float = 1.0
var outer_authorized: bool = false
var opened_side: StringName = &""
var busy: bool = false


func request_open(side: StringName) -> bool:
	if side not in [&"inner", &"outer"] or busy or opened_side != &"":
		return false
	if side == &"outer" and not outer_authorized:
		return false
	busy = true
	state_changed.emit()
	var door := get_node("InnerDoor" if side == &"inner" else "OuterDoor") as Node3D
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(door, "position:x", 1.8, cycle_seconds)
	tween.tween_callback(func():
		opened_side = side
		busy = false
		state_changed.emit())
	return true


func request_close() -> bool:
	if busy or opened_side == &"":
		return false
	busy = true
	state_changed.emit()
	var door := get_node("InnerDoor" if opened_side == &"inner" else "OuterDoor") as Node3D
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(door, "position:x", 0.0, cycle_seconds)
	tween.tween_callback(func():
		opened_side = &""
		busy = false
		state_changed.emit())
	return true
